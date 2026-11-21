import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../../../core/error/user_facing_error.dart';
import '../../../shared/domain/arabic_search_normalizer.dart';
import '../../../shared/utils/firestore_in_query.dart';
import '../../accounts/domain/onboarding_models.dart';
import '../domain/directory_models.dart';
import '../domain/relationship_history_text.dart';

/// Admin academy directory: bounded reads for lists and profiles, and every
/// relationship or account change through an audited callable. Nothing here
/// writes Firestore directly.
abstract class AcademyDirectoryRepository {
  static const pageSize = 20;

  Future<DirectoryPage<DirectoryPerson>> browsePeople({
    required DirectoryRole role,
    DirectoryStatusFilter status = DirectoryStatusFilter.all,
    DirectoryRelationFilter relation = DirectoryRelationFilter.none,
    String? halaqaId,
    Object? cursor,
  });

  Future<List<DirectoryPerson>> searchPeople({
    DirectoryRole? role,
    required String query,
  });

  Future<DirectoryPage<DirectoryHalaqa>> browseHalaqat({
    HalaqaListFilter filter = HalaqaListFilter.all,
    Object? cursor,
  });

  Future<List<DirectoryHalaqa>> searchHalaqat(String query);

  Future<List<StructureCount>> structureOverview();

  Future<PersonProfile> loadPerson(String uid);

  Future<HalaqaProfile> loadHalaqa(String halaqaId);

  Future<MemberAccount> loadAccount(String uid);

  Future<IssuedCredential> resetPassword(DirectoryPerson person);

  Future<IssuedCredential> createMember({
    required DirectoryRole role,
    required String name,
  });

  Future<void> linkParent({
    required String parentId,
    required String studentId,
  });

  Future<void> unlinkParent({
    required String parentId,
    required String studentId,
  });

  Future<void> replaceParent({
    required String studentId,
    required String fromParentId,
    required String toParentId,
  });

  Future<void> admitStudent({
    required String halaqaId,
    required String studentId,
  });

  Future<void> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  });

  /// [newStaffId] empty removes the supervisor; a halaqa always keeps a teacher.
  Future<void> reassignStaff({
    required String halaqaId,
    required DirectoryRole role,
    required String newStaffId,
  });

  Future<void> setAssistant({
    required String halaqaId,
    required String assistantId,
    required bool assign,
  });

  Future<void> startCover({
    required String halaqaId,
    required String coverTeacherId,
    String reason = '',
  });

  Future<void> endCover({required String halaqaId});
}

class FirestoreAcademyDirectoryRepository
    implements AcademyDirectoryRepository {
  FirestoreAcademyDirectoryRepository({
    required this.firestore,
    required this.functions,
  });

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  static const _searchLimit = 20;
  static const _halaqatPerPerson = 20;
  static const _studentsShown = 100;
  static const _historyLimit = 20;

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(FirestoreCollections.users);
  CollectionReference<Map<String, dynamic>> get _halaqat =>
      firestore.collection(FirestoreCollections.halaqat);

  // ── reads ───────────────────────────────────────────────────────────────

  Future<Map<String, DirectoryPerson>> _peopleById(Iterable<String> ids) async {
    final out = <String, DirectoryPerson>{};
    for (final chunk in FirestoreInQuery.chunkIds(ids)) {
      final snap = await _users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        out[d.id] = DirectoryPerson.fromUser(d.id, d.data());
      }
    }
    return out;
  }

  Future<Map<String, String>> _halaqaNames(Iterable<String> ids) async {
    final out = <String, String>{};
    for (final chunk in FirestoreInQuery.chunkIds(ids)) {
      final snap = await _halaqat
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        out[d.id] = '${d.data()['name'] ?? ''}'.trim();
      }
    }
    return out;
  }

  static String _str(Object? v) => v is String ? v.trim() : '';
  static List<String> _ids(Object? v) => [
    for (final x in (v is List ? v : const []))
      if (x is String && x.trim().isNotEmpty) x.trim(),
  ];
  static bool _coverActive(Map<String, dynamic> d) =>
      _str(d['coverId']).isNotEmpty && _str(d['coverTeacherId']).isNotEmpty;
  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  DirectoryHalaqa _halaqaOf(
    String id,
    Map<String, dynamic> d, [
    Map<String, DirectoryPerson> people = const {},
  ]) => DirectoryHalaqa(
    id: id,
    name: _str(d['name']),
    academyRef: _str(d['academyRef']),
    status: _str(d['status']).isEmpty ? 'active' : _str(d['status']),
    teacherName: people[_str(d['teacherId'])]?.name ?? '',
    supervisorName: people[_str(d['supervisorId'])]?.name ?? '',
    studentCount: _ids(d['studentIds']).length,
    assistantCount: _ids(d['assistantTeacherIds']).length,
    hasActiveCover: _coverActive(d),
  );

  Set<String> _staffIdsOf(Map<String, dynamic> d) => {
    _str(d['teacherId']),
    _str(d['supervisorId']),
    ..._ids(d['assistantTeacherIds']),
    if (_coverActive(d)) _str(d['coverTeacherId']),
  }..remove('');

  HalaqaStaff _staffOf(
    Map<String, dynamic> d,
    Map<String, DirectoryPerson> people,
  ) => HalaqaStaff(
    teacher: people[_str(d['teacherId'])],
    supervisor: people[_str(d['supervisorId'])],
    assistants: [
      for (final id in _ids(d['assistantTeacherIds']))
        if (people[id] != null) people[id]!,
    ],
    cover: _coverActive(d) ? people[_str(d['coverTeacherId'])] : null,
  );

  @override
  Future<DirectoryPage<DirectoryPerson>> browsePeople({
    required DirectoryRole role,
    DirectoryStatusFilter status = DirectoryStatusFilter.all,
    DirectoryRelationFilter relation = DirectoryRelationFilter.none,
    String? halaqaId,
    Object? cursor,
  }) async {
    const size = AcademyDirectoryRepository.pageSize;
    try {
      // Students of one halaqa: page through its roster ids.
      if (role == DirectoryRole.student && (halaqaId ?? '').isNotEmpty) {
        final doc = await _halaqat.doc(halaqaId).get();
        final ids = _ids(doc.data()?['studentIds']);
        final start = cursor is int ? cursor : 0;
        final slice = ids.skip(start).take(size).toList();
        final people = await _peopleById(slice);
        return DirectoryPage(
          items: [
            for (final id in slice)
              if (people[id] != null) people[id]!,
          ],
          cursor: start + slice.length,
          hasMore: start + slice.length < ids.length,
        );
      }

      // Relationship filters: the related collection selects the ids.
      if (relation == DirectoryRelationFilter.studentsWithoutHalaqa ||
          relation == DirectoryRelationFilter.parentsWithoutChildren) {
        Query<Map<String, dynamic>> q =
            relation == DirectoryRelationFilter.studentsWithoutHalaqa
            ? firestore
                  .collection(FirestoreCollections.studentProfiles)
                  .where('halaqaId', isNull: true)
            : firestore
                  .collection(FirestoreCollections.parentProfiles)
                  .where('childrenIds', isEqualTo: const <String>[]);
        q = q.orderBy(FieldPath.documentId).limit(size);
        if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
        final snap = await q.get();
        final people = await _peopleById(snap.docs.map((d) => d.id));
        return DirectoryPage(
          items: [
            for (final d in snap.docs)
              if (people[d.id] != null) people[d.id]!,
          ],
          cursor: snap.docs.isEmpty ? null : snap.docs.last,
          hasMore: snap.docs.length == size,
        );
      }

      Query<Map<String, dynamic>> q = _users.where(
        'role',
        isEqualTo: role.wire,
      );
      if (status != DirectoryStatusFilter.all) {
        q = q.where(
          'isActive',
          isEqualTo: status == DirectoryStatusFilter.active,
        );
      }
      q = q.orderBy('name').limit(size);
      if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      return DirectoryPage(
        items: [
          for (final d in snap.docs) DirectoryPerson.fromUser(d.id, d.data()),
        ],
        cursor: snap.docs.isEmpty ? null : snap.docs.last,
        hasMore: snap.docs.length == size,
      );
    } catch (_) {
      throw const ServerException('تعذر تحميل القائمة، أعد المحاولة');
    }
  }

  @override
  Future<List<DirectoryPerson>> searchPeople({
    DirectoryRole? role,
    required String query,
  }) async {
    final raw = query.trim();
    if (raw.isEmpty) return const [];
    try {
      final ref = normalizeAcademyRef(raw);
      if (ref != null) {
        final snap = await _users
            .where('academyRef', whereIn: {ref, raw.toUpperCase()}.toList())
            .limit(10)
            .get();
        return [
          for (final d in snap.docs) DirectoryPerson.fromUser(d.id, d.data()),
        ];
      }
      final normalized = ArabicSearchNormalizer.normalize(raw);
      if (normalized.length < 2) return const [];
      Query<Map<String, dynamic>> base = _users;
      if (role != null) base = base.where('role', isEqualTo: role.wire);
      final results = await Future.wait([
        base
            .orderBy('nameNormalized')
            .startAt([normalized])
            .endAt(['$normalized\uf8ff'])
            .limit(_searchLimit)
            .get(),
        // Accounts created before `nameNormalized` existed carry `name` only.
        base
            .orderBy('name')
            .startAt([raw])
            .endAt(['$raw\uf8ff'])
            .limit(_searchLimit)
            .get(),
      ]);
      final seen = <String>{};
      return [
        for (final snap in results)
          for (final d in snap.docs)
            if (seen.add(d.id)) DirectoryPerson.fromUser(d.id, d.data()),
      ];
    } catch (_) {
      throw const ServerException('تعذر البحث، أعد المحاولة');
    }
  }

  @override
  Future<DirectoryPage<DirectoryHalaqa>> browseHalaqat({
    HalaqaListFilter filter = HalaqaListFilter.all,
    Object? cursor,
  }) async {
    const size = AcademyDirectoryRepository.pageSize;
    try {
      Query<Map<String, dynamic>> q = switch (filter) {
        HalaqaListFilter.all => _halaqat.orderBy('name'),
        HalaqaListFilter.active =>
          _halaqat.where('status', isEqualTo: 'active').orderBy('name'),
        HalaqaListFilter.withoutSupervisor =>
          _halaqat.where('supervisorId', isEqualTo: '').orderBy('name'),
        HalaqaListFilter.activeCover =>
          _halaqat.where('coverId', isNotEqualTo: '').orderBy('coverId'),
      };
      q = q.limit(size);
      if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
      final snap = await q.get();
      final people = await _peopleById({
        for (final d in snap.docs) ...[
          _str(d.data()['teacherId']),
          _str(d.data()['supervisorId']),
        ],
      });
      return DirectoryPage(
        items: [for (final d in snap.docs) _halaqaOf(d.id, d.data(), people)],
        cursor: snap.docs.isEmpty ? null : snap.docs.last,
        hasMore: snap.docs.length == size,
      );
    } catch (_) {
      throw const ServerException('تعذر تحميل الحلقات، أعد المحاولة');
    }
  }

  @override
  Future<List<DirectoryHalaqa>> searchHalaqat(String query) async {
    final raw = query.trim();
    if (raw.isEmpty) return const [];
    try {
      final ref = normalizeAcademyRef(raw);
      final snap = ref != null
          ? await _halaqat
                .where('academyRef', whereIn: {ref, raw.toUpperCase()}.toList())
                .limit(10)
                .get()
          : await _halaqat
                .orderBy('name')
                .startAt([raw])
                .endAt(['$raw\uf8ff'])
                .limit(_searchLimit)
                .get();
      final people = await _peopleById({
        for (final d in snap.docs) ...[
          _str(d.data()['teacherId']),
          _str(d.data()['supervisorId']),
        ],
      });
      return [for (final d in snap.docs) _halaqaOf(d.id, d.data(), people)];
    } catch (_) {
      throw const ServerException('تعذر البحث، أعد المحاولة');
    }
  }

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  @override
  Future<List<StructureCount>> structureOverview() async {
    try {
      final roleCounts = await Future.wait([
        for (final r in DirectoryRole.values)
          _count(_users.where('role', isEqualTo: r.wire)),
      ]);
      final other = await Future.wait([
        _count(_halaqat),
        _count(_halaqat.where('supervisorId', isEqualTo: '')),
        _count(_halaqat.where('coverId', isNotEqualTo: '')),
        _count(
          firestore
              .collection(FirestoreCollections.studentProfiles)
              .where('halaqaId', isNull: true),
        ),
        _count(
          firestore
              .collection(FirestoreCollections.parentProfiles)
              .where('childrenIds', isEqualTo: const <String>[]),
        ),
        _count(_users.where('isActive', isEqualTo: false)),
      ]);
      return [
        for (var i = 0; i < DirectoryRole.values.length; i++)
          StructureCount(
            label: DirectoryRole.values[i].plural,
            count: roleCounts[i],
            role: DirectoryRole.values[i],
          ),
        StructureCount(
          label: 'الحلقات',
          count: other[0],
          halaqaFilter: HalaqaListFilter.all,
        ),
        StructureCount(
          label: 'حلقات بلا مشرف',
          count: other[1],
          halaqaFilter: HalaqaListFilter.withoutSupervisor,
        ),
        StructureCount(
          label: 'حلقات بها تغطية مؤقتة',
          count: other[2],
          halaqaFilter: HalaqaListFilter.activeCover,
        ),
        StructureCount(
          label: 'طلاب بلا حلقة',
          count: other[3],
          role: DirectoryRole.student,
          relation: DirectoryRelationFilter.studentsWithoutHalaqa,
        ),
        StructureCount(
          label: 'أولياء أمور بلا أبناء مرتبطين',
          count: other[4],
          role: DirectoryRole.parent,
          relation: DirectoryRelationFilter.parentsWithoutChildren,
        ),
        StructureCount(
          label: 'حسابات غير نشطة',
          count: other[5],
          status: DirectoryStatusFilter.inactive,
        ),
      ];
    } catch (_) {
      throw const ServerException('تعذر تحميل ملخص الأكاديمية');
    }
  }

  Future<List<RelationshipEvent>> _history(String subjectId) async {
    final snap = await firestore
        .collection(FirestoreCollections.relationshipHistory)
        .where('subjectIds', arrayContains: subjectId)
        .orderBy('at', descending: true)
        .limit(_historyLimit)
        .get();
    final people = <String>{};
    final halaqat = <String>{};
    for (final d in snap.docs) {
      final ids = relationshipEntryIds(d.data());
      people.addAll(ids.people);
      halaqat.addAll(ids.halaqat);
    }
    final names = await _peopleById(people);
    final halaqaNames = await _halaqaNames(halaqat);
    String person(String id) => names[id]?.displayName ?? 'حساب محذوف';
    String halaqa(String id) {
      final n = halaqaNames[id] ?? '';
      return n.isEmpty ? 'حلقة' : n;
    }

    return [
      for (final d in snap.docs)
        RelationshipEvent(
          kind: _str(d.data()['kind']),
          operation: _str(d.data()['operation']),
          at: _date(d.data()['at']),
          actorName: person(_str(d.data()['actorId'])),
          description: describeRelationshipEntry(
            d.data(),
            person: person,
            halaqa: halaqa,
          ),
        ),
    ];
  }

  /// Halaqat where [uid] holds [role], with their staff resolved.
  Future<List<({String id, Map<String, dynamic> data, HalaqaRole role})>>
  _halaqatOf(String uid, String personRole) async {
    final queries = <(Query<Map<String, dynamic>>, HalaqaRole)>[
      if (personRole == AppRoles.student)
        (_halaqat.where('studentIds', arrayContains: uid), HalaqaRole.student),
      if (personRole == AppRoles.teacher)
        (
          _halaqat.where('teacherId', isEqualTo: uid),
          HalaqaRole.primaryTeacher,
        ),
      if (personRole == AppRoles.supervisor)
        (_halaqat.where('supervisorId', isEqualTo: uid), HalaqaRole.supervisor),
      if (personRole == AppRoles.assistantTeacher)
        (
          _halaqat.where('assistantTeacherIds', arrayContains: uid),
          HalaqaRole.assistant,
        ),
      if (personRole == AppRoles.teacher ||
          personRole == AppRoles.assistantTeacher)
        (
          _halaqat
              .where('coverTeacherId', isEqualTo: uid)
              .where('coverId', isNotEqualTo: ''),
          HalaqaRole.cover,
        ),
    ];
    final snaps = await Future.wait([
      for (final (q, _) in queries) q.limit(_halaqatPerPerson).get(),
    ]);
    return [
      for (var i = 0; i < queries.length; i++)
        for (final d in snaps[i].docs)
          (id: d.id, data: d.data(), role: queries[i].$2),
    ];
  }

  @override
  Future<PersonProfile> loadPerson(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> userDoc;
    try {
      userDoc = await _users.doc(uid).get();
    } catch (_) {
      throw const ServerException('تعذر تحميل الملف، أعد المحاولة');
    }
    if (!userDoc.exists) throw const ServerException('الحساب غير موجود');
    final person = DirectoryPerson.fromUser(uid, userDoc.data()!);
    try {
      final role = person.role;
      final halaqat = await _halaqatOf(uid, role);

      // Parents and siblings (student), children (parent).
      var parentIds = <String>[];
      var childIds = <String>[];
      final siblingIds = <String>{};
      if (role == AppRoles.student) {
        final links = await firestore
            .collection(FirestoreCollections.parentProfiles)
            .where('childrenIds', arrayContains: uid)
            .limit(10)
            .get();
        parentIds = [for (final l in links.docs) l.id];
        for (final l in links.docs) {
          siblingIds.addAll(_ids(l.data()['childrenIds']));
        }
        siblingIds.remove(uid);
      } else if (role == AppRoles.parent) {
        final profile = await firestore
            .collection(FirestoreCollections.parentProfiles)
            .doc(uid)
            .get();
        childIds = _ids(profile.data()?['childrenIds']);
      }

      // Children's halaqat (parent profile).
      final childHalaqat =
          <String, List<({String id, Map<String, dynamic> data})>>{};
      for (final childId in childIds) {
        final snap = await _halaqat
            .where('studentIds', arrayContains: childId)
            .limit(5)
            .get();
        childHalaqat[childId] = [
          for (final d in snap.docs) (id: d.id, data: d.data()),
        ];
      }

      // Students reached through staff halaqat.
      final studentIds = <String>{
        if (role != AppRoles.student)
          for (final h in halaqat) ..._ids(h.data['studentIds']),
      };
      final shownStudents = studentIds.take(_studentsShown).toList();

      final staffIds = <String>{
        for (final h in halaqat) ..._staffIdsOf(h.data),
        for (final list in childHalaqat.values)
          for (final h in list) ..._staffIdsOf(h.data),
      };
      final people = await _peopleById({
        ...staffIds,
        ...parentIds,
        ...siblingIds,
        ...childIds,
        ...shownStudents,
      });

      List<PaymentSummary> payments = const [];
      if (role == AppRoles.student || role == AppRoles.parent) {
        final snap = await firestore
            .collection(FirestoreCollections.payments)
            .where(
              role == AppRoles.student ? 'studentId' : 'parentId',
              isEqualTo: uid,
            )
            .orderBy('dueDate', descending: true)
            .limit(6)
            .get();
        payments = [
          for (final d in snap.docs)
            PaymentSummary(
              studentName:
                  people[_str(d.data()['studentId'])]?.name ?? person.name,
              amount: d.data()['amount'] is num ? d.data()['amount'] as num : 0,
              status: _str(d.data()['status']),
              dueDate: _date(d.data()['dueDate']),
            ),
        ];
      }

      final supervisorStaff = <DirectoryPerson>[
        if (role == AppRoles.supervisor)
          for (final id in {
            for (final h in halaqat) ...[
              _str(h.data['teacherId']),
              ..._ids(h.data['assistantTeacherIds']),
            ],
          })
            if (people[id] != null) people[id]!,
      ];

      return PersonProfile(
        person: person,
        halaqat: [
          for (final h in halaqat)
            HalaqaLink(
              halaqa: _halaqaOf(h.id, h.data, people),
              role: h.role,
              staff: _staffOf(h.data, people),
            ),
        ],
        parents: [
          for (final id in parentIds)
            if (people[id] != null) people[id]!,
        ],
        siblings: [
          for (final id in siblingIds)
            if (people[id] != null) people[id]!,
        ],
        children: [
          for (final id in childIds)
            if (people[id] != null)
              ChildSummary(
                child: people[id]!,
                halaqat: [
                  for (final h in childHalaqat[id] ?? const [])
                    HalaqaLink(
                      halaqa: _halaqaOf(h.id, h.data, people),
                      role: HalaqaRole.student,
                      staff: _staffOf(h.data, people),
                    ),
                ],
              ),
        ],
        students: [
          for (final id in shownStudents)
            if (people[id] != null) people[id]!,
        ]..sort((a, b) => a.name.compareTo(b.name)),
        studentsTruncated: studentIds.length > shownStudents.length,
        staff: supervisorStaff,
        payments: payments,
        history: await _history(uid),
      );
    } on ServerException {
      rethrow;
    } catch (_) {
      throw const ServerException('تعذر تحميل علاقات الحساب، أعد المحاولة');
    }
  }

  @override
  Future<HalaqaProfile> loadHalaqa(String halaqaId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _halaqat.doc(halaqaId).get();
    } catch (_) {
      throw const ServerException('تعذر تحميل الحلقة، أعد المحاولة');
    }
    if (!doc.exists) throw const ServerException('الحلقة غير موجودة');
    final d = doc.data()!;
    try {
      final studentIds = _ids(d['studentIds']);
      final parentsOf = <String, List<String>>{};
      for (final chunk in FirestoreInQuery.chunkIds(studentIds)) {
        final links = await firestore
            .collection(FirestoreCollections.parentProfiles)
            .where('childrenIds', arrayContainsAny: chunk)
            .get();
        for (final l in links.docs) {
          for (final child in _ids(l.data()['childrenIds'])) {
            if (chunk.contains(child)) (parentsOf[child] ??= []).add(l.id);
          }
        }
      }
      final periodsSnap = await firestore
          .collection(FirestoreCollections.halaqaCoverPeriods)
          .where('halaqaId', isEqualTo: halaqaId)
          .orderBy('startedAt', descending: true)
          .limit(10)
          .get();
      final people = await _peopleById({
        ..._staffIdsOf(d),
        ...studentIds,
        for (final list in parentsOf.values) ...list,
        for (final p in periodsSnap.docs) _str(p.data()['coverTeacherId']),
      });
      final schedule = [
        for (final s in (d['schedule'] as List? ?? const []))
          if (s is Map)
            '${s['day'] ?? ''} ${s['startTime'] ?? ''}–${s['endTime'] ?? ''}'
                .trim(),
      ];
      return HalaqaProfile(
        halaqa: _halaqaOf(doc.id, d, people),
        staff: _staffOf(d, people),
        schedule: schedule,
        students: [
          for (final id in studentIds)
            if (people[id] != null)
              StudentWithParents(
                student: people[id]!,
                parents: [
                  for (final p in parentsOf[id] ?? const <String>[])
                    if (people[p] != null) people[p]!,
                ],
              ),
        ]..sort((a, b) => a.student.name.compareTo(b.student.name)),
        coverPeriods: [
          for (final p in periodsSnap.docs)
            if (people[_str(p.data()['coverTeacherId'])] != null)
              CoverPeriod(
                cover: people[_str(p.data()['coverTeacherId'])]!,
                coverRole: _str(p.data()['coverRole']),
                status: _str(p.data()['status']),
                reason: _str(p.data()['reason']),
                startedAt: _date(p.data()['startedAt']),
                endedAt: _date(p.data()['endedAt']),
              ),
        ],
        history: await _history(halaqaId),
      );
    } on ServerException {
      rethrow;
    } catch (_) {
      throw const ServerException('تعذر تحميل تفاصيل الحلقة، أعد المحاولة');
    }
  }

  // ── callables ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await functions.httpsCallable(name).call<dynamic>(payload);
      final data = result.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim() ?? '';
      throw ServerException(
        message.isNotEmpty && !message.contains(RegExp('[A-Za-z]{6,}'))
            ? message
            : 'تعذر إتمام العملية، حاول مرة أخرى',
      );
    } catch (_) {
      throw const ServerException(connectionErrorText);
    }
  }

  @override
  Future<MemberAccount> loadAccount(String uid) async => MemberAccount.fromMap(
    await _call('adminGetMemberAccount', {'userId': uid}),
  );

  @override
  Future<IssuedCredential> resetPassword(DirectoryPerson person) async {
    final data = await _call('adminResetMemberPassword', {
      'userId': person.uid,
    });
    return IssuedCredential(
      role: person.role,
      uid: person.uid,
      name: person.name,
      username: '${data['username'] ?? ''}',
      temporaryPassword: '${data['temporaryPassword'] ?? ''}',
      academyRef: '${data['academyRef'] ?? person.academyRef}',
    );
  }

  @override
  Future<IssuedCredential> createMember({
    required DirectoryRole role,
    required String name,
  }) async => IssuedCredential.fromMap(
    await _call('adminCreateMemberAccount', {
      'role': role.wire,
      'name': name.trim(),
    }),
  );

  @override
  Future<void> linkParent({
    required String parentId,
    required String studentId,
  }) => _call('adminLinkParentChild', {
    'parentId': parentId,
    'studentId': studentId,
    'operation': 'link',
  });

  @override
  Future<void> unlinkParent({
    required String parentId,
    required String studentId,
  }) => _call('adminLinkParentChild', {
    'parentId': parentId,
    'studentId': studentId,
    'operation': 'unlink',
  });

  @override
  Future<void> replaceParent({
    required String studentId,
    required String fromParentId,
    required String toParentId,
  }) => _call('adminReplaceParentLink', {
    'studentId': studentId,
    'fromParentId': fromParentId,
    'toParentId': toParentId,
  });

  @override
  Future<void> admitStudent({
    required String halaqaId,
    required String studentId,
  }) => _call('admitStudentToHalaqa', {
    'halaqaId': halaqaId,
    'studentId': studentId,
  });

  @override
  Future<void> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  }) => _call('adminTransferStudent', {
    'studentId': studentId,
    'fromHalaqaId': fromHalaqaId,
    'toHalaqaId': toHalaqaId,
  });

  @override
  Future<void> reassignStaff({
    required String halaqaId,
    required DirectoryRole role,
    required String newStaffId,
  }) => _call('adminReassignHalaqaStaff', {
    'halaqaId': halaqaId,
    'role': role.wire,
    'newStaffId': newStaffId,
  });

  @override
  Future<void> setAssistant({
    required String halaqaId,
    required String assistantId,
    required bool assign,
  }) => _call('adminSetHalaqaAssistant', {
    'halaqaId': halaqaId,
    'assistantId': assistantId,
    'operation': assign ? 'assign' : 'unassign',
  });

  @override
  Future<void> startCover({
    required String halaqaId,
    required String coverTeacherId,
    String reason = '',
  }) => _call('adminStartHalaqaCover', {
    'halaqaId': halaqaId,
    'coverTeacherId': coverTeacherId,
    if (reason.trim().isNotEmpty) 'reason': reason.trim(),
  });

  @override
  Future<void> endCover({required String halaqaId}) =>
      _call('adminEndHalaqaCover', {'halaqaId': halaqaId});
}

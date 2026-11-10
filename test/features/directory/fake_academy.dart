import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/accounts/domain/onboarding_models.dart';
import 'package:rafiq_academy/features/directory/data/academy_directory_repository.dart';
import 'package:rafiq_academy/features/directory/domain/directory_models.dart';
import 'package:rafiq_academy/features/directory/domain/relationship_history_text.dart';

class FakeHalaqa {
  final String id;
  final String name;
  final String ref;
  String teacher;
  String supervisor;
  final List<String> assistants = [];
  String cover = '';
  final List<String> students = [];
  final List<CoverPeriod> periods = [];

  FakeHalaqa(this.id, this.name, this.ref, {required this.teacher, this.supervisor = ''});
}

typedef BrowseCall = ({
  DirectoryRole role,
  DirectoryStatusFilter status,
  DirectoryRelationFilter relation,
  String? halaqaId,
  Object? cursor,
  int returned,
});

/// In-memory academy keeping one source of truth per relationship (parent →
/// children, halaqa → staff and roster), so every profile is derived from the
/// same data the mutations change — like the server-side SSOT fields.
class FakeAcademy implements AcademyDirectoryRepository {
  FakeAcademy({this.pageSize = AcademyDirectoryRepository.pageSize});

  final int pageSize;
  final Map<String, DirectoryPerson> people = {};
  final Map<String, Set<String>> childrenOf = {};
  final Map<String, FakeHalaqa> halaqat = {};
  final Map<String, MemberAccount> accounts = {};
  final List<({Map<String, dynamic> entry, Set<String> subjects})> history = [];
  final List<String> calls = [];
  final List<BrowseCall> browseCalls = [];
  int _seq = 0;

  static const temporaryPassword = 'Tmp7Kx9Qw2';

  void addPerson(String uid, String name, DirectoryRole role, String ref, {bool active = true}) {
    people[uid] = DirectoryPerson(uid: uid, name: name, role: role.wire, academyRef: ref, isActive: active);
  }

  /// P-001 with S-001 and S-002 in H-001 (T-001, V-001); T-002, V-002,
  /// A-001 and an unattached S-003 added later.
  static FakeAcademy seeded({int pageSize = AcademyDirectoryRepository.pageSize}) {
    final f = FakeAcademy(pageSize: pageSize)
      ..addPerson('p1', 'محمد أحمد', DirectoryRole.parent, 'P-001')
      ..addPerson('s1', 'يوسف محمد', DirectoryRole.student, 'S-001')
      ..addPerson('s2', 'مريم محمد', DirectoryRole.student, 'S-002')
      ..addPerson('s3', 'عمر أحمد', DirectoryRole.student, 'S-003')
      ..addPerson('t1', 'أحمد علي', DirectoryRole.teacher, 'T-001')
      ..addPerson('t2', 'خالد حسن', DirectoryRole.teacher, 'T-002')
      ..addPerson('v1', 'سعيد عمر', DirectoryRole.supervisor, 'V-001')
      ..addPerson('v2', 'هشام يوسف', DirectoryRole.supervisor, 'V-002')
      ..addPerson('a1', 'خالد سعيد', DirectoryRole.assistant, 'A-001')
      ..addPerson('ad1', 'مدير الأكاديمية', DirectoryRole.admin, '');
    f.childrenOf['p1'] = {'s1', 's2'};
    f.halaqat['h1'] = FakeHalaqa('h1', 'حلقة الفجر', 'H-001', teacher: 't1', supervisor: 'v1')
      ..students.addAll(['s1', 's2']);
    return f;
  }

  String _name(String uid) => people[uid]?.displayName ?? 'حساب';
  String _halaqaName(String id) => halaqat[id]?.name ?? 'حلقة';

  void _record(Map<String, dynamic> entry) {
    final ids = relationshipEntryIds(entry);
    history.insert(0, (entry: entry, subjects: {...ids.people, ...ids.halaqat}));
  }

  List<RelationshipEvent> _historyOf(String id) => [
    for (final h in history)
      if (h.subjects.contains(id))
        RelationshipEvent(
          kind: '${h.entry['kind']}',
          operation: '${h.entry['operation']}',
          at: DateTime(2026, 10, 31, 12),
          actorName: 'المسؤول',
          description: describeRelationshipEntry(h.entry, person: _name, halaqa: _halaqaName),
        ),
  ];

  HalaqaStaff _staff(FakeHalaqa h) => HalaqaStaff(
    teacher: people[h.teacher],
    supervisor: people[h.supervisor],
    assistants: [for (final a in h.assistants) people[a]!],
    cover: people[h.cover],
  );

  DirectoryHalaqa _summary(FakeHalaqa h) => DirectoryHalaqa(
    id: h.id,
    name: h.name,
    academyRef: h.ref,
    teacherName: _name(h.teacher),
    supervisorName: h.supervisor.isEmpty ? '' : _name(h.supervisor),
    studentCount: h.students.length,
    assistantCount: h.assistants.length,
    hasActiveCover: h.cover.isNotEmpty,
  );

  HalaqaLink _link(FakeHalaqa h, HalaqaRole role) =>
      HalaqaLink(halaqa: _summary(h), role: role, staff: _staff(h));

  List<DirectoryPerson> _parentsOf(String student) => [
    for (final e in childrenOf.entries)
      if (e.value.contains(student)) people[e.key]!,
  ];

  List<HalaqaLink> _studentHalaqat(String student) => [
    for (final h in halaqat.values)
      if (h.students.contains(student)) _link(h, HalaqaRole.student),
  ];

  // ── reads ───────────────────────────────────────────────────────────────

  @override
  Future<DirectoryPage<DirectoryPerson>> browsePeople({
    required DirectoryRole role,
    DirectoryStatusFilter status = DirectoryStatusFilter.all,
    DirectoryRelationFilter relation = DirectoryRelationFilter.none,
    String? halaqaId,
    Object? cursor,
  }) async {
    final all = people.values.where((p) {
      if (p.role != role.wire) return false;
      if (status == DirectoryStatusFilter.active && !p.isActive) return false;
      if (status == DirectoryStatusFilter.inactive && p.isActive) return false;
      if (relation == DirectoryRelationFilter.studentsWithoutHalaqa &&
          _studentHalaqat(p.uid).isNotEmpty) {
        return false;
      }
      if (relation == DirectoryRelationFilter.parentsWithoutChildren &&
          (childrenOf[p.uid] ?? const {}).isNotEmpty) {
        return false;
      }
      if (halaqaId != null && !(halaqat[halaqaId]?.students.contains(p.uid) ?? false)) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
    final start = cursor as int? ?? 0;
    final end = (start + pageSize).clamp(0, all.length);
    final items = all.sublist(start.clamp(0, all.length), end);
    browseCalls.add((
      role: role,
      status: status,
      relation: relation,
      halaqaId: halaqaId,
      cursor: cursor,
      returned: items.length,
    ));
    return DirectoryPage(items: items, cursor: end, hasMore: end < all.length);
  }

  @override
  Future<List<DirectoryPerson>> searchPeople({DirectoryRole? role, required String query}) async {
    calls.add('search:$query');
    final ref = normalizeAcademyRef(query);
    return [
      for (final p in people.values)
        if ((role == null || p.role == role.wire) &&
            (ref != null ? p.academyRef == ref : p.name.contains(query.trim())))
          p,
    ];
  }

  @override
  Future<DirectoryPage<DirectoryHalaqa>> browseHalaqat({
    HalaqaListFilter filter = HalaqaListFilter.all,
    Object? cursor,
  }) async => DirectoryPage(
    items: [
      for (final h in halaqat.values)
        if (filter != HalaqaListFilter.withoutSupervisor || h.supervisor.isEmpty)
          if (filter != HalaqaListFilter.activeCover || h.cover.isNotEmpty) _summary(h),
    ],
  );

  @override
  Future<List<DirectoryHalaqa>> searchHalaqat(String query) async => [
    for (final h in halaqat.values)
      if (h.name.contains(query) || h.ref == normalizeAcademyRef(query)) _summary(h),
  ];

  @override
  Future<List<StructureCount>> structureOverview() async {
    int count(DirectoryRole r) => people.values.where((p) => p.role == r.wire).length;
    return [
      for (final r in DirectoryRole.values) StructureCount(label: r.plural, count: count(r), role: r),
      StructureCount(
        label: 'طلاب بلا حلقة',
        count: people.values
            .where((p) => p.role == DirectoryRole.student.wire && _studentHalaqat(p.uid).isEmpty)
            .length,
        role: DirectoryRole.student,
        relation: DirectoryRelationFilter.studentsWithoutHalaqa,
      ),
      StructureCount(
        label: 'حلقات بلا مشرف',
        count: halaqat.values.where((h) => h.supervisor.isEmpty).length,
        halaqaFilter: HalaqaListFilter.withoutSupervisor,
      ),
    ];
  }

  @override
  Future<PersonProfile> loadPerson(String uid) async {
    final p = people[uid];
    if (p == null) throw const ServerException('الحساب غير موجود');
    final role = DirectoryRole.fromWire(p.role);
    switch (role) {
      case DirectoryRole.student:
        final parents = _parentsOf(uid);
        return PersonProfile(
          person: p,
          parents: parents,
          siblings: {
            for (final parent in parents)
              for (final c in childrenOf[parent.uid]!)
                if (c != uid) c,
          }.map((c) => people[c]!).toList(),
          halaqat: _studentHalaqat(uid),
          history: _historyOf(uid),
        );
      case DirectoryRole.parent:
        return PersonProfile(
          person: p,
          children: [
            for (final c in childrenOf[uid] ?? const <String>{})
              ChildSummary(child: people[c]!, halaqat: _studentHalaqat(c)),
          ],
          history: _historyOf(uid),
        );
      case DirectoryRole.teacher || DirectoryRole.assistant || DirectoryRole.supervisor:
        final links = <HalaqaLink>[
          for (final h in halaqat.values)
            if (h.teacher == uid)
              _link(h, HalaqaRole.primaryTeacher)
            else if (h.cover == uid)
              _link(h, HalaqaRole.cover)
            else if (h.assistants.contains(uid))
              _link(h, HalaqaRole.assistant)
            else if (h.supervisor == uid)
              _link(h, HalaqaRole.supervisor),
        ];
        final students = {
          for (final l in links) ...halaqat[l.halaqa.id]!.students,
        }.map((s) => people[s]!).toList();
        return PersonProfile(
          person: p,
          halaqat: links,
          students: students,
          staff: role == DirectoryRole.supervisor
              ? {
                  for (final l in links) ...[
                    halaqat[l.halaqa.id]!.teacher,
                    ...halaqat[l.halaqa.id]!.assistants,
                  ],
                }.map((s) => people[s]!).toList()
              : const [],
          history: _historyOf(uid),
        );
      case DirectoryRole.admin || null:
        return PersonProfile(person: p);
    }
  }

  @override
  Future<HalaqaProfile> loadHalaqa(String halaqaId) async {
    final h = halaqat[halaqaId];
    if (h == null) throw const ServerException('الحلقة غير موجودة');
    return HalaqaProfile(
      halaqa: _summary(h),
      staff: _staff(h),
      schedule: const ['الأحد 16:00–17:00'],
      students: [
        for (final s in h.students) StudentWithParents(student: people[s]!, parents: _parentsOf(s)),
      ],
      coverPeriods: List.of(h.periods.reversed),
      history: _historyOf(halaqaId),
    );
  }

  @override
  Future<MemberAccount> loadAccount(String uid) async {
    calls.add('account:$uid');
    final p = people[uid]!;
    return accounts[uid] ??
        (p.role == DirectoryRole.admin.wire
            ? const MemberAccount(
                loginKind: 'email',
                username: '',
                isActive: true,
                mustChangePassword: false,
                canResetPassword: false,
              )
            : MemberAccount(
                loginKind: 'username',
                username: 'u${p.academyRef.toLowerCase().replaceAll('-', '')}',
                isActive: true,
                mustChangePassword: false,
                canResetPassword: true,
              ));
  }

  @override
  Future<IssuedCredential> resetPassword(DirectoryPerson person) async {
    calls.add('reset:${person.uid}');
    final current = await loadAccount(person.uid);
    accounts[person.uid] = MemberAccount(
      loginKind: current.loginKind,
      username: current.username,
      isActive: true,
      mustChangePassword: true,
      canResetPassword: true,
      recoveries: [(at: DateTime(2026, 10, 31, 12), actorName: 'المسؤول'), ...current.recoveries],
    );
    return IssuedCredential(
      role: person.role,
      uid: person.uid,
      name: person.name,
      username: current.username,
      temporaryPassword: temporaryPassword,
      academyRef: person.academyRef,
    );
  }

  @override
  Future<IssuedCredential> createMember({required DirectoryRole role, required String name}) async {
    calls.add('create:${role.wire}:$name');
    final prefix = role.wire == 'assistant_teacher' ? 'A' : role.wire[0].toUpperCase();
    final n = people.values.where((p) => p.academyRef.startsWith('$prefix-')).length + 1;
    final ref = '$prefix-${n.toString().padLeft(3, '0')}';
    final uid = 'new${++_seq}';
    addPerson(uid, name, role, ref);
    return IssuedCredential(
      role: role.wire,
      uid: uid,
      name: name,
      username: 'as${100000 + _seq}',
      temporaryPassword: temporaryPassword,
      academyRef: ref,
    );
  }

  // ── relationship changes ───────────────────────────────────────────────

  @override
  Future<void> linkParent({required String parentId, required String studentId}) async {
    calls.add('link:$parentId:$studentId');
    final set = childrenOf.putIfAbsent(parentId, () => {});
    if (!set.add(studentId)) throw const ServerException('الطالب مرتبط بولي الأمر بالفعل');
    _record({'kind': 'parent_child', 'operation': 'link', 'parentId': parentId, 'studentId': studentId});
  }

  @override
  Future<void> unlinkParent({required String parentId, required String studentId}) async {
    calls.add('unlink:$parentId:$studentId');
    childrenOf[parentId]?.remove(studentId);
    _record({'kind': 'parent_child', 'operation': 'unlink', 'parentId': parentId, 'studentId': studentId});
  }

  @override
  Future<void> replaceParent({
    required String studentId,
    required String fromParentId,
    required String toParentId,
  }) async {
    calls.add('replace:$studentId:$fromParentId:$toParentId');
    childrenOf[fromParentId]?.remove(studentId);
    childrenOf.putIfAbsent(toParentId, () => {}).add(studentId);
    _record({
      'kind': 'parent_child',
      'operation': 'replace',
      'parentId': toParentId,
      'previousParentId': fromParentId,
      'studentId': studentId,
    });
  }

  @override
  Future<void> admitStudent({required String halaqaId, required String studentId}) async {
    calls.add('admit:$halaqaId:$studentId');
    if (halaqat.values.any((h) => h.students.contains(studentId))) {
      throw const ServerException('الطالب مسجّل في حلقة؛ استخدم النقل');
    }
    halaqat[halaqaId]!.students.add(studentId);
    _record({'kind': 'halaqa_membership', 'operation': 'admit', 'halaqaId': halaqaId, 'studentId': studentId});
  }

  @override
  Future<void> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  }) async {
    calls.add('transfer:$studentId:$fromHalaqaId:$toHalaqaId');
    halaqat[fromHalaqaId]!.students.remove(studentId);
    halaqat[toHalaqaId]!.students.add(studentId);
    _record({
      'kind': 'halaqa_membership',
      'operation': 'transfer',
      'fromHalaqaId': fromHalaqaId,
      'toHalaqaId': toHalaqaId,
      'studentId': studentId,
    });
  }

  @override
  Future<void> reassignStaff({
    required String halaqaId,
    required DirectoryRole role,
    required String newStaffId,
  }) async {
    calls.add('reassign:$halaqaId:${role.wire}:$newStaffId');
    final h = halaqats(halaqaId);
    if (role == DirectoryRole.teacher) {
      if (newStaffId.isEmpty) throw const ServerException('لا يمكن ترك الحلقة بلا معلم');
      final previous = h.teacher;
      h.teacher = newStaffId;
      _record({
        'kind': 'halaqa_teacher',
        'operation': 'assign',
        'halaqaId': halaqaId,
        'staffId': newStaffId,
        'previousStaffId': previous,
      });
    } else {
      final previous = h.supervisor;
      h.supervisor = newStaffId;
      _record({
        'kind': 'halaqa_supervisor',
        'operation': newStaffId.isEmpty ? 'unassign' : 'assign',
        'halaqaId': halaqaId,
        'staffId': newStaffId,
        'previousStaffId': previous,
      });
    }
  }

  FakeHalaqa halaqats(String id) => halaqat[id]!;

  @override
  Future<void> setAssistant({
    required String halaqaId,
    required String assistantId,
    required bool assign,
  }) async {
    calls.add('assistant:$halaqaId:$assistantId:$assign');
    final h = halaqats(halaqaId);
    if (assign) {
      h.assistants.add(assistantId);
    } else {
      if (h.cover == assistantId) throw const ServerException('أنهِ التغطية أولاً');
      h.assistants.remove(assistantId);
    }
    _record({
      'kind': 'halaqa_assistant',
      'operation': assign ? 'assign' : 'unassign',
      'halaqaId': halaqaId,
      'staffId': assistantId,
    });
  }

  @override
  Future<void> startCover({
    required String halaqaId,
    required String coverTeacherId,
    String reason = '',
  }) async {
    calls.add('cover:start:$halaqaId:$coverTeacherId:$reason');
    final h = halaqats(halaqaId);
    if (h.cover.isNotEmpty) throw const ServerException('توجد تغطية نشطة');
    h.cover = coverTeacherId;
    h.periods.add(
      CoverPeriod(
        cover: people[coverTeacherId]!,
        coverRole: people[coverTeacherId]!.role,
        status: 'active',
        reason: reason,
        startedAt: DateTime(2026, 10, 31, 9),
      ),
    );
    _record({
      'kind': 'halaqa_cover',
      'operation': 'start',
      'halaqaId': halaqaId,
      'staffId': coverTeacherId,
      'previousStaffId': h.teacher,
    });
  }

  @override
  Future<void> endCover({required String halaqaId}) async {
    calls.add('cover:end:$halaqaId');
    final h = halaqats(halaqaId);
    final ended = h.cover;
    h.cover = '';
    final last = h.periods.removeLast();
    h.periods.add(
      CoverPeriod(
        cover: last.cover,
        coverRole: last.coverRole,
        status: 'ended',
        reason: last.reason,
        startedAt: last.startedAt,
        endedAt: DateTime(2026, 10, 31, 11),
      ),
    );
    _record({'kind': 'halaqa_cover', 'operation': 'end', 'halaqaId': halaqaId, 'staffId': ended});
  }
}

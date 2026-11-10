import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../../../shared/utils/attendance_policy.dart';

/// A halaqa seen by an assistant teacher or a covering teacher.
class DutyHalaqa {
  final String id;
  final String name;
  final String teacherName;
  final List<String> schedule;
  final List<String> studentIds;

  /// The caller is the halaqa's active temporary cover (may record).
  final bool isCover;

  /// The caller is an assigned assistant (read-only unless covering).
  final bool isAssigned;

  const DutyHalaqa({
    required this.id,
    required this.name,
    required this.teacherName,
    this.schedule = const [],
    this.studentIds = const [],
    required this.isCover,
    required this.isAssigned,
  });

  String get displayName => name.isEmpty ? 'حلقة' : name;
}

class DutyStudent {
  final String uid;
  final String name;

  const DutyStudent({required this.uid, required this.name});
}

/// Reads only what rules grant the caller (assigned or covered halaqat and
/// single user documents); attendance goes through `recordSessionAttendance`,
/// which re-checks the active cover on the server.
abstract class CoverDutyRepository {
  Future<List<DutyHalaqa>> myHalaqat(String uid, {required bool assistant});

  Future<List<DutyStudent>> roster(DutyHalaqa halaqa);

  /// [marks] maps student → present | absent | late | excused.
  Future<void> recordAttendance({
    required String halaqaId,
    required DateTime day,
    required Map<String, String> marks,
  });
}

class FirestoreCoverDutyRepository implements CoverDutyRepository {
  FirestoreCoverDutyRepository({required this.firestore, required this.functions});

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  CollectionReference<Map<String, dynamic>> get _halaqat =>
      firestore.collection(FirestoreCollections.halaqat);

  static List<String> _ids(Object? v) => [
    for (final x in (v is List ? v : const [])) if (x is String && x.isNotEmpty) x,
  ];

  Future<String> _name(String uid) async {
    if (uid.isEmpty) return '';
    try {
      final d = await firestore.collection(FirestoreCollections.users).doc(uid).get();
      return '${d.data()?['name'] ?? ''}'.trim();
    } catch (_) {
      return '';
    }
  }

  @override
  Future<List<DutyHalaqa>> myHalaqat(String uid, {required bool assistant}) async {
    try {
      final results = await Future.wait([
        if (assistant) _halaqat.where('assistantTeacherIds', arrayContains: uid).get(),
        _halaqat.where('coverTeacherId', isEqualTo: uid).where('coverId', isNotEqualTo: '').get(),
      ]);
      final byId = <String, Map<String, dynamic>>{};
      for (final snap in results) {
        for (final d in snap.docs) {
          byId[d.id] = d.data();
        }
      }
      final out = <DutyHalaqa>[];
      for (final MapEntry(key: id, value: d) in byId.entries) {
        final status = '${d['status'] ?? 'active'}';
        if (status == 'archived' || status == 'closed') continue;
        out.add(
          DutyHalaqa(
            id: id,
            name: '${d['name'] ?? ''}'.trim(),
            teacherName: await _name('${d['teacherId'] ?? ''}'),
            schedule: [
              for (final s in (d['schedule'] as List? ?? const []))
                if (s is Map) '${s['day'] ?? ''} ${s['startTime'] ?? ''}–${s['endTime'] ?? ''}',
            ],
            studentIds: _ids(d['studentIds']),
            isCover: '${d['coverTeacherId'] ?? ''}' == uid && '${d['coverId'] ?? ''}'.isNotEmpty,
            isAssigned: _ids(d['assistantTeacherIds']).contains(uid),
          ),
        );
      }
      out.sort((a, b) {
        if (a.isCover != b.isCover) return a.isCover ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return out;
    } catch (_) {
      throw const ServerException('تعذر تحميل الحلقات، أعد المحاولة');
    }
  }

  @override
  Future<List<DutyStudent>> roster(DutyHalaqa halaqa) async {
    final names = await Future.wait(halaqa.studentIds.map(_name));
    return [
      for (var i = 0; i < halaqa.studentIds.length; i++)
        DutyStudent(uid: halaqa.studentIds[i], name: names[i]),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> recordAttendance({
    required String halaqaId,
    required DateTime day,
    required Map<String, String> marks,
  }) async {
    final d = AttendancePolicy.dayStart(day);
    String two(int v) => v.toString().padLeft(2, '0');
    try {
      await functions.httpsCallable('recordSessionAttendance').call<dynamic>({
        'halaqaId': halaqaId,
        'date': '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}',
        'marks': [
          for (final e in marks.entries) {'studentId': e.key, 'status': e.value},
        ],
      });
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim() ?? '';
      throw ServerException(
        message.isNotEmpty && !message.contains(RegExp('[A-Za-z]{6,}'))
            ? message
            : 'تعذر حفظ الحضور، حاول مرة أخرى',
      );
    } catch (_) {
      throw const ServerException('تعذر حفظ الحضور، حاول مرة أخرى');
    }
  }
}

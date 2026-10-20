import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_operations_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_operations_entities.dart';
import 'package:rafiq_academy/features/homework/data/datasources/homework_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/student/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';

import '../support/fake_callables.dart';

/// Wire contracts between the app and the authoritative callables. Each write
/// below must go through its callable only ([UnusedFirestore] throws on any
/// direct access) and must surface a server rejection as [ServerException].
void main() {
  late FakeFunctions functions;

  setUp(() => functions = FakeFunctions());

  Matcher serverError(String message) =>
      throwsA(isA<ServerException>().having((e) => e.message, 'message', message));

  group('teacher attendance (recordSessionAttendance)', () {
    late TeacherRemoteDatasourceImpl ds;

    setUp(() {
      functions.handlers['recordSessionAttendance'] = (_) => null;
      ds = TeacherRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
    });

    AttendanceRecordModel mark(String studentId, AttendanceStatus status) =>
        AttendanceRecordModel(
          id: '',
          studentId: ' $studentId ',
          studentName: studentId,
          halaqaId: ' h1 ',
          date: DateTime(2026, 9, 1, 12),
          status: status,
          recordedBy: 't1',
          sessionId: '',
        );

    test('sends halaqa, Cairo day and marks only', () async {
      final events = await ds.saveDayAttendance([
        mark('s1', AttendanceStatus.present),
        mark('s2', AttendanceStatus.absent),
      ]);

      expect(events, isEmpty);
      final payload = functions.payloadOf('recordSessionAttendance') as Map;
      expect(payload.keys, unorderedEquals(['halaqaId', 'date', 'marks']));
      expect(payload['halaqaId'], 'h1');
      expect(payload['date'], '2026-09-01');
      expect(payload['marks'], [
        {'studentId': 's1', 'status': 'present'},
        {'studentId': 's2', 'status': 'absent'},
      ]);
    });

    test('an empty register is a no-op', () async {
      expect(await ds.saveDayAttendance(const []), isEmpty);
      expect(functions.calls, isEmpty);
    });

    test('server rejection is surfaced', () async {
      functions.handlers['recordSessionAttendance'] = (_) =>
          throw FakeFunctionsError('failed-precondition', 'الجلسة مغلقة');
      await expectLater(
        ds.saveDayAttendance([mark('s1', AttendanceStatus.present)]),
        serverError('الجلسة مغلقة'),
      );
    });
  });

  group('teacher evaluation (upsertSessionEvaluation)', () {
    late TeacherRemoteDatasourceImpl ds;

    setUp(() {
      functions.handlers['upsertSessionEvaluation'] = (_) => null;
      ds = TeacherRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
    });

    RecitationRecordModel record({
      String? sessionId,
      RecitationGrade? grade = RecitationGrade.good,
      String? notes,
    }) => RecitationRecordModel(
      id: '',
      studentId: 's1',
      studentName: 'أحمد',
      teacherId: 't1',
      halaqaId: 'h1',
      date: DateTime(2026, 9, 1, 12),
      type: RecitationType.memorization,
      versesRange: '',
      sessionId: sessionId,
      grade: grade,
      behaviorGrade: RecitationGrade.excellent,
      notes: notes,
    );

    test('real session id and notes are forwarded', () async {
      await ds.upsertTeacherEvaluation(
        record: record(sessionId: 'sessAbc', notes: ' ممتاز '),
        retireDocumentIds: const ['old1'],
      );

      expect(functions.payloadOf('upsertSessionEvaluation'), {
        'halaqaId': 'h1',
        'studentId': 's1',
        'type': 'memorization',
        'grade': 'good',
        'behaviorGrade': 'excellent',
        'date': '2026-09-01',
        'sessionId': 'sessAbc',
        'notes': 'ممتاز',
      });
    });

    test('legacy synthetic day ids are never sent as a session', () async {
      await ds.upsertTeacherEvaluation(
        record: record(sessionId: 'h1_20260901'),
        retireDocumentIds: const [],
      );

      final payload = functions.payloadOf('upsertSessionEvaluation') as Map;
      expect(payload.containsKey('sessionId'), isFalse);
      expect(payload.containsKey('notes'), isFalse);
    });

    test('missing grade is rejected before the server', () async {
      await expectLater(
        ds.upsertTeacherEvaluation(
          record: record(grade: null),
          retireDocumentIds: const [],
        ),
        serverError('التقييم مطلوب'),
      );
      expect(functions.calls, isEmpty);
    });
  });

  group('homework completion (completeHomework)', () {
    late HomeworkRemoteDatasourceImpl ds;

    setUp(() {
      ds = HomeworkRemoteDatasourceImpl(
        UnusedFirestore(),
        UnusedStorage(),
        functions,
      );
    });

    test('sends the assignment id; reward comes from the server', () async {
      functions.handlers['completeHomework'] = (_) => {'awardedCoins': 7};

      expect(await ds.completeHomework(' hw1 '), 7);
      expect(functions.payloadOf('completeHomework'), {'assignmentId': 'hw1'});
    });

    test('legacy awardedPoints and a missing reward are tolerated', () async {
      functions.handlers['completeHomework'] = (_) => {'awardedPoints': 3};
      expect(await ds.completeHomework('hw1'), 3);

      functions.handlers['completeHomework'] = (_) => {'ok': true};
      expect(await ds.completeHomework('hw1'), 0);
    });

    test('server rejection is surfaced', () async {
      functions.handlers['completeHomework'] = (_) =>
          throw FakeFunctionsError('failed-precondition', 'لم تكتمل المهام');
      await expectLater(ds.completeHomework('hw1'), serverError('لم تكتمل المهام'));
    });
  });

  group('supervisor admission (admitStudentToHalaqa)', () {
    test('sends trimmed halaqa + student; denial surfaced', () async {
      final ds = SupervisorRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
      functions.handlers['admitStudentToHalaqa'] = (_) => null;

      await ds.registerNewStudent(halaqaId: ' h1 ', studentId: ' s9 ');
      expect(functions.payloadOf('admitStudentToHalaqa'), {
        'halaqaId': 'h1',
        'studentId': 's9',
      });

      functions.handlers['admitStudentToHalaqa'] = (_) =>
          throw FakeFunctionsError('permission-denied', 'خارج نطاق إشرافك');
      await expectLater(
        ds.registerNewStudent(halaqaId: 'h2', studentId: 's9'),
        serverError('خارج نطاق إشرافك'),
      );
    });
  });

  group('admin provisioning + billing', () {
    late AdminRemoteDatasourceImpl ds;

    setUp(() {
      ds = AdminRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
    });

    test('provision sends no phone and returns the uid', () async {
      functions.handlers['adminProvisionUser'] = (_) => {'uid': 'newUid'};

      final uid = await ds.provisionUser(
        email: ' a@x.test ',
        password: 'secret1',
        name: ' طالب ',
        role: 'student',
      );

      expect(uid, 'newUid');
      expect(functions.payloadOf('adminProvisionUser'), {
        'email': 'a@x.test',
        'password': 'secret1',
        'name': 'طالب',
        'role': 'student',
        'isActive': true,
      });
    });

    test('provision without a uid in the reply is an error', () async {
      functions.handlers['adminProvisionUser'] = (_) => {'ok': true};
      await expectLater(
        ds.provisionUser(
          email: 'a@x.test',
          password: 'secret1',
          name: 'n',
          role: 'student',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('invoice generation forwards only provided fields', () async {
      functions.handlers['adminGenerateInvoice'] =
          (_) => {'paymentId': 'inv_s1_2026-10'};

      final id = await ds.generateInvoice(studentId: ' s1 ', periodKey: '2026-10');

      expect(id, 'inv_s1_2026-10');
      expect(functions.payloadOf('adminGenerateInvoice'), {
        'studentId': 's1',
        'periodKey': '2026-10',
      });
    });

    test('reinstate access forwards an optional reason', () async {
      functions.handlers['adminReinstatePaymentAccess'] = (_) => null;

      await ds.reinstatePaymentAccess(parentId: 'p1', reason: '  ');
      expect(functions.payloadOf('adminReinstatePaymentAccess'), {'parentId': 'p1'});

      await ds.reinstatePaymentAccess(parentId: 'p1', reason: ' تم السداد ');
      expect(functions.payloadOf('adminReinstatePaymentAccess'), {
        'parentId': 'p1',
        'reason': 'تم السداد',
      });
    });
  });

  group('admin operations', () {
    late AdminOperationsRemoteDatasourceImpl ds;

    setUp(() {
      ds = AdminOperationsRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
    });

    test('link parent ↔ child maps the server result', () async {
      functions.handlers['adminLinkParentChild'] = (_) => {
        'childrenIds': ['c1', 'c2'],
        'changed': true,
      };

      final result = await ds.linkParentChild(
        parentId: 'p1',
        studentId: 'c2',
        operation: ParentLinkOperation.link,
      );

      expect(functions.payloadOf('adminLinkParentChild'), {
        'parentId': 'p1',
        'studentId': 'c2',
        'operation': 'link',
      });
      expect(result.childrenIds, ['c1', 'c2']);
      expect(result.changed, isTrue);
    });

    test('create halaqa without an id in the reply is an error', () async {
      functions.handlers['adminCreateHalaqa'] = (_) => const <String, Object>{};
      await expectLater(
        ds.createHalaqa(
          name: 'حلقة',
          teacherId: 't1',
          schedule: const [],
          requestId: 'req_0123456789',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('review decision omits blank notes', () async {
      functions.handlers['reviewPaymentProof'] = (_) => null;

      await ds.reviewPaymentProof(
        paymentId: 'inv1',
        decision: PaymentReviewDecision.reject,
        notes: ' ',
      );

      expect(functions.payloadOf('reviewPaymentProof'), {
        'paymentId': 'inv1',
        'decision': 'reject',
      });
    });

    test('server denial is surfaced', () async {
      functions.handlers['adminTransferStudent'] = (_) =>
          throw FakeFunctionsError('permission-denied', 'للمسؤول فقط');
      await expectLater(
        ds.transferStudent(
          studentId: 's1',
          fromHalaqaId: 'h1',
          toHalaqaId: 'h2',
        ),
        serverError('للمسؤول فقط'),
      );
    });
  });
}

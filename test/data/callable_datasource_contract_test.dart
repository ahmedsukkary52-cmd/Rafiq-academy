import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_operations_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/admin/domain/entities/admin_operations_entities.dart';
import 'package:rafiq_academy/features/homework/data/datasources/homework_remote_datasource_impl.dart';
import 'package:rafiq_academy/shared/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/features/supervisor/data/data_sources/supervisor_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/payment_review_params.dart'
    as supervisor;
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/shared/domain/attendance_record_entity.dart';
import 'package:rafiq_academy/shared/domain/payment_review_amounts.dart';

import '../support/fake_callables.dart';

/// Wire contracts between the app and the authoritative callables. Each write
/// below must go through its callable only ([UnusedFirestore] throws on any
/// direct access) and must surface a server rejection as [ServerException].
void main() {
  late FakeFunctions functions;

  setUp(() => functions = FakeFunctions());

  Matcher serverError(String message) => throwsA(
    isA<ServerException>().having((e) => e.message, 'message', message),
  );

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
      await expectLater(
        ds.completeHomework('hw1'),
        serverError('لم تكتمل المهام'),
      );
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

  group('supervisor payment review (reviewPaymentProof)', () {
    late SupervisorRemoteDatasourceImpl ds;

    setUp(() {
      ds = SupervisorRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
      );
      functions.handlers['reviewPaymentProof'] = (_) => null;
    });

    supervisor.PaymentReviewParams params(PaymentReviewCommand command) =>
        supervisor.PaymentReviewParams(
          supervisorId: 'sup1',
          command: command,
          requestId: 'req_0123456789abcdef',
          snapshot: const PaymentAmountSnapshot(invoice: 20000, previous: 6000),
        );

    test('partial receipt uses the current contract only', () async {
      await ds.reviewPaymentProof(
        params(
          PaymentReviewCommand(
            paymentId: ' inv1 ',
            decision: supervisor.PaymentReviewDecision.partial.wire,
            notes: ' جزء ',
            amountMode: PaymentAmountMode.receipt,
            amountMinorUnits: 5000,
            expectedProofFileName: '1790000000000.jpg',
          ),
        ),
      );
      expect(functions.payloadOf('reviewPaymentProof'), {
        'paymentId': 'inv1',
        'decision': 'partial',
        'notes': 'جزء',
        'requestId': 'req_0123456789abcdef',
        'expectedProofFileName': '1790000000000.jpg',
        'amountMode': 'receipt',
        'amountValue': 50.0,
      });
    });

    test('approval sends no amount and no remainingAmount', () async {
      await ds.reviewPaymentProof(
        params(
          PaymentReviewCommand(
            paymentId: 'inv1',
            decision: supervisor.PaymentReviewDecision.approved.wire,
            expectedProofFileName: '1790000000000.jpg',
          ),
        ),
      );
      final payload = functions.payloadOf('reviewPaymentProof') as Map;
      expect(
        payload.keys,
        unorderedEquals([
          'paymentId',
          'decision',
          'requestId',
          'expectedProofFileName',
        ]),
      );
      expect(payload['decision'], 'approve');
    });

    test('a changed proof surfaces the server message verbatim', () async {
      functions.handlers['reviewPaymentProof'] = (_) =>
          throw FakeFunctionsError(
            'failed-precondition',
            kPaymentProofChangedMessage,
          );
      await expectLater(
        ds.reviewPaymentProof(
          params(
            PaymentReviewCommand(
              paymentId: 'inv1',
              decision: supervisor.PaymentReviewDecision.rejected.wire,
              expectedProofFileName: '1790000000000.jpg',
            ),
          ),
        ),
        serverError(kPaymentProofChangedMessage),
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
      functions.handlers['adminGenerateInvoice'] = (_) => {
        'paymentId': 'inv_s1_2026-10',
      };

      final id = await ds.generateInvoice(
        studentId: ' s1 ',
        periodKey: '2026-10',
      );

      expect(id, 'inv_s1_2026-10');
      expect(functions.payloadOf('adminGenerateInvoice'), {
        'studentId': 's1',
        'periodKey': '2026-10',
      });
    });

    test('P2-2: account activation goes through adminSetMemberActive only', () async {
      functions.handlers['adminSetMemberActive'] = (_) => null;

      await ds.toggleAccountStatus(uid: ' p1 ', isActive: false);
      expect(functions.payloadOf('adminSetMemberActive'), {
        'uid': 'p1',
        'isActive': false,
      });

      await ds.rejectRegistrationRequest(studentId: ' s9 ');
      expect(functions.payloadOf('adminSetMemberActive'), {
        'uid': 's9',
        'isActive': false,
      });
    });

    test('P2-2: a refused activation is surfaced', () async {
      functions.handlers['adminSetMemberActive'] = (_) =>
          throw FakeFunctionsError('failed-precondition', 'الطالب مؤرشف؛ ألغِ الأرشفة أولاً');
      await expectLater(
        ds.toggleAccountStatus(uid: 's1', isActive: true),
        serverError('الطالب مؤرشف؛ ألغِ الأرشفة أولاً'),
      );
    });

    test('reinstate access forwards an optional reason', () async {
      functions.handlers['adminReinstatePaymentAccess'] = (_) => null;

      await ds.reinstatePaymentAccess(parentId: 'p1', reason: '  ');
      expect(functions.payloadOf('adminReinstatePaymentAccess'), {
        'parentId': 'p1',
      });

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

    test('review decision omits blank notes and never sends amounts', () async {
      // Real callable returns a result map; null is not a valid wire response.
      functions.handlers['reviewPaymentProof'] = (_) => <String, dynamic>{};

      await ds.reviewPaymentProof(
        command: PaymentReviewCommand(
          paymentId: 'inv1',
          decision: PaymentReviewWire.reject,
          notes: ' ',
          expectedProofFileName: '1790000000000.jpg',
        ),
        requestId: 'req_0123456789abcdef',
      );

      expect(functions.payloadOf('reviewPaymentProof'), {
        'paymentId': 'inv1',
        'decision': 'reject',
        'requestId': 'req_0123456789abcdef',
        'expectedProofFileName': '1790000000000.jpg',
      });
    });

    test(
      'partial review sends mode + value, never amountPaidConfirmed',
      () async {
        functions.handlers['reviewPaymentProof'] = (_) => <String, dynamic>{};

        await ds.reviewPaymentProof(
          command: PaymentReviewCommand(
            paymentId: 'inv1',
            decision: PaymentReviewWire.partial,
            amountMode: PaymentAmountMode.cumulative,
            amountMinorUnits: 15050,
            expectedProofFileName: '1790000000000.jpg',
          ),
          requestId: 'req_0123456789abcdef',
        );

        final payload = functions.payloadOf('reviewPaymentProof') as Map;
        expect(payload['amountMode'], 'cumulative');
        expect(payload['amountValue'], 150.5);
        expect(payload.containsKey('amountPaidConfirmed'), isFalse);
      },
    );

    test('a changed proof surfaces the server message verbatim', () async {
      functions.handlers['reviewPaymentProof'] = (_) =>
          throw FakeFunctionsError(
            'failed-precondition',
            kPaymentProofChangedMessage,
          );
      await expectLater(
        ds.reviewPaymentProof(
          command: PaymentReviewCommand(
            paymentId: 'inv1',
            decision: PaymentReviewWire.approve,
            expectedProofFileName: '1790000000000.jpg',
          ),
          requestId: 'req_0123456789abcdef',
        ),
        serverError(kPaymentProofChangedMessage),
      );
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

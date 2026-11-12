import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/complaints/data/complaints_repository.dart';
import 'package:rafiq_academy/features/complaints/domain/complaint.dart';

import '../../support/fake_callables.dart';

/// Complaints are written only through `submitComplaint` /
/// `respondToComplaint` ([UnusedFirestore] throws on any direct write).
void main() {
  late FakeFunctions functions;
  late ComplaintsRepository repo;

  setUp(() {
    functions = FakeFunctions();
    repo = ComplaintsRepository(
      firestore: UnusedFirestore(),
      functions: functions,
    );
  });

  test('submit sends trimmed text and only the chosen context', () async {
    functions.handlers['submitComplaint'] = (_) => {'complaintId': 'c1'};
    final id = await repo.submit(
      subject: '  تأخر  ',
      message: ' نص ',
      studentId: 's1',
    );
    expect(id, 'c1');
    expect(functions.payloadOf('submitComplaint'), {
      'subject': 'تأخر',
      'message': 'نص',
      'studentId': 's1',
    });
  });

  test('submit never sends a priority or sender identity', () async {
    functions.handlers['submitComplaint'] = (_) => {'complaintId': 'c2'};
    await repo.submit(subject: 's', message: 'm', halaqaId: 'h1');
    final payload = functions.payloadOf('submitComplaint') as Map;
    expect(payload.keys, unorderedEquals(['subject', 'message', 'halaqaId']));
  });

  test('admin respond sends message and status wire value', () async {
    functions.handlers['respondToComplaint'] = (_) => {'status': 'resolved'};
    final status = await repo.respond(
      complaintId: 'c1',
      message: ' تم ',
      status: ComplaintStatus.resolved,
    );
    expect(status, ComplaintStatus.resolved);
    expect(functions.payloadOf('respondToComplaint'), {
      'complaintId': 'c1',
      'message': 'تم',
      'status': 'resolved',
    });
  });

  test('status-only respond omits the empty message', () async {
    functions.handlers['respondToComplaint'] = (_) => {'status': 'archived'};
    await repo.respond(
      complaintId: 'c1',
      message: '  ',
      status: ComplaintStatus.archived,
    );
    expect(functions.payloadOf('respondToComplaint'), {
      'complaintId': 'c1',
      'status': 'archived',
    });
  });

  test('server rejection surfaces the backend message', () async {
    functions.handlers['respondToComplaint'] = (_) =>
        throw FakeFunctionsError('permission-denied', 'تغيير الحالة متاح للإدارة فقط');
    await expectLater(
      repo.respond(complaintId: 'c1', status: ComplaintStatus.resolved),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'تغيير الحالة متاح للإدارة فقط',
        ),
      ),
    );
  });

  group('domain', () {
    test('unknown wire status falls back to open', () {
      expect(ComplaintStatus.fromWire('weird'), ComplaintStatus.open);
      expect(ComplaintStatus.fromWire('in_progress'), ComplaintStatus.inProgress);
      expect(ComplaintStatus.resolved.isClosed, isTrue);
      expect(ComplaintStatus.inProgress.isClosed, isFalse);
    });

    test('form validation', () {
      expect(ComplaintFormValidation.subject('  '), isNotNull);
      expect(ComplaintFormValidation.subject('x' * 121), isNotNull);
      expect(ComplaintFormValidation.subject('عنوان'), isNull);
      expect(ComplaintFormValidation.message(''), isNotNull);
      expect(ComplaintFormValidation.message('x' * 2001), isNotNull);
      expect(ComplaintFormValidation.message('نص'), isNull);
    });

    test('context line names student and halaqa, never ids', () {
      final c = Complaint(
        id: 'c1',
        senderId: 'p1',
        senderRole: 'parent',
        senderName: 'ولي',
        subject: 's',
        message: 'm',
        status: ComplaintStatus.open,
        createdAt: DateTime(2026),
        studentId: 's1',
        studentName: 'أحمد',
        halaqaId: 'h1',
        halaqaName: 'النور',
      );
      expect(c.contextLine, 'الطالب: أحمد · الحلقة: النور');
      expect(c.contextLine.contains('s1'), isFalse);
    });
  });
}

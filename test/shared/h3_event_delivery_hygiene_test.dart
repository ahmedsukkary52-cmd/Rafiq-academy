import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/admin/domain/admin_ops_broadcast.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';
import 'package:rafiq_academy/shared/domain/fan_out_academy_event_sink.dart';

void main() {
  group('H3 event delivery hygiene', () {
    test('sole in_app handler fan-out reports success unchanged', () async {
      final handler = _NamedHandler('in_app');
      final sink = FanOutAcademyEventSink(handlers: [handler]);

      final report = await sink.publish([
        StudentAbsentRecorded(
          studentId: 's1',
          studentName: 'أحمد',
          halaqaId: 'h1',
          date: DateTime(2024, 6, 3),
          attendanceDocumentId: 'doc1',
        ),
      ]);

      expect(report.handlers, hasLength(1));
      expect(report.handlers.single.handlerName, 'in_app');
      expect(report.handlers.single.succeeded, isTrue);
      expect(report.anySucceeded, isTrue);
      expect(report.allFailed, isFalse);
    });

    test('admin ops broadcast stays outside academy-event fields', () {
      final fields = AdminOpsBroadcast.notificationFields(
        title: 'تنبيه',
        body: 'نص',
        targetRole: 'student',
      );

      expect(AdminOpsBroadcast.channel, 'admin_ops_broadcast');
      expect(fields[AdminOpsBroadcast.audienceField], 'student');
      expect(fields[AdminOpsBroadcast.typeField], NotificationTypes.general);
      expect(fields.containsKey('eventId'), isFalse);
      expect(fields.containsKey('recipientId'), isFalse);
    });

    test('HomeworkReviewed remains a publishable academy fact', () {
      final event = HomeworkReviewed(
        recitationRecordId: 'r1',
        studentId: 's1',
        halaqaId: 'h1',
        date: DateTime(2024, 6, 3),
        grade: 'A',
        versesRange: '1-5',
      );
      expect(event.eventId, isNotEmpty);
      expect(event.studentId, 's1');
    });
  });
}

class _NamedHandler implements AcademyEventHandler {
  @override
  final String name;
  _NamedHandler(this.name);

  @override
  Future<void> handle(Iterable<AcademyEvent> events) async {}
}

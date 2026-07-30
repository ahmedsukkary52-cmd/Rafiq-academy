import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';
import 'package:rafiq_academy/shared/domain/fan_out_academy_event_sink.dart';

void main() {
  final earlier = StudentAbsentRecorded(
    studentId: 's1',
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: DateTime(2024, 6, 3),
    attendanceDocumentId: 'doc1',
  );
  final later = HomeworkAssigned(
    assignmentId: 'a1',
    studentId: 's1',
    halaqaId: 'h1',
    assignedBy: 't1',
    dueDate: DateTime(2024, 6, 3),
    newMemorizationRange: '1-5',
    reviewRange: '',
  );

  group('FanOutAcademyEventSink', () {
    test('preserves publisher event order for every handler', () async {
      final handler = _RecordingHandler('a');
      final sink = FanOutAcademyEventSink(handlers: [handler]);

      final report = await sink.publish([earlier, later]);

      expect(handler.seen.map((e) => e.eventId).toList(), [
        earlier.eventId,
        later.eventId,
      ]);
      expect(report.handlers.single.succeeded, isTrue);
      expect(report.handlers.single.handlerName, 'a');
    });

    test('one handler failure does not stop the other', () async {
      final ok = _RecordingHandler('ok');
      final sink = FanOutAcademyEventSink(
        handlers: [_FailingHandler('bad'), ok],
      );

      final report = await sink.publish([earlier]);

      expect(ok.calls, 1);
      expect(report.anySucceeded, isTrue);
      expect(report.allFailed, isFalse);
      expect(report.handlers.map((h) => h.succeeded).toList(), [false, true]);
    });

    test('fails only when every handler fails', () async {
      final sink = FanOutAcademyEventSink(
        handlers: [_FailingHandler('a'), _FailingHandler('b')],
      );

      expect(() => sink.publish([earlier]), throwsA(isA<ServerException>()));
    });

    test(
      'empty event list returns empty report without calling handlers',
      () async {
        final handler = _RecordingHandler('a');
        final sink = FanOutAcademyEventSink(handlers: [handler]);

        final report = await sink.publish(const []);

        expect(handler.calls, 0);
        expect(report.handlers, isEmpty);
      },
    );
  });
}

class _RecordingHandler implements AcademyEventHandler {
  @override
  final String name;
  int calls = 0;
  List<AcademyEvent> seen = const [];

  _RecordingHandler(this.name);

  @override
  Future<void> handle(Iterable<AcademyEvent> events) async {
    calls++;
    seen = events.toList();
  }
}

class _FailingHandler implements AcademyEventHandler {
  @override
  final String name;

  _FailingHandler(this.name);

  @override
  Future<void> handle(Iterable<AcademyEvent> events) async {
    throw const ServerException('handler down');
  }
}

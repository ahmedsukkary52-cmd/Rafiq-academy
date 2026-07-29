import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';
import 'package:rafiq_academy/shared/domain/fan_out_academy_event_sink.dart';

void main() {
  final event = StudentAbsentRecorded(
    studentId: 's1',
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: DateTime(2024, 6, 3),
    attendanceDocumentId: 'doc1',
  );

  group('FanOutAcademyEventSink', () {
    test(
      'publisher does not need to know handlers — empty is a no-op',
      () async {
        final sink = FanOutAcademyEventSink(handlers: const []);
        await sink.publish([event]);
      },
    );

    test('runs every handler', () async {
      final a = _RecordingHandler();
      final b = _RecordingHandler();
      final sink = FanOutAcademyEventSink(handlers: [a, b]);

      await sink.publish([event]);

      expect(a.calls, 1);
      expect(b.calls, 1);
    });

    test('one handler failure does not stop the other', () async {
      final ok = _RecordingHandler();
      final sink = FanOutAcademyEventSink(handlers: [_FailingHandler(), ok]);

      await sink.publish([event]);

      expect(ok.calls, 1);
    });

    test('fails only when every handler fails', () async {
      final sink = FanOutAcademyEventSink(
        handlers: [_FailingHandler(), _FailingHandler()],
      );

      expect(() => sink.publish([event]), throwsA(isA<ServerException>()));
    });
  });
}

class _RecordingHandler implements AcademyEventHandler {
  int calls = 0;

  @override
  Future<void> handle(Iterable<AcademyEvent> events) async {
    calls++;
  }
}

class _FailingHandler implements AcademyEventHandler {
  @override
  Future<void> handle(Iterable<AcademyEvent> events) async {
    throw const ServerException('handler down');
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:rafiq_academy/features/notifications/data/models/notification_model.dart';
import 'package:rafiq_academy/features/notifications/data/sinks/in_app_academy_event_sink.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/notification_signal.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_observer_resolver.dart';

void main() {
  final date = DateTime(2024, 6, 3);

  StudentAbsentRecorded absent(String studentId) => StudentAbsentRecorded(
    studentId: studentId,
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: date,
    attendanceDocumentId: 'h1_${studentId}_20240603',
  );

  HomeworkAssigned assigned(String studentId) => HomeworkAssigned(
    assignmentId: 'a_$studentId',
    studentId: studentId,
    studentName: 'أحمد',
    halaqaId: 'h1',
    dueDate: date,
    newMemorizationRange: '1-5',
    reviewRange: '',
  );

  late _FakeObserverResolver observers;
  late _FakeNotificationsDatasource notifications;
  late InAppAcademyEventSink sink;

  setUp(() {
    observers = _FakeObserverResolver();
    notifications = _FakeNotificationsDatasource();
    sink = InAppAcademyEventSink(
      observerResolver: observers,
      notificationsDatasource: notifications,
    );
  });

  group('InAppAcademyEventSink', () {
    test('no events → no resolve and no write', () async {
      await sink.publish(const []);

      expect(observers.callCount, 0);
      expect(notifications.written, isEmpty);
    });

    test('resolves observers then writes one signal per observer', () async {
      final e1 = absent('s1');
      final e2 = absent('s2');
      observers.result = {
        e1.eventId: ['p1'],
        e2.eventId: ['p2'],
      };

      await sink.publish([e1, e2]);

      expect(observers.callCount, 1);
      expect(notifications.written.map((s) => s.audience), ['p1', 'p2']);
    });

    test('homework fact can address student and parent observers', () async {
      final event = assigned('s1');
      observers.result = {
        event.eventId: ['s1', 'p1'],
      };

      await sink.publish([event]);

      expect(notifications.written.map((s) => s.audience), ['s1', 'p1']);
    });

    test('no observers is not an error and writes nothing', () async {
      final event = absent('s1');
      observers.result = {event.eventId: <String>[]};

      await sink.publish([event]);

      expect(notifications.written, isEmpty);
    });

    test('observer resolve failure is not reported as delivered', () async {
      observers.fail = true;

      expect(
        () => sink.publish([absent('s1')]),
        throwsA(isA<ServerException>()),
      );
      expect(notifications.written, isEmpty);
    });

    test('write failure propagates to the caller', () async {
      final event = absent('s1');
      observers.result = {
        event.eventId: ['p1'],
      };
      notifications.failOnWrite = true;

      expect(() => sink.publish([event]), throwsA(isA<ServerException>()));
    });
  });
}

class _FakeObserverResolver implements AcademyEventObserverResolver {
  Map<String, List<String>> result = const {};
  bool fail = false;
  int callCount = 0;

  @override
  Future<Map<String, List<String>>> resolve(
    Iterable<AcademyEvent> events,
  ) async {
    callCount++;
    if (fail) throw const ServerException('resolve failed');
    return result;
  }
}

class _FakeNotificationsDatasource implements NotificationsRemoteDatasource {
  final List<NotificationSignal> written = [];
  bool failOnWrite = false;

  @override
  Future<void> upsertSignals(List<NotificationSignal> signals) async {
    if (failOnWrite) throw const ServerException('write failed');
    written.addAll(signals);
  }

  @override
  Stream<List<NotificationModel>> watchNotifications({
    required String uid,
    required String role,
  }) => throw UnimplementedError();
  @override
  Future<void> markAsRead({
    required String notificationId,
    required String uid,
  }) => throw UnimplementedError();
  @override
  Future<void> markAllAsRead({
    required List<String> notificationIds,
    required String uid,
  }) => throw UnimplementedError();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:rafiq_academy/features/notifications/data/models/notification_model.dart';
import 'package:rafiq_academy/features/notifications/data/sinks/in_app_academy_event_sink.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/notification_signal.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';

void main() {
  final date = DateTime(2024, 6, 3);

  StudentAbsentRecorded absent(String studentId) => StudentAbsentRecorded(
    studentId: studentId,
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: date,
    attendanceDocumentId: 'h1_${studentId}_20240603',
  );

  late _FakeParentRepository parents;
  late _FakeNotificationsDatasource notifications;
  late InAppAcademyEventSink sink;

  setUp(() {
    parents = _FakeParentRepository();
    notifications = _FakeNotificationsDatasource();
    sink = InAppAcademyEventSink(
      parentRepository: parents,
      notificationsDatasource: notifications,
    );
  });

  group('InAppAcademyEventSink', () {
    test('no events → no lookup and no write', () async {
      await sink.publish(const []);

      expect(parents.requestedStudentIds, isNull);
      expect(notifications.written, isEmpty);
    });

    test('resolves recipients once for the whole batch', () async {
      parents.result = const {
        's1': ['p1'],
        's2': ['p2'],
      };

      await sink.publish([absent('s1'), absent('s2')]);

      expect(parents.callCount, 1);
      expect(parents.requestedStudentIds, ['s1', 's2']);
      expect(notifications.written.map((s) => s.audience), ['p1', 'p2']);
    });

    test('multiple parents of one student each receive a message', () async {
      parents.result = const {
        's1': ['p1', 'p2'],
      };

      await sink.publish([absent('s1')]);

      expect(notifications.written.map((s) => s.audience), ['p1', 'p2']);
    });

    test('no linked parent is not an error and writes nothing', () async {
      parents.result = const {};

      await sink.publish([absent('s1')]);

      expect(notifications.written, isEmpty);
    });

    test('recipient lookup failure is not reported as delivered', () async {
      parents.failure = const ServerFailure('lookup down');

      expect(
        () => sink.publish([absent('s1')]),
        throwsA(isA<ServerException>()),
      );
      expect(notifications.written, isEmpty);
    });

    test('write failure propagates to the caller', () async {
      parents.result = const {
        's1': ['p1'],
      };
      notifications.failOnWrite = true;

      expect(
        () => sink.publish([absent('s1')]),
        throwsA(isA<ServerException>()),
      );
    });
  });
}

class _FakeParentRepository implements ParentRepository {
  Map<String, List<String>> result = const {};
  Failure? failure;
  List<String>? requestedStudentIds;
  int callCount = 0;

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    callCount++;
    requestedStudentIds = studentIds;
    if (failure != null) return Left(failure!);
    return Right(result);
  }

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  ) => throw UnimplementedError();
  @override
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, PaymentInitiationEntity>> initiatePayment(
    String paymentId,
  ) => throw UnimplementedError();
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

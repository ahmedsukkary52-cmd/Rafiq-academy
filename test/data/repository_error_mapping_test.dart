import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:rafiq_academy/features/auth/data/models/user_model.dart';
import 'package:rafiq_academy/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:rafiq_academy/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:rafiq_academy/features/notifications/data/models/notification_model.dart';
import 'package:rafiq_academy/features/notifications/data/repositories/notifiaction_repository.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart';
import 'package:rafiq_academy/features/parent/data/repositories/parent_repository_impl.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/features/teacher/data/repositories/teacher_repository_impl.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/data/absence_request_model.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';

import '../support/fake_callables.dart';

// ── Auth ─────────────────────────────────────────────────────────────────

class _AuthDs extends Fake implements AuthRemoteDatasource {
  Object? error;
  int loginCalls = 0;

  @override
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    throw error!;
  }

  @override
  Future<void> logout() async {
    if (error != null) throw error!;
  }
}

// ── Parent ───────────────────────────────────────────────────────────────

class _ParentDs extends Fake implements ParentRemoteDatasource {
  Object? proofError;
  final submittedAbsence = <AbsenceRequestModel>[];

  @override
  Future<void> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  }) async {
    if (proofError != null) throw proofError!;
  }

  @override
  Future<void> submitAbsenceRequest(AbsenceRequestModel request) async {
    submittedAbsence.add(request);
  }
}

// ── Teacher ──────────────────────────────────────────────────────────────

class _TeacherDs extends Fake implements TeacherRemoteDatasource {
  List<AcademyEvent> events = const [];
  Object? error;
  final saved = <List<AttendanceRecordModel>>[];

  @override
  Future<List<AcademyEvent>> saveDayAttendance(
    List<AttendanceRecordModel> records,
  ) async {
    saved.add(records);
    if (error != null) throw error!;
    return events;
  }
}

class _Sink implements AcademyEventSink {
  Object? error;
  AcademyEventPublishReport report = const AcademyEventPublishReport.empty();

  @override
  Future<AcademyEventPublishReport> publish(
    Iterable<AcademyEvent> events,
  ) async {
    if (error != null) throw error!;
    return report;
  }
}

// ── Notifications ────────────────────────────────────────────────────────

class _NotificationsDs extends Fake implements NotificationsRemoteDatasource {
  final controller = StreamController<List<NotificationModel>>();
  int markCalls = 0;

  @override
  Stream<List<NotificationModel>> watchNotifications({
    required String uid,
    required String role,
  }) => controller.stream;

  @override
  Future<void> markAsRead({
    required String notificationId,
    required String uid,
  }) async {
    markCalls++;
  }
}

final _absentEvent = StudentAbsentRecorded(
  studentId: 's1',
  studentName: 'أحمد',
  halaqaId: 'h1',
  date: DateTime(2026, 9, 1),
  attendanceDocumentId: 'att1',
);

AttendanceRecordEntity _mark() => AttendanceRecordEntity(
  id: 'att1',
  studentId: 's1',
  studentName: 'أحمد',
  halaqaId: 'h1',
  date: DateTime(2026, 9, 1, 12),
  status: AttendanceStatus.absent,
  recordedBy: 't1',
  sessionId: 'sess1',
);

void main() {
  group('AuthRepositoryImpl', () {
    late _AuthDs ds;
    late FakeNetworkInfo network;
    late AuthRepositoryImpl repo;

    setUp(() {
      ds = _AuthDs();
      network = FakeNetworkInfo();
      repo = AuthRepositoryImpl(remoteDatasource: ds, networkInfo: network);
    });

    test('offline login fails fast without touching Firebase', () async {
      network.connected = false;
      final result = await repo.loginWithEmail(email: 'a@x', password: 'p');

      expect(result, const Left<Failure, Never>(NetworkFailure()));
      expect(ds.loginCalls, 0);
    });

    test('AuthException keeps its reason for the UI', () async {
      ds.error = const AuthException(
        'الحساب معطل',
        reason: AuthErrorReason.disabled,
      );
      final result = await repo.loginWithEmail(email: 'a@x', password: 'p');

      result.match(
        (f) {
          expect(f, isA<AuthFailure>());
          expect((f as AuthFailure).reason, AuthErrorReason.disabled);
          expect(f.message, 'الحساب معطل');
        },
        (_) => fail('disabled account must not sign in'),
      );
    });

    test('ServerException and unknown errors are mapped, not thrown', () async {
      ds.error = const ServerException('تعذر');
      expect(
        await repo.loginWithEmail(email: 'a@x', password: 'p'),
        const Left<Failure, Never>(ServerFailure('تعذر')),
      );

      ds.error = StateError('boom');
      expect(
        await repo.loginWithEmail(email: 'a@x', password: 'p'),
        const Left<Failure, Never>(UnexpectedFailure()),
      );
    });

    test('logout is not blocked by connectivity', () async {
      network.connected = false;
      expect(await repo.logout(), const Right<Failure, Unit>(unit));
    });
  });

  group('ParentRepositoryImpl', () {
    late _ParentDs ds;
    late ParentRepositoryImpl repo;

    setUp(() {
      ds = _ParentDs();
      repo = ParentRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: FakeNetworkInfo(),
      );
    });

    Future<Either<Failure, Unit>> submitProof() => repo.submitPaymentProof(
      parentId: 'p1',
      paymentId: 'inv1',
      localFilePath: '/tmp/a.jpg',
    );

    test('user-correctable proof errors become ValidationFailure', () async {
      for (final message in const [
        'تم رفع الإيصال بالفعل',
        'الفاتورة غير مرتبطة بحسابك',
        'الملف غير صالح',
        'الملف أكبر من 5 ميجابايت',
      ]) {
        ds.proofError = ServerException(message);
        expect(
          await submitProof(),
          Left<Failure, Unit>(ValidationFailure(message)),
          reason: message,
        );
      }
    });

    test('other proof errors stay ServerFailure', () async {
      ds.proofError = const ServerException('انقطع الاتصال');
      expect(
        await submitProof(),
        const Left<Failure, Unit>(ServerFailure('انقطع الاتصال')),
      );
    });

    test('absence request is forwarded field-for-field', () async {
      final request = AbsenceRequestEntity(
        id: '',
        studentId: 'c1',
        halaqaId: 'h1',
        requestedBy: 'p1',
        date: DateTime(2026, 9, 12),
        reason: 'سفر',
        status: AbsenceRequestStatus.pending,
      );

      expect(
        await repo.submitAbsenceRequest(request),
        const Right<Failure, Unit>(unit),
      );
      final sent = ds.submittedAbsence.single;
      expect(sent.studentId, 'c1');
      expect(sent.halaqaId, 'h1');
      expect(sent.requestedBy, 'p1');
      expect(sent.reason, 'سفر');
      expect(sent.status, AbsenceRequestStatus.pending);
      expect(sent.reviewedBy, isNull);
    });
  });

  group('TeacherRepositoryImpl.saveDayAttendance', () {
    late _TeacherDs ds;
    late _Sink sink;
    late FakeNetworkInfo network;
    late TeacherRepositoryImpl repo;

    setUp(() {
      ds = _TeacherDs();
      sink = _Sink();
      network = FakeNetworkInfo();
      repo = TeacherRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: network,
        eventSink: sink,
      );
    });

    test('server-side fan-out (no device events) reports none', () async {
      final result = await repo.saveDayAttendance([_mark()]);

      expect(
        result,
        const Right<Failure, AcademyEventPublication>(
          AcademyEventPublication.none(),
        ),
      );
      expect(ds.saved.single.single.status, AttendanceStatus.absent);
      expect(ds.saved.single.single.sessionId, 'sess1');
    });

    test('a failing sink never rolls back the committed save', () async {
      ds.events = [_absentEvent];
      sink.error = StateError('fcm down');

      final result = await repo.saveDayAttendance([_mark()]);

      result.match(
        (_) => fail('save already committed'),
        (publication) {
          expect(publication.eventCount, 1);
          expect(publication.eventsPublished, isFalse);
          expect(publication.hasUnpublishedEvents, isTrue);
        },
      );
    });

    test('server rejection and offline are failures', () async {
      ds.error = const ServerException('خارج نافذة التعديل');
      expect(
        await repo.saveDayAttendance([_mark()]),
        const Left<Failure, AcademyEventPublication>(
          ServerFailure('خارج نافذة التعديل'),
        ),
      );

      network.connected = false;
      ds.saved.clear();
      expect(
        await repo.saveDayAttendance([_mark()]),
        const Left<Failure, AcademyEventPublication>(NetworkFailure()),
      );
      expect(ds.saved, isEmpty);
    });
  });

  group('NotificationsRepositoryImpl', () {
    test('stream error is delivered as a Left', () async {
      final ds = _NotificationsDs();
      final repo = NotificationsRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: FakeNetworkInfo(),
      );

      final events = <Either<Failure, List<Object>>>[];
      final done = repo
          .watchNotifications(uid: 'u1', role: 'parent')
          .listen(events.add)
          .asFuture<void>();
      ds.controller
        ..add(const [])
        ..addError(Exception('permission-denied'));
      await ds.controller.close();
      await done;

      expect(events.first.isRight(), isTrue);
      expect(events.last.isLeft(), isTrue);
    });

    test('mark as read offline does not call the datasource', () async {
      final ds = _NotificationsDs();
      final repo = NotificationsRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: FakeNetworkInfo(connected: false),
      );

      expect(
        await repo.markAsRead(notificationId: 'n1', uid: 'u1'),
        const Left<Failure, Unit>(NetworkFailure()),
      );
      expect(ds.markCalls, 0);
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/calendar/data/datasources/calendar_remote_datasource.dart';
import 'package:rafiq_academy/features/calendar/data/repositories/calendar_repository_impl.dart';
import 'package:rafiq_academy/features/calendar/domain/entities/calendar_event_entity.dart';
import 'package:rafiq_academy/features/content/data/datasources/content_library_remote_datasource.dart';
import 'package:rafiq_academy/features/content/data/repositories/content_repository_impl.dart';
import 'package:rafiq_academy/features/content/domain/entities/content_file_entity.dart';
import 'package:rafiq_academy/features/halaqa_activity/data/datasources/halaqa_activity_remote_datasource.dart';
import 'package:rafiq_academy/features/halaqa_activity/data/repositories/halaqa_activity_repository_impl.dart';
import 'package:rafiq_academy/features/halaqa_activity/domain/entities/halaqa_activity_entity.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart';
import 'package:rafiq_academy/features/parent/data/repositories/parent_repository_impl.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/features/post/domain/repositories/posts_repository.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';
import 'package:rafiq_academy/features/teacher/data/repositories/teacher_repository_impl.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';
import 'package:rafiq_academy/shared/domain/contact_info_policy.dart';

import '../support/fake_callables.dart';

class _CalendarDs extends Fake implements CalendarRemoteDatasource {}

class _ContentDs extends Fake implements ContentLibraryRemoteDatasource {}

class _ActivityDs extends Fake implements HalaqaActivityRemoteDatasource {}

class _ParentDs extends Fake implements ParentRemoteDatasource {}

class _TeacherDs extends Fake implements TeacherRemoteDatasource {}

class _PostsRepo extends Fake implements PostsRepository {}

class _Sink extends Fake implements AcademyEventSink {}

/// Every guarded write rejects contact info before touching the datasource
/// (the fakes throw if called). Academic text passes the guard and reaches
/// the offline check, which proves it was not blocked.
void main() {
  const phone = 'تواصل معي 0501234567';
  const waLink = 'https://wa.me/966501234567';
  const academic = 'سورة البقرة الآيات 1-20، الدرجة 95/100، تمرين 3';
  final rejected = Left<Failure, Never>(
    ValidationFailure(contactInfoViolation(phone)!),
  );
  final offline = FakeNetworkInfo(connected: false);

  CalendarEventEntity event(String title, {String? description}) =>
      CalendarEventEntity(
        id: '',
        title: title,
        type: CalendarEventType.exam,
        date: DateTime(2026, 10, 20),
        description: description,
        createdBy: 't1',
      );

  test('calendar event title and description', () async {
    final repo = CalendarRepositoryImpl(
      remoteDatasource: _CalendarDs(),
      networkInfo: offline,
    );
    expect(await repo.addEvent(event(phone)), rejected);
    expect(await repo.addEvent(event('اختبار', description: waLink)), rejected);
    expect(
      await repo.addEvent(event('اختبار جزء 30', description: academic)),
      const Left<Failure, Never>(NetworkFailure()),
    );
  });

  test('parent absence request reason', () async {
    final repo = ParentRepositoryImpl(
      remoteDatasource: _ParentDs(),
      networkInfo: offline,
    );
    AbsenceRequestEntity request(String reason) => AbsenceRequestEntity(
      id: '',
      studentId: 'c1',
      halaqaId: 'h1',
      requestedBy: 'p1',
      date: DateTime(2026, 10, 20),
      reason: reason,
      status: AbsenceRequestStatus.pending,
    );
    expect(await repo.submitAbsenceRequest(request(phone)), rejected);
    final allowed = await repo.submitAbsenceRequest(
      request('موعد طبيب يوم 2026-10-20 الساعة 10:30'),
    );
    expect(allowed.isLeft(), isTrue);
    expect(allowed.getLeft().toNullable(), isNot(isA<ValidationFailure>()));
  });

  test('teacher assignment ranges', () async {
    final repo = TeacherRepositoryImpl(
      remoteDatasource: _TeacherDs(),
      networkInfo: offline,
      eventSink: _Sink(),
    );
    Future<Either<Failure, Object>> send(String memorization) =>
        repo.sendAssignment(
          halaqaId: 'h1',
          newMemorizationRange: memorization,
          reviewRange: 'آل عمران 1-50',
          dueDate: DateTime(2026, 10, 20),
          teacherId: 't1',
        );
    expect(await send(phone), rejected);
    expect(
      await send('البقرة 1-20'),
      const Left<Failure, Never>(NetworkFailure()),
    );
  });

  test('halaqa activity prompt and student reply', () async {
    final repo = HalaqaActivityRepositoryImpl(
      remoteDatasource: _ActivityDs(),
      networkInfo: offline,
      eventSink: _Sink(),
      postsRepository: _PostsRepo(),
    );
    Future<Either<Failure, Object>> publish(String prompt) =>
        repo.publishActivity(
          halaqaId: 'h1',
          teacherId: 't1',
          teacherName: 'المعلم',
          prompt: prompt,
          allowedResponseTypes: {HalaqaActivityResponseType.text},
        );
    Future<Either<Failure, Object>> reply(String text) => repo.submitResponse(
      activityId: 'a1',
      halaqaId: 'h1',
      studentId: 's1',
      studentName: 'أحمد',
      text: text,
    );

    expect(await publish('tel:0501234567'), rejected);
    expect(await reply(waLink), rejected);
    expect(
      await publish(academic),
      const Left<Failure, Never>(NetworkFailure()),
    );
    expect(
      await reply('أجبت عن 10 أسئلة من 12'),
      const Left<Failure, Never>(NetworkFailure()),
    );
  });

  test('content library upload title', () async {
    final repo = ContentLibraryRepositoryImpl(
      remoteDatasource: _ContentDs(),
      networkInfo: offline,
    );
    Future<List<Either<Failure, double>>> upload(String title) => repo
        .uploadFile(
          file: File('unused.pdf'),
          title: title,
          type: ContentFileType.pdf,
          uploadedBy: 't1',
          uploaderName: 'المعلم',
        )
        .toList();

    expect(await upload(phone), [rejected]);
    expect(await upload('ملزمة التجويد الدرس 4'), [
      const Left<Failure, double>(NetworkFailure()),
    ]);
  });
}

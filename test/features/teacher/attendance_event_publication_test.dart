import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/student/data/models/halaqa_model.dart';
import 'package:rafiq_academy/features/student/data/models/recitation_record_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/data/data_sources/teacher_remote_datasource.dart';
import 'package:rafiq_academy/features/teacher/data/models/attendance_record_model.dart';
import 'package:rafiq_academy/features/teacher/data/models/halaqa_student_summary_model.dart';
import 'package:rafiq_academy/features/teacher/data/repositories/teacher_repository_impl.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/academy_event.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';

void main() {
  final date = DateTime(2024, 6, 3);

  final record = AttendanceRecordEntity(
    id: '',
    studentId: 's1',
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: date,
    status: AttendanceStatus.absent,
    recordedBy: 't1',
  );

  final event = StudentAbsentRecorded(
    studentId: 's1',
    studentName: 'أحمد',
    halaqaId: 'h1',
    date: date,
    attendanceDocumentId: 'h1_s1_20240603',
  );

  late _FakeTeacherDatasource datasource;
  late _RecordingSink sink;
  late TeacherRepositoryImpl repository;

  setUp(() {
    datasource = _FakeTeacherDatasource();
    sink = _RecordingSink();
    repository = TeacherRepositoryImpl(
      remoteDatasource: datasource,
      networkInfo: _AlwaysOnline(),
      eventSink: sink,
    );
  });

  group('TeacherRepositoryImpl.saveDayAttendance event publication', () {
    test('committed transitions are published exactly once', () async {
      datasource.attendanceEvents = [event];

      final result = await repository.saveDayAttendance([record]);

      expect(sink.published, [
        [event],
      ]);
      result.fold((_) => fail('expected success'), (outcome) {
        expect(outcome.eventCount, 1);
        expect(outcome.eventsPublished, isTrue);
      });
    });

    test(
      'publication failure degrades the outcome, not the register',
      () async {
        datasource.attendanceEvents = [event];
        sink.fail = true;

        final result = await repository.saveDayAttendance([record]);

        result.fold((_) => fail('expected success'), (outcome) {
          expect(outcome.hasUnpublishedEvents, isTrue);
        });
      },
    );
  });

  group('TeacherRepositoryImpl.sendAssignment event publication', () {
    test('publishes HomeworkAssigned facts after commit', () async {
      final assigned = HomeworkAssigned(
        assignmentId: 'a1',
        studentId: 's1',
        halaqaId: 'h1',
        assignedBy: 't1',
        dueDate: date,
        newMemorizationRange: '1-5',
        reviewRange: '',
      );
      datasource.assignmentEvents = [assigned];

      final result = await repository.sendAssignment(
        halaqaId: 'h1',
        newMemorizationRange: '1-5',
        reviewRange: '',
        dueDate: date,
        teacherId: 't1',
      );

      expect(sink.published, [
        [assigned],
      ]);
      result.fold((_) => fail('expected success'), (outcome) {
        expect(outcome.eventsPublished, isTrue);
      });
    });
  });

  group('TeacherRepositoryImpl.updateRecitationReview event publication', () {
    test('publishes HomeworkReviewed through the same path', () async {
      final reviewed = HomeworkReviewed(
        recitationRecordId: 'r1',
        studentId: 's1',
        halaqaId: 'h1',
        date: date,
        grade: 'ممتاز',
        behaviorGrade: 'جيد',
        versesRange: '1-5',
      );
      datasource.reviewEvents = [reviewed];

      final result = await repository.updateRecitationReview(
        UpdateRecitationReviewParams(
          recordId: 'r1',
          halaqaId: 'h1',
          grade: RecitationGrade.excellent,
          behaviorGrade: RecitationGrade.good,
        ),
      );

      expect(sink.published, [
        [reviewed],
      ]);
      result.fold((_) => fail('expected success'), (outcome) {
        expect(outcome.eventCount, 1);
        expect(outcome.eventsPublished, isTrue);
        expect(outcome.succeededHandlerNames, ['fake']);
        expect(outcome.failedHandlerNames, isEmpty);
      });
    });

    test('failed review write publishes nothing', () async {
      datasource.reviewFailure = const ServerException('write failed');

      final result = await repository.updateRecitationReview(
        UpdateRecitationReviewParams(
          recordId: 'r1',
          halaqaId: 'h1',
          grade: RecitationGrade.excellent,
          behaviorGrade: RecitationGrade.good,
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(sink.published, isEmpty);
    });

    test(
      'publication failure keeps review success with unpublished flag',
      () async {
        datasource.reviewEvents = [
          HomeworkReviewed(
            recitationRecordId: 'r1',
            studentId: 's1',
            halaqaId: 'h1',
            date: date,
            grade: 'ممتاز',
          ),
        ];
        sink.fail = true;

        final result = await repository.updateRecitationReview(
          UpdateRecitationReviewParams(
            recordId: 'r1',
            halaqaId: 'h1',
            grade: RecitationGrade.excellent,
            behaviorGrade: RecitationGrade.good,
          ),
        );

        result.fold((_) => fail('expected success'), (outcome) {
          expect(outcome.hasUnpublishedEvents, isTrue);
        });
      },
    );
  });
}

class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _RecordingSink implements AcademyEventSink {
  final List<List<AcademyEvent>> published = [];
  bool fail = false;

  @override
  Future<AcademyEventPublishReport> publish(
    Iterable<AcademyEvent> events,
  ) async {
    if (fail) throw const ServerException('sink down');
    published.add(events.toList());
    return const AcademyEventPublishReport([
      AcademyEventHandlerReport(handlerName: 'fake', succeeded: true),
    ]);
  }
}

class _FakeTeacherDatasource implements TeacherRemoteDatasource {
  List<AcademyEvent> attendanceEvents = const [];
  List<AcademyEvent> assignmentEvents = const [];
  List<AcademyEvent> reviewEvents = const [];
  ServerException? reviewFailure;

  @override
  Future<List<AcademyEvent>> saveDayAttendance(
    List<AttendanceRecordModel> records,
  ) async => attendanceEvents;

  @override
  Future<List<AcademyEvent>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) async => assignmentEvents;

  @override
  Future<List<AcademyEvent>> updateRecitationReview({
    required String recordId,
    required RecitationGrade grade,
    required RecitationGrade behaviorGrade,
    String? notes,
  }) async {
    if (reviewFailure != null) throw reviewFailure!;
    return reviewEvents;
  }

  @override
  Future<List<HalaqaModel>> getTeacherHalaqat(String teacherId) =>
      throw UnimplementedError();
  @override
  Future<List<HalaqaStudentSummaryModel>> getHalaqaStudents(String halaqaId) =>
      throw UnimplementedError();
  @override
  Future<void> recordAttendance(AttendanceRecordModel record) =>
      throw UnimplementedError();
  @override
  Future<List<AttendanceRecordModel>> getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) => throw UnimplementedError();
  @override
  Future<void> addRecitationRecord(RecitationRecordModel record) =>
      throw UnimplementedError();
  @override
  Future<List<RecitationRecordModel>> getHalaqaRecitationRecords(
    String halaqaId,
  ) => throw UnimplementedError();
  @override
  Future<DateTime?> getLatestAssignmentDueDate(String halaqaId) =>
      throw UnimplementedError();
}

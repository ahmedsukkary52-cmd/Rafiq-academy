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
      datasource.events = [event];

      final result = await repository.saveDayAttendance([record]);

      expect(sink.published, [
        [event],
      ]);
      result.fold((_) => fail('expected success'), (outcome) {
        expect(outcome.eventCount, 1);
        expect(outcome.eventsPublished, isTrue);
        expect(outcome.hasUnpublishedEvents, isFalse);
      });
    });

    test('a save with no transitions publishes nothing', () async {
      datasource.events = const [];

      final result = await repository.saveDayAttendance([record]);

      expect(sink.published, isEmpty);
      result.fold(
        (_) => fail('expected success'),
        (outcome) => expect(outcome.eventCount, 0),
      );
    });

    test('failed attendance write publishes nothing', () async {
      datasource.failure = const ServerException('write failed');

      final result = await repository.saveDayAttendance([record]);

      expect(sink.published, isEmpty);
      expect(result.isLeft(), isTrue);
    });

    test('offline never reaches the datasource or the sink', () async {
      final offlineRepository = TeacherRepositoryImpl(
        remoteDatasource: datasource,
        networkInfo: _AlwaysOffline(),
        eventSink: sink,
      );

      final result = await offlineRepository.saveDayAttendance([record]);

      expect(datasource.saveCallCount, 0);
      expect(sink.published, isEmpty);
      expect(result.isLeft(), isTrue);
    });

    test(
      'publication failure degrades the outcome, not the register',
      () async {
        datasource.events = [event];
        sink.shouldFail = true;

        final result = await repository.saveDayAttendance([record]);

        result.fold((_) => fail('attendance must stay saved'), (outcome) {
          expect(outcome.eventCount, 1);
          expect(outcome.eventsPublished, isFalse);
          expect(outcome.hasUnpublishedEvents, isTrue);
        });
      },
    );

    test('single-record path reuses the same publication rule', () async {
      datasource.events = [event];

      final result = await repository.recordAttendance(record);

      expect(result.isRight(), isTrue);
      expect(sink.published, hasLength(1));
    });
  });
}

class _RecordingSink implements AcademyEventSink {
  final List<List<AcademyEvent>> published = [];
  bool shouldFail = false;

  @override
  Future<void> publish(Iterable<AcademyEvent> events) async {
    if (shouldFail) throw const ServerException('sink down');
    published.add(events.toList());
  }
}

class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _AlwaysOffline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

class _FakeTeacherDatasource implements TeacherRemoteDatasource {
  List<AcademyEvent> events = const [];
  ServerException? failure;
  int saveCallCount = 0;

  @override
  Future<List<AcademyEvent>> saveDayAttendance(
    List<AttendanceRecordModel> records,
  ) async {
    saveCallCount++;
    if (failure != null) throw failure!;
    return events;
  }

  @override
  Future<void> recordAttendance(AttendanceRecordModel record) =>
      throw UnimplementedError();
  @override
  Future<List<HalaqaModel>> getTeacherHalaqat(String teacherId) =>
      throw UnimplementedError();
  @override
  Future<List<HalaqaStudentSummaryModel>> getHalaqaStudents(String halaqaId) =>
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
  Future<void> updateRecitationReview({
    required String recordId,
    required RecitationGrade grade,
    required RecitationGrade behaviorGrade,
    String? notes,
  }) => throw UnimplementedError();
  @override
  Future<List<RecitationRecordModel>> getHalaqaRecitationRecords(
    String halaqaId,
  ) => throw UnimplementedError();
  @override
  Future<void> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) => throw UnimplementedError();
  @override
  Future<DateTime?> getLatestAssignmentDueDate(String halaqaId) =>
      throw UnimplementedError();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/achievement_issue_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/entities/supervisor_report_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/repositories/parent_repository.dart';
import 'package:rafiq_academy/features/supervisor/domain/usecases/get_supervisor_day_board_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';
import 'package:rafiq_academy/shared/domain/halaqa_day_readiness.dart';

final _monday = DateTime(2024, 6, 3, 9, 0);
final _mondayDue = DateTime(2024, 6, 3, 23, 59, 59);

HalaqaEntity _halaqa({
  required String id,
  String teacherId = 't1',
  List<String> studentIds = const ['s1'],
  String day = 'monday',
  String start = '09:00',
}) {
  return HalaqaEntity(
    id: id,
    name: 'حلقة $id',
    teacherId: teacherId,
    supervisorId: 'sup1',
    studentIds: studentIds,
    schedule: [
      HalaqaScheduleEntity(day: day, startTime: start, endTime: '10:00'),
    ],
    meetingLink: '',
    status: 'active',
  );
}

AttendanceRecordEntity _attendance(String halaqaId, String studentId) {
  return AttendanceRecordEntity(
    id: '${halaqaId}_$studentId',
    studentId: studentId,
    studentName: studentId,
    halaqaId: halaqaId,
    date: _monday,
    status: AttendanceStatus.present,
    recordedBy: 't1',
  );
}

RecitationRecordEntity _recitation(String halaqaId, {required bool pending}) {
  return RecitationRecordEntity(
    id: '${halaqaId}_rec',
    studentId: 's1',
    studentName: 's1',
    teacherId: 't1',
    halaqaId: halaqaId,
    date: _monday,
    type: RecitationType.memorization,
    versesRange: '1-5',
    reviewStatus: pending ? 'pending' : 'reviewed',
  );
}

class _FakeTeacherRepository implements TeacherRepository {
  final Map<String, List<AttendanceRecordEntity>> attendance;
  final Map<String, List<RecitationRecordEntity>> recitations;
  final Map<String, DateTime?> latestDueByHalaqa;

  _FakeTeacherRepository({
    this.attendance = const {},
    this.recitations = const {},
    this.latestDueByHalaqa = const {},
  });

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async => Right(attendance[halaqaId] ?? const []);

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId) async =>
      Right(recitations[halaqaId] ?? const []);

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) async => Right(latestDueByHalaqa[halaqaId]);

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getTeacherHalaqat(String t) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> getHalaqaStudents(
    String h,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> recordAttendance(AttendanceRecordEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> saveDayAttendance(
    List<AttendanceRecordEntity> r,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> addRecitationRecord(RecitationRecordEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> upsertTeacherEvaluation({
    required RecitationRecordEntity record,
    required List<String> retireDocumentIds,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> updateRecitationReview(
    UpdateRecitationReviewParams p,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, AcademyEventPublication>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getPendingAbsenceRequests({
    required String halaqaId,
    required DateTime date,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> reviewAbsenceRequest({
    required String requestId,
    required String expectedHalaqaId,
    required String teacherId,
    required AbsenceRequestStatus decision,
  }) => throw UnimplementedError();
}

class _FakeSupervisorRepository implements SupervisorRepository {
  final Map<String, String> names;

  _FakeSupervisorRepository({this.names = const {}});

  @override
  Future<Either<Failure, Map<String, String>>> getUserDisplayNames(
    List<String> userIds,
  ) async => Right({
    for (final id in userIds)
      if (names.containsKey(id)) id: names[id]!,
  });

  @override
  Future<Either<Failure, List<HalaqaEntity>>> getSupervisedHalaqat(String s) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> issueAchievement(AchievementIssueEntity d) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> submitReport(SupervisorReportEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> registerNewStudent({
    required String halaqaId,
    required String studentId,
  }) => throw UnimplementedError();
  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForHalaqatOnDate({
    required List<String> halaqaIds,
    required DateTime date,
  }) => throw UnimplementedError();
}

void main() {
  group('GetSupervisorDayBoardUseCase', () {
    test('excludes halaqat with no session today (D-W6-6)', () async {
      final useCase = GetSupervisorDayBoardUseCase(
        teacherRepository: _FakeTeacherRepository(),
        supervisorRepository: _FakeSupervisorRepository(),
      );

      final board = (await useCase(
        SupervisorDayBoardParams(
          halaqat: [_halaqa(id: 'h1', day: 'tuesday')],
          now: _monday,
        ),
      )).getOrElse((f) => fail(f.message));

      expect(board.sessionsTodayCount, 0);
      expect(board.items, isEmpty);
    });

    test(
      'includes complete and incomplete; uses shared projector facts',
      () async {
        final useCase = GetSupervisorDayBoardUseCase(
          teacherRepository: _FakeTeacherRepository(
            attendance: {
              'ok': [_attendance('ok', 's1')],
              // gap: incomplete attendance
            },
            latestDueByHalaqa: {'ok': _mondayDue, 'gap': _mondayDue},
            recitations: {
              'ok': [_recitation('ok', pending: false)],
              'gap': [_recitation('gap', pending: false)],
            },
          ),
          supervisorRepository: _FakeSupervisorRepository(
            names: {'t1': 'أ. أحمد'},
          ),
        );

        final board = (await useCase(
          SupervisorDayBoardParams(
            halaqat: [
              _halaqa(id: 'gap', start: '10:00'),
              _halaqa(id: 'ok', start: '09:00'),
            ],
            now: _monday,
          ),
        )).getOrElse((f) => fail(f.message));

        expect(board.sessionsTodayCount, 2);
        expect(board.items.map((i) => i.halaqaId).toList(), ['ok', 'gap']);
        expect(board.items[0].isComplete, isTrue);
        expect(board.items[1].needsAttention, isTrue);
        expect(
          board.items[1].readiness.gaps.single.kind,
          HalaqaDayGapKind.attendanceIncomplete,
        );
        expect(
          board.items.every((i) => i.teacherDisplayName == 'أ. أحمد'),
          isTrue,
        );
      },
    );

    test('does not exception-sort — presentation owns Rule 3', () async {
      final useCase = GetSupervisorDayBoardUseCase(
        teacherRepository: _FakeTeacherRepository(
          attendance: {
            'ok': [_attendance('ok', 's1')],
          },
          latestDueByHalaqa: {'ok': _mondayDue, 'gap': _mondayDue},
          recitations: {
            'ok': [_recitation('ok', pending: false)],
            'gap': [_recitation('gap', pending: false)],
          },
        ),
        supervisorRepository: _FakeSupervisorRepository(),
      );

      final board = (await useCase(
        SupervisorDayBoardParams(
          halaqat: [
            _halaqa(id: 'gap', start: '08:00'),
            _halaqa(id: 'ok', start: '11:00'),
          ],
          now: _monday,
        ),
      )).getOrElse((f) => fail(f.message));

      // D7 order by start time — incomplete comes first only because it starts earlier.
      expect(board.items.map((i) => i.halaqaId).toList(), ['gap', 'ok']);
    });
  });
}

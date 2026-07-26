import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_save_result.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/read_models/teacher_day_agenda.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_today_agenda_usecase.dart';

/// Fixed Monday so `monday` schedule slots land on "today".
final _monday = DateTime(2024, 6, 3, 9, 0);
final _mondayDue = DateTime(2024, 6, 3, 23, 59, 59);
final _tuesdayDue = DateTime(2024, 6, 4, 23, 59, 59);

HalaqaEntity _halaqa({
  required String id,
  List<String> studentIds = const ['s1'],
  String day = 'monday',
  String start = '09:00',
  String end = '10:00',
}) {
  return HalaqaEntity(
    id: id,
    name: 'حلقة $id',
    teacherId: 't1',
    supervisorId: 'sup1',
    studentIds: studentIds,
    schedule: [HalaqaScheduleEntity(day: day, startTime: start, endTime: end)],
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
  final Failure? failAttendance;
  final Failure? failReviews;
  final Failure? failHomework;

  _FakeTeacherRepository({
    this.attendance = const {},
    this.recitations = const {},
    this.latestDueByHalaqa = const {},
    this.failAttendance,
    this.failReviews,
    this.failHomework,
  });

  @override
  Future<Either<Failure, List<AttendanceRecordEntity>>>
  getHalaqaAttendanceForDate({
    required String halaqaId,
    required DateTime date,
  }) async {
    if (failAttendance != null) return Left(failAttendance!);
    return Right(attendance[halaqaId] ?? const []);
  }

  @override
  Future<Either<Failure, List<RecitationRecordEntity>>>
  getHalaqaRecitationRecords(String halaqaId) async {
    if (failReviews != null) return Left(failReviews!);
    return Right(recitations[halaqaId] ?? const []);
  }

  @override
  Future<Either<Failure, DateTime?>> getLatestAssignmentDueDate(
    String halaqaId,
  ) async {
    if (failHomework != null) return Left(failHomework!);
    return Right(latestDueByHalaqa[halaqaId]);
  }

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
  Future<Either<Failure, AttendanceSaveResult>> saveDayAttendance(
    List<AttendanceRecordEntity> r,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> addRecitationRecord(RecitationRecordEntity r) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> updateRecitationReview(
    UpdateRecitationReviewParams p,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> sendAssignment({
    required String halaqaId,
    required String newMemorizationRange,
    required String reviewRange,
    required DateTime dueDate,
    required String teacherId,
  }) => throw UnimplementedError();
}

TeacherDayAgenda _unwrap(Either<Failure, TeacherDayAgenda> either) {
  return either.getOrElse(
    (f) => fail('expected Right, got Left: ${f.message}'),
  );
}

/// Fully handled halaqa: register complete + homework due today + no pending.
_FakeTeacherRepository _fullyHandledRepo(String halaqaId) {
  return _FakeTeacherRepository(
    attendance: {
      halaqaId: [_attendance(halaqaId, 's1')],
    },
    latestDueByHalaqa: {halaqaId: _mondayDue},
    recitations: {
      halaqaId: [_recitation(halaqaId, pending: false)],
    },
  );
}

void main() {
  group('GetTodayAgendaUseCase', () {
    test('empty halaqat → empty agenda', () async {
      final useCase = GetTodayAgendaUseCase(_FakeTeacherRepository());

      final agenda = _unwrap(
        await useCase(TodayAgendaParams(halaqat: const [], now: _monday)),
      );

      expect(agenda.items, isEmpty);
      expect(agenda.sessionsTodayCount, 0);
    });

    test('halaqa not scheduled today is excluded', () async {
      final useCase = GetTodayAgendaUseCase(_FakeTeacherRepository());

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1', day: 'tuesday')],
            now: _monday,
          ),
        ),
      );

      expect(agenda.sessionsTodayCount, 0);
      expect(agenda.items, isEmpty);
    });

    test('attendance incomplete surfaces takeAttendance action', () async {
      final useCase = GetTodayAgendaUseCase(
        _FakeTeacherRepository(latestDueByHalaqa: {'h1': _mondayDue}),
      );

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [
              _halaqa(id: 'h1', studentIds: const ['s1', 's2']),
            ],
            now: _monday,
          ),
        ),
      );

      expect(agenda.sessionsTodayCount, 1);
      expect(agenda.items.single.pendingActions, [
        TeacherAgendaAction.takeAttendance,
      ]);
    });

    test('missing / stale homework surfaces sendHomework action', () async {
      final useCase = GetTodayAgendaUseCase(
        _FakeTeacherRepository(
          attendance: {
            'h1': [_attendance('h1', 's1')],
          },
          // Latest dueDate is tomorrow → not "today's" under W1 D7 + day SSOT.
          latestDueByHalaqa: {'h1': _tuesdayDue},
        ),
      );

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1')],
            now: _monday,
          ),
        ),
      );

      expect(agenda.items.single.pendingActions, [
        TeacherAgendaAction.sendHomework,
      ]);
    });

    test('no assignments at all surfaces sendHomework', () async {
      final useCase = GetTodayAgendaUseCase(
        _FakeTeacherRepository(
          attendance: {
            'h1': [_attendance('h1', 's1')],
          },
        ),
      );

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1')],
            now: _monday,
          ),
        ),
      );

      expect(agenda.items.single.pendingActions, [
        TeacherAgendaAction.sendHomework,
      ]);
    });

    test('pending reviews surface reviewRecitations action', () async {
      final repo = _FakeTeacherRepository(
        attendance: {
          'h1': [_attendance('h1', 's1')],
        },
        latestDueByHalaqa: {'h1': _mondayDue},
        recitations: {
          'h1': [_recitation('h1', pending: true)],
        },
      );
      final useCase = GetTodayAgendaUseCase(repo);

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1')],
            now: _monday,
          ),
        ),
      );

      expect(agenda.items.single.pendingActions, [
        TeacherAgendaAction.reviewRecitations,
      ]);
    });

    test('all three signals appear in stable order', () async {
      final repo = _FakeTeacherRepository(
        recitations: {
          'h1': [_recitation('h1', pending: true)],
        },
      );
      final useCase = GetTodayAgendaUseCase(repo);

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1')],
            now: _monday,
          ),
        ),
      );

      expect(agenda.items.single.pendingActions, [
        TeacherAgendaAction.takeAttendance,
        TeacherAgendaAction.sendHomework,
        TeacherAgendaAction.reviewRecitations,
      ]);
    });

    test('completed work is removed but still counted as a session', () async {
      final useCase = GetTodayAgendaUseCase(_fullyHandledRepo('h1'));

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1')],
            now: _monday,
          ),
        ),
      );

      expect(agenda.sessionsTodayCount, 1);
      expect(agenda.items, isEmpty, reason: 'nothing left to do → removed');
    });

    test('empty roster is never an attendance or homework action', () async {
      // Aligns with sendAssignment empty-roster guard and register-complete.
      final useCase = GetTodayAgendaUseCase(_FakeTeacherRepository());

      final agenda = _unwrap(
        await useCase(
          TodayAgendaParams(
            halaqat: [_halaqa(id: 'h1', studentIds: const [])],
            now: _monday,
          ),
        ),
      );

      expect(agenda.sessionsTodayCount, 1);
      expect(agenda.items, isEmpty);
    });

    test(
      'multiple halaqat ordered by start time then id (D7 via mapper)',
      () async {
        final useCase = GetTodayAgendaUseCase(_FakeTeacherRepository());

        final agenda = _unwrap(
          await useCase(
            TodayAgendaParams(
              halaqat: [
                _halaqa(id: 'b', start: '10:00'),
                _halaqa(id: 'a', start: '09:00'),
                _halaqa(id: 'c', start: '09:00'),
              ],
              now: _monday,
            ),
          ),
        );

        expect(agenda.items.map((i) => i.halaqaId).toList(), ['a', 'c', 'b']);
      },
    );

    test('attendance read failure propagates as Left', () async {
      final repo = _FakeTeacherRepository(
        failAttendance: const ServerFailure('boom'),
      );
      final useCase = GetTodayAgendaUseCase(repo);

      final result = await useCase(
        TodayAgendaParams(
          halaqat: [_halaqa(id: 'h1')],
          now: _monday,
        ),
      );

      expect(result.isLeft(), isTrue);
    });

    test('homework read failure propagates as Left', () async {
      final repo = _FakeTeacherRepository(
        attendance: {
          'h1': [_attendance('h1', 's1')],
        },
        failHomework: const ServerFailure('boom'),
      );
      final useCase = GetTodayAgendaUseCase(repo);

      final result = await useCase(
        TodayAgendaParams(
          halaqat: [_halaqa(id: 'h1')],
          now: _monday,
        ),
      );

      expect(result.isLeft(), isTrue);
    });

    test('review read failure propagates as Left', () async {
      final repo = _FakeTeacherRepository(
        attendance: {
          'h1': [_attendance('h1', 's1')],
        },
        latestDueByHalaqa: {'h1': _mondayDue},
        failReviews: const ServerFailure('boom'),
      );
      final useCase = GetTodayAgendaUseCase(repo);

      final result = await useCase(
        TodayAgendaParams(
          halaqat: [_halaqa(id: 'h1')],
          now: _monday,
        ),
      );

      expect(result.isLeft(), isTrue);
    });
  });
}

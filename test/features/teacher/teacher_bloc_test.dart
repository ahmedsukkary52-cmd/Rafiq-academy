import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/read_models/teacher_home_feed.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/add_recitation_record_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_halaqa_attendance_for_date_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_halaqa_recitation_records_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_halaqa_students_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_pending_absence_requests_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_teacher_halaqt_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_teacher_home_feed_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/get_today_agenda_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/review_absence_request_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/save_day_attendance_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/send_assignment_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/update_recitation_review_usecase.dart';
import 'package:rafiq_academy/features/teacher/domain/usecases/upsert_teacher_evaluation_usecase.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_event.dart';
import 'package:rafiq_academy/features/teacher/presentation/bloc/teacher_state.dart';
import 'package:rafiq_academy/shared/domain/absence_request.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';

/// Scripted use-case response; [gates] hold specific calls open so tests can
/// interleave requests.
class _Script<P, R> {
  _Script(this.respond);

  R Function(P params) respond;
  final params = <P>[];
  final gates = <int, Completer<void>>{};

  Future<R> run(P p) async {
    final index = params.length;
    params.add(p);
    await gates[index]?.future;
    return respond(p);
  }
}

typedef _E<T> = Either<Failure, T>;

const _halaqa = HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: ['s1'],
  schedule: [],
  status: 'active',
);

const _student = HalaqaStudentSummaryEntity(uid: 's1', name: 'أحمد');

const _published = AcademyEventPublication(eventCount: 1, eventsPublished: true);
const _unpublished = AcademyEventPublication(
  eventCount: 1,
  eventsPublished: false,
);

AttendanceRecordEntity _attendance(DateTime date) => AttendanceRecordEntity(
  id: 'a_s1',
  studentId: 's1',
  studentName: 'أحمد',
  halaqaId: 'h1',
  date: date,
  status: AttendanceStatus.present,
  recordedBy: 't1',
  sessionId: 'sess1',
);

class _Halaqat extends Fake implements GetTeacherHalaqatUseCase {
  final s = _Script<TeacherIdParams, _E<List<HalaqaEntity>>>(
    (_) => const Right([_halaqa]),
  );
  @override
  Future<_E<List<HalaqaEntity>>> call(TeacherIdParams p) => s.run(p);
}

class _Feed extends Fake implements GetTeacherHomeFeedUseCase {
  final s = _Script<TodayAgendaParams, _E<TeacherHomeFeed>>(
    (_) => const Right(TeacherHomeFeed.empty),
  );
  @override
  Future<_E<TeacherHomeFeed>> call(TodayAgendaParams p) => s.run(p);
}

class _Students extends Fake implements GetHalaqaStudentsUseCase {
  final s = _Script<HalaqaStudentsParams, _E<List<HalaqaStudentSummaryEntity>>>(
    (_) => const Right([_student]),
  );
  @override
  Future<_E<List<HalaqaStudentSummaryEntity>>> call(HalaqaStudentsParams p) =>
      s.run(p);
}

class _Evaluations extends Fake implements GetHalaqaRecitationRecordsUseCase {
  final s = _Script<HalaqaStudentsParams, _E<List<RecitationRecordEntity>>>(
    (_) => const Right([]),
  );
  @override
  Future<_E<List<RecitationRecordEntity>>> call(HalaqaStudentsParams p) =>
      s.run(p);
}

class _DayAttendance extends Fake implements GetHalaqaAttendanceForDateUseCase {
  final s =
      _Script<HalaqaAttendanceDateParams, _E<List<AttendanceRecordEntity>>>(
        (p) => Right([_attendance(p.date)]),
      );
  @override
  Future<_E<List<AttendanceRecordEntity>>> call(HalaqaAttendanceDateParams p) =>
      s.run(p);
}

class _SaveAttendance extends Fake implements SaveDayAttendanceUseCase {
  final s = _Script<List<AttendanceRecordEntity>, _E<AcademyEventPublication>>(
    (_) => const Right(_published),
  );
  @override
  Future<_E<AcademyEventPublication>> call(List<AttendanceRecordEntity> p) =>
      s.run(p);
}

class _SendAssignment extends Fake implements SendAssignmentUseCase {
  final s = _Script<SendAssignmentParams, _E<AcademyEventPublication>>(
    (_) => const Right(_published),
  );
  @override
  Future<_E<AcademyEventPublication>> call(SendAssignmentParams p) => s.run(p);
}

class _UpdateReview extends Fake implements UpdateRecitationReviewUseCase {
  final s = _Script<UpdateRecitationReviewParams, _E<AcademyEventPublication>>(
    (_) => const Right(_published),
  );
  @override
  Future<_E<AcademyEventPublication>> call(UpdateRecitationReviewParams p) =>
      s.run(p);
}

class _PendingAbsence extends Fake implements GetPendingAbsenceRequestsUseCase {
  final s =
      _Script<PendingAbsenceRequestsParams, _E<List<AbsenceRequestEntity>>>(
        (_) => const Right([]),
      );
  @override
  Future<_E<List<AbsenceRequestEntity>>> call(PendingAbsenceRequestsParams p) =>
      s.run(p);
}

class _ReviewAbsence extends Fake implements ReviewAbsenceRequestUseCase {
  final s = _Script<ReviewAbsenceRequestParams, _E<Unit>>(
    (_) => const Right(unit),
  );
  @override
  Future<_E<Unit>> call(ReviewAbsenceRequestParams p) => s.run(p);
}

class _Unused1 extends Fake implements AddRecitationRecordUseCase {}

class _Unused2 extends Fake implements UpsertTeacherEvaluationUseCase {}

class _Harness {
  final halaqat = _Halaqat();
  final feed = _Feed();
  final students = _Students();
  final evaluations = _Evaluations();
  final dayAttendance = _DayAttendance();
  final saveAttendance = _SaveAttendance();
  final sendAssignment = _SendAssignment();
  final updateReview = _UpdateReview();
  final pendingAbsence = _PendingAbsence();
  final reviewAbsence = _ReviewAbsence();

  late final bloc = TeacherBloc(
    getTeacherHalaqat: halaqat,
    getHalaqaStudents: students,
    getHalaqaRecitationRecords: evaluations,
    getHalaqaAttendanceForDate: dayAttendance,
    saveDayAttendance: saveAttendance,
    addRecitationRecord: _Unused1(),
    upsertTeacherEvaluation: _Unused2(),
    updateRecitationReview: updateReview,
    sendAssignment: sendAssignment,
    getTeacherHomeFeed: feed,
    getPendingAbsenceRequests: pendingAbsence,
    reviewAbsenceRequest: reviewAbsence,
  );
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Harness h;

  setUp(() => h = _Harness());
  tearDown(() => h.bloc.close());

  test('initial state is idle', () {
    expect(h.bloc.state, TeacherState.initial());
    expect(h.bloc.state.attendanceSubmissionStatus, SubmissionStatus.idle);
  });

  group('halaqat + today agenda', () {
    test('loaded halaqat feed the agenda derivation', () async {
      h.bloc.add(const LoadTeacherHalaqatEvent('t1'));
      await _settle();

      expect(h.halaqat.s.params.single.teacherId, 't1');
      expect(h.bloc.state.halaqatStatus, SectionStatus.loaded);
      expect(h.bloc.state.halaqat, [_halaqa]);
      expect(h.feed.s.params.single.halaqat, [_halaqa]);
      expect(h.bloc.state.todayAgendaStatus, SectionStatus.loaded);
      expect(h.bloc.state.recentActivitiesStatus, SectionStatus.loaded);
    });

    test('teacher with no halaqat is loaded and empty', () async {
      h.halaqat.s.respond = (_) => const Right([]);
      h.bloc.add(const LoadTeacherHalaqatEvent('t1'));
      await _settle();

      expect(h.bloc.state.halaqatStatus, SectionStatus.loaded);
      expect(h.bloc.state.halaqat, isEmpty);
    });

    test('halaqat failure skips the agenda', () async {
      h.halaqat.s.respond = (_) => const Left(NetworkFailure());
      h.bloc.add(const LoadTeacherHalaqatEvent('t1'));
      await _settle();

      expect(h.bloc.state.halaqatStatus, SectionStatus.error);
      expect(h.bloc.state.halaqatError, const NetworkFailure().message);
      expect(h.feed.s.params, isEmpty);
      expect(h.bloc.state.todayAgendaStatus, SectionStatus.initial);
    });

    test('agenda failure can be retried without reloading halaqat', () async {
      h.feed.s.respond = (_) => const Left(ServerFailure('تعذر'));
      h.bloc.add(const LoadTeacherHalaqatEvent('t1'));
      await _settle();
      expect(h.bloc.state.todayAgendaStatus, SectionStatus.error);
      expect(h.bloc.state.recentActivitiesError, 'تعذر');

      h.feed.s.respond = (_) => const Right(TeacherHomeFeed.empty);
      h.bloc.add(const LoadTodayAgendaEvent());
      await _settle();

      expect(h.halaqat.s.params, hasLength(1));
      expect(h.bloc.state.todayAgendaStatus, SectionStatus.loaded);
      expect(h.bloc.state.todayAgendaError, isNull);
    });
  });

  group('halaqa students', () {
    test('select halaqa loads its roster', () async {
      h.bloc.add(const SelectHalaqaEvent('h1'));
      await _settle();

      expect(h.bloc.state.selectedHalaqaId, 'h1');
      expect(h.bloc.state.studentsStatus, SectionStatus.loaded);
      expect(h.bloc.state.students, [_student]);
    });

    test('a stale roster response is dropped', () async {
      h.students.s.gates[0] = Completer<void>();
      h.students.s.respond = (p) => p.halaqaId == 'h1'
          ? const Right([_student])
          : const Right([]);

      h.bloc.add(const LoadHalaqaStudentsEvent('h1'));
      await _settle();
      h.bloc.add(const LoadHalaqaStudentsEvent('h2'));
      await _settle();
      h.students.s.gates[0]!.complete();
      await _settle();

      expect(h.bloc.state.studentsHalaqaId, 'h2');
      expect(h.bloc.state.students, isEmpty);
    });
  });

  group('day attendance', () {
    test('a stale day response is dropped', () async {
      h.dayAttendance.s.gates[0] = Completer<void>();
      h.bloc.add(
        LoadHalaqaAttendanceEvent(halaqaId: 'h1', date: DateTime(2026, 9, 1)),
      );
      await _settle();
      h.bloc.add(
        LoadHalaqaAttendanceEvent(halaqaId: 'h1', date: DateTime(2026, 9, 2, 15)),
      );
      await _settle();
      h.dayAttendance.s.gates[0]!.complete();
      await _settle();

      expect(h.bloc.state.dayAttendanceDate, DateTime(2026, 9, 2));
      expect(h.bloc.state.dayAttendance.single.date, DateTime(2026, 9, 2));
    });

    test('save success refreshes the day, roster and agenda', () async {
      final day = DateTime(2026, 9, 1);
      h.bloc.add(SaveDayAttendanceEvent([_attendance(day)]));
      await _settle();

      expect(h.bloc.state.attendanceSubmissionStatus, SubmissionStatus.success);
      expect(h.bloc.state.attendanceEventsUnpublished, isFalse);
      expect(h.dayAttendance.s.params.single.halaqaId, 'h1');
      expect(h.students.s.params.single.halaqaId, 'h1');
      expect(h.feed.s.params, hasLength(1));
    });

    test('save reports unpublished notification events', () async {
      h.saveAttendance.s.respond = (_) => const Right(_unpublished);
      h.bloc.add(SaveDayAttendanceEvent([_attendance(DateTime(2026, 9, 1))]));
      await _settle();

      expect(h.bloc.state.attendanceEventsUnpublished, isTrue);

      h.bloc.add(const ResetAttendanceSubmissionEvent());
      await _settle();
      expect(h.bloc.state.attendanceSubmissionStatus, SubmissionStatus.idle);
      expect(h.bloc.state.attendanceEventsUnpublished, isFalse);
    });

    test('save failure keeps the error and refreshes nothing', () async {
      h.saveAttendance.s.respond =
          (_) => const Left(ServerFailure('الجلسة مغلقة'));
      h.bloc.add(SaveDayAttendanceEvent([_attendance(DateTime(2026, 9, 1))]));
      await _settle();

      expect(h.bloc.state.attendanceSubmissionStatus, SubmissionStatus.error);
      expect(h.bloc.state.attendanceSubmissionError, 'الجلسة مغلقة');
      expect(h.dayAttendance.s.params, isEmpty);
      expect(h.feed.s.params, isEmpty);
    });

    test('status is submitting while the save is in flight', () async {
      h.saveAttendance.s.gates[0] = Completer<void>();
      h.bloc.add(SaveDayAttendanceEvent([_attendance(DateTime(2026, 9, 1))]));
      await _settle();
      expect(
        h.bloc.state.attendanceSubmissionStatus,
        SubmissionStatus.submitting,
      );

      h.saveAttendance.s.gates[0]!.complete();
      await _settle();
      expect(h.bloc.state.attendanceSubmissionStatus, SubmissionStatus.success);
    });
  });

  group('assignment + review', () {
    test('send assignment success refreshes the agenda', () async {
      h.bloc.add(
        SendAssignmentEvent(
          halaqaId: 'h1',
          newMemorizationRange: 'الملك 1-5',
          reviewRange: '',
          dueDate: DateTime(2026, 9, 3),
          teacherId: 't1',
        ),
      );
      await _settle();

      expect(h.sendAssignment.s.params.single.halaqaId, 'h1');
      expect(h.bloc.state.assignmentSubmissionStatus, SubmissionStatus.success);
      expect(h.feed.s.params, hasLength(1));
    });

    test('send assignment failure is surfaced', () async {
      h.sendAssignment.s.respond = (_) => const Left(ServerFailure('مرفوض'));
      h.bloc.add(
        SendAssignmentEvent(
          halaqaId: 'h1',
          newMemorizationRange: 'x',
          reviewRange: '',
          dueDate: DateTime(2026, 9, 3),
          teacherId: 't1',
        ),
      );
      await _settle();

      expect(h.bloc.state.assignmentSubmissionStatus, SubmissionStatus.error);
      expect(h.bloc.state.assignmentSubmissionError, 'مرفوض');
    });

    test('review update reloads evaluations for that halaqa', () async {
      h.updateReview.s.respond = (_) => const Right(_unpublished);
      h.bloc.add(
        const UpdateRecitationReviewEvent(
          recordId: 'r1',
          halaqaId: 'h1',
          grade: RecitationGrade.good,
          behaviorGrade: RecitationGrade.good,
        ),
      );
      await _settle();

      expect(h.bloc.state.recitationSubmissionStatus, SubmissionStatus.success);
      expect(h.bloc.state.recitationEventsUnpublished, isTrue);
      expect(h.evaluations.s.params.single.halaqaId, 'h1');
    });
  });

  group('absence requests', () {
    test('approve reloads pending requests for the same scope', () async {
      final day = DateTime(2026, 9, 1);
      h.bloc.add(
        LoadPendingAbsenceRequestsEvent(teacherId: 't1', halaqaId: 'h1', date: day),
      );
      await _settle();
      expect(h.bloc.state.pendingAbsenceRequestsStatus, SectionStatus.loaded);

      h.bloc.add(
        const ReviewAbsenceRequestEvent(
          requestId: 'req1',
          halaqaId: 'h1',
          teacherId: 't1',
          decision: AbsenceRequestStatus.approved,
        ),
      );
      await _settle();

      expect(h.reviewAbsence.s.params.single.decision,
          AbsenceRequestStatus.approved);
      expect(h.bloc.state.absenceReviewStatus, SubmissionStatus.success);
      expect(h.pendingAbsence.s.params, hasLength(2));
      expect(h.pendingAbsence.s.params.last.date, day);
    });

    test('review failure does not reload', () async {
      h.reviewAbsence.s.respond = (_) => const Left(ServerFailure('تمت المراجعة'));
      h.bloc.add(
        const ReviewAbsenceRequestEvent(
          requestId: 'req1',
          halaqaId: 'h1',
          teacherId: 't1',
          decision: AbsenceRequestStatus.rejected,
        ),
      );
      await _settle();

      expect(h.bloc.state.absenceReviewStatus, SubmissionStatus.error);
      expect(h.bloc.state.absenceReviewError, 'تمت المراجعة');
      expect(h.pendingAbsence.s.params, isEmpty);
    });
  });

  test('logout clears all teacher state', () async {
    h.bloc.add(const LoadTeacherHalaqatEvent('t1'));
    await _settle();
    h.bloc.add(const ClearTeacherSessionEvent());
    await _settle();

    expect(h.bloc.state, TeacherState.initial());
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/progress_report/domain/entities/progress_report_entity.dart';
import 'package:rafiq_academy/features/progress_report/domain/repositories/progress_report_repository.dart';
import 'package:rafiq_academy/features/progress_report/domain/usecases/get_progress_report_usecase.dart';
import 'package:rafiq_academy/features/progress_report/presentation/bloc/progress_report_bloc.dart';
import 'package:rafiq_academy/features/student/domain/entities/student_profile_entity.dart';
import 'package:rafiq_academy/features/student/domain/repositories/student_repository.dart';
import 'package:rafiq_academy/features/student/domain/usecases/get_student_profile_usecase.dart';

final _calls = <String>[];

class _ReportRepository implements ProgressReportRepository {
  Object? error;

  @override
  Future<ProgressReportEntity> getReport({required String studentId}) async {
    _calls.add('report $studentId');
    final e = error;
    if (e != null) throw e;
    return _report;
  }
}

class _StudentRepository extends Fake implements StudentRepository {
  Either<Failure, StudentProfileEntity> profile = Right(_profile(72.5));

  @override
  Future<Either<Failure, StudentProfileEntity>> getStudentProfile(
    String uid,
  ) async {
    _calls.add('profile $uid');
    return profile;
  }
}

const _report = ProgressReportEntity(
  memorizationAccuracyPercent: 40,
  attendedSessions: 8,
  monthlyAttendancePercent: 80,
  attendanceDays: 8,
  absenceDays: 2,
  weeklyVersesPerDay: [1, 2, 3, 4, 5, 6, 7],
  teacherNotes: 'ممتاز',
);

StudentProfileEntity _profile(double overall) => StudentProfileEntity(
  uid: 's1',
  name: 'أحمد',
  currentPlanName: '',
  overallProgressPercent: overall,
  totalStars: 0,
  badges: const [],
);

late _ReportRepository _reports;
late _StudentRepository _students;
late ProgressReportBloc _bloc;

void main() {
  setUp(() {
    _calls.clear();
    _reports = _ReportRepository();
    _students = _StudentRepository();
    _bloc = ProgressReportBloc(
      getProgressReport: GetProgressReportUseCase(_reports),
      getStudentProfile: GetStudentProfileUseCase(_students),
    );
  });

  tearDown(() async {
    await _bloc.close();
  });

  test('accuracy comes from the profile overall progress', () async {
    _bloc.add(const LoadProgressReportEvent('s1'));
    await expectLater(
      _bloc.stream,
      emitsInOrder([
        const ProgressReportState(
          status: SectionStatus.loading,
          studentId: 's1',
        ),
        ProgressReportState(
          status: SectionStatus.loaded,
          studentId: 's1',
          report: _report.copyWith(memorizationAccuracyPercent: 72.5),
        ),
      ]),
    );
    expect(_calls, ['report s1', 'profile s1']);
  });

  test('a profile failure keeps the report accuracy', () async {
    _students.profile = const Left(ServerFailure('x'));
    _bloc.add(const LoadProgressReportEvent('s1'));
    await expectLater(
      _bloc.stream,
      emitsInOrder([
        const ProgressReportState(
          status: SectionStatus.loading,
          studentId: 's1',
        ),
        const ProgressReportState(
          status: SectionStatus.loaded,
          studentId: 's1',
          report: _report,
        ),
      ]),
    );
  });

  test('a report failure is an error and the profile is still read', () async {
    _reports.error = const ServerException('تعذر التحميل');
    _bloc.add(const LoadProgressReportEvent('s1'));
    await expectLater(
      _bloc.stream,
      emitsInOrder([
        const ProgressReportState(
          status: SectionStatus.loading,
          studentId: 's1',
        ),
        const ProgressReportState(
          status: SectionStatus.error,
          studentId: 's1',
          errorMessage: 'تعذر التحميل',
        ),
      ]),
    );
    expect(_calls, ['report s1', 'profile s1']);
  });

  test('a retry clears the error and reloads for the new id', () async {
    _reports.error = const ServerException('x');
    _bloc.add(const LoadProgressReportEvent('s1'));
    await _bloc.stream.firstWhere((s) => s.status == SectionStatus.error);

    _reports.error = null;
    _bloc.add(const LoadProgressReportEvent('s2'));
    await expectLater(
      _bloc.stream,
      emitsInOrder([
        const ProgressReportState(
          status: SectionStatus.loading,
          studentId: 's2',
        ),
        ProgressReportState(
          status: SectionStatus.loaded,
          studentId: 's2',
          report: _report.copyWith(memorizationAccuracyPercent: 72.5),
        ),
      ]),
    );
    expect(_calls, ['report s1', 'profile s1', 'report s2', 'profile s2']);
  });
}

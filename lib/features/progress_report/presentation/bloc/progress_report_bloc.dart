import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../student/domain/usecases/get_student_profile_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/entities/progress_report_entity.dart';
import '../../domain/usecases/get_progress_report_usecase.dart';

part 'progress_report_event.dart';

part 'progress_report_state.dart';

@injectable
class ProgressReportBloc
    extends Bloc<ProgressReportEvent, ProgressReportState> {
  final GetProgressReportUseCase getProgressReport;
  final GetStudentProfileUseCase getStudentProfile;

  ProgressReportBloc({
    required this.getProgressReport,
    required this.getStudentProfile,
  }) : super(const ProgressReportState()) {
    on<LoadProgressReportEvent>(_onLoad);
  }

  Future<void> _onLoad(
    LoadProgressReportEvent event,
    Emitter<ProgressReportState> emit,
  ) async {
    emit(state.copyWith(status: SectionStatus.loading));

    final reportResult = await getProgressReport(
      ProgressReportParams(event.studentId),
    );
    final profileResult = await getStudentProfile(
      StudentUidParams(event.studentId),
    );

    reportResult.fold(
      (f) => emit(
        state.copyWith(status: SectionStatus.error, errorMessage: f.message),
      ),
      (report) {
        // نفس مصدر Home: overallProgressPercent من studentProfiles
        final accuracy = profileResult.fold(
          (_) => report.memorizationAccuracyPercent,
          (profile) => profile.overallProgressPercent,
        );
        emit(
          state.copyWith(
            status: SectionStatus.loaded,
            report: report.copyWith(memorizationAccuracyPercent: accuracy),
          ),
        );
      },
    );
  }
}

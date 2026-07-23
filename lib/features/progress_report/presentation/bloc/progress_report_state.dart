part of 'progress_report_bloc.dart';

class ProgressReportState extends Equatable {
  final SectionStatus status;
  final String? studentId;
  final ProgressReportEntity? report;
  final String? errorMessage;

  const ProgressReportState({
    this.status = SectionStatus.initial,
    this.studentId,
    this.report,
    this.errorMessage,
  });

  ProgressReportState copyWith({
    SectionStatus? status,
    String? studentId,
    ProgressReportEntity? report,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProgressReportState(
      status: status ?? this.status,
      studentId: studentId ?? this.studentId,
      report: report ?? this.report,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, studentId, report, errorMessage];
}

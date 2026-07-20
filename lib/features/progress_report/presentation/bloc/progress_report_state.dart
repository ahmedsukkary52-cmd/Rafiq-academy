part of 'progress_report_bloc.dart';

class ProgressReportState extends Equatable {
  final SectionStatus status;
  final ProgressReportEntity? report;
  final String? errorMessage;

  const ProgressReportState({
    this.status = SectionStatus.initial,
    this.report,
    this.errorMessage,
  });

  ProgressReportState copyWith({
    SectionStatus? status,
    ProgressReportEntity? report,
    String? errorMessage,
  }) {
    return ProgressReportState(
      status: status ?? this.status,
      report: report ?? this.report,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, report, errorMessage];
}

part of 'progress_report_bloc.dart';

abstract class ProgressReportEvent extends Equatable {
  const ProgressReportEvent();

  @override
  List<Object?> get props => [];
}

class LoadProgressReportEvent extends ProgressReportEvent {
  final String studentId;

  const LoadProgressReportEvent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

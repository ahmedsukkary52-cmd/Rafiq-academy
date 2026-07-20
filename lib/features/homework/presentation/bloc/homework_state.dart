part of 'homework_bloc.dart';

class HomeworkState extends Equatable {
  final SectionStatus status;
  final SubmissionStatus submissionStatus;
  final SubmissionStatus recitationUploadStatus;
  final String? studentId;
  final HomeworkEntity? homework;
  final int? lastEarnedPoints;
  final String? errorMessage;
  final String? recitationError;

  const HomeworkState({
    this.status = SectionStatus.initial,
    this.submissionStatus = SubmissionStatus.idle,
    this.recitationUploadStatus = SubmissionStatus.idle,
    this.studentId,
    this.homework,
    this.lastEarnedPoints,
    this.errorMessage,
    this.recitationError,
  });

  HomeworkState copyWith({
    SectionStatus? status,
    SubmissionStatus? submissionStatus,
    SubmissionStatus? recitationUploadStatus,
    String? studentId,
    HomeworkEntity? homework,
    bool clearHomework = false,
    int? lastEarnedPoints,
    String? errorMessage,
    String? recitationError,
    bool clearRecitationError = false,
  }) {
    return HomeworkState(
      status: status ?? this.status,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      recitationUploadStatus:
          recitationUploadStatus ?? this.recitationUploadStatus,
      studentId: studentId ?? this.studentId,
      homework: clearHomework ? null : (homework ?? this.homework),
      lastEarnedPoints: lastEarnedPoints,
      errorMessage: errorMessage,
      recitationError: clearRecitationError
          ? null
          : (recitationError ?? this.recitationError),
    );
  }

  @override
  List<Object?> get props => [
    status,
    submissionStatus,
    recitationUploadStatus,
    studentId,
    homework,
    lastEarnedPoints,
    errorMessage,
    recitationError,
  ];
}

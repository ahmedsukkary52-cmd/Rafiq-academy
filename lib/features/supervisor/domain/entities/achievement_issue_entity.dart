import 'package:equatable/equatable.dart';

class AchievementIssueEntity extends Equatable {
  /// `issueAchievement` operation id; reused by retries of the same submission.
  final String achievementId;
  final String studentId;
  final String type;
  final String title;
  final String issuedBy;

  /// Halaqa scope for achievements dual-write / teacher stats (H7 / A-H7).
  final String halaqaId;

  const AchievementIssueEntity({
    required this.achievementId,
    required this.studentId,
    required this.type,
    required this.title,
    required this.issuedBy,
    required this.halaqaId,
  });

  @override
  List<Object?> get props => [
    achievementId,
    studentId,
    type,
    title,
    issuedBy,
    halaqaId,
  ];
}

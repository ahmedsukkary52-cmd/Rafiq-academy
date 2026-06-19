import 'package:equatable/equatable.dart';

class AchievementIssueEntity extends Equatable {
  final String studentId;
  final String type;
  final String title;
  final String issuedBy;

  const AchievementIssueEntity({
    required this.studentId,
    required this.type,
    required this.title,
    required this.issuedBy,
  });

  @override
  List<Object?> get props => [studentId, type, title, issuedBy];
}

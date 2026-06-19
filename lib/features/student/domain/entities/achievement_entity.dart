import 'package:equatable/equatable.dart';

enum AchievementType { star, badge, certificate }

class AchievementEntity extends Equatable {
  final String id;
  final String studentId;
  final AchievementType type;
  final String title;
  final String issuedBy;
  final DateTime date;

  const AchievementEntity({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    required this.issuedBy,
    required this.date,
  });

  @override
  List<Object?> get props => [id, studentId, type, title, issuedBy, date];
}

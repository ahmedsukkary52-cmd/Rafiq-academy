import 'package:equatable/equatable.dart';

class StudentProfileEntity extends Equatable {
  final String uid;
  final String name;
  final String? profileImageUrl;
  final String? halaqaId;
  final String currentPlanName;
  final double overallProgressPercent;
  final int totalStars;
  final List<String> badges;

  const StudentProfileEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    this.halaqaId,
    required this.currentPlanName,
    required this.overallProgressPercent,
    required this.totalStars,
    required this.badges,
  });

  @override
  List<Object?> get props => [
    uid,
    name,
    profileImageUrl,
    halaqaId,
    currentPlanName,
    overallProgressPercent,
    totalStars,
    badges,
  ];
}

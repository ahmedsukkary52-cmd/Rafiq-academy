import 'package:equatable/equatable.dart';

class TeacherManagementEntity extends Equatable {
  final String uid;
  final String name;
  final String? profileImageUrl;
  final List<String> halaqatIds;
  final double? performanceRating;
  final int weeklyQuota;

  const TeacherManagementEntity({
    required this.uid,
    required this.name,
    this.profileImageUrl,
    required this.halaqatIds,
    this.performanceRating,
    required this.weeklyQuota,
  });

  @override
  List<Object?> get props => [
    uid,
    name,
    profileImageUrl,
    halaqatIds,
    performanceRating,
    weeklyQuota,
  ];
}

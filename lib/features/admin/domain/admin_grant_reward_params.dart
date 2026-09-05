import 'package:equatable/equatable.dart';

/// Admin grant target — student or entire halaqa roster.
enum AdminRewardTargetKind { student, halaqa }

class AdminGrantRewardParams extends Equatable {
  final AdminRewardTargetKind targetKind;
  final String targetId;
  final String type;
  final String title;
  final String? description;
  final String grantedBy;
  final String? halaqaId;
  final String? halaqaName;
  final String? studentName;

  const AdminGrantRewardParams({
    required this.targetKind,
    required this.targetId,
    required this.type,
    required this.title,
    this.description,
    required this.grantedBy,
    this.halaqaId,
    this.halaqaName,
    this.studentName,
  });

  @override
  List<Object?> get props => [
    targetKind,
    targetId,
    type,
    title,
    description,
    grantedBy,
    halaqaId,
    halaqaName,
    studentName,
  ];
}

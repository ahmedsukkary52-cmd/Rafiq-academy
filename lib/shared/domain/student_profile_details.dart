import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import 'student_profile_summary.dart';

/// The staff student profile view (teacher, supervisor, admin): the
/// [summary] display fields plus the halaqa link, plan, streak and join date.
/// Student-only data (coins, avatars, stars, badges, lifecycle) is not exposed.
class StudentProfileDetails extends Equatable {
  final StudentProfileSummary summary;
  final String? halaqaId;
  final String currentPlanName;
  final int streakDays;
  final DateTime? createdAt;

  const StudentProfileDetails({
    required this.summary,
    this.halaqaId,
    required this.currentPlanName,
    required this.streakDays,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
    summary,
    halaqaId,
    currentPlanName,
    streakDays,
    createdAt,
  ];
}

/// Reads one student's [StudentProfileDetails]. Firestore Rules decide which
/// caller may read which student's profile.
abstract interface class StudentProfileDetailsReader {
  Future<Either<Failure, StudentProfileDetails>> getStudentProfileDetails(
    String studentId,
  );
}

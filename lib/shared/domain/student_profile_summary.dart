import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';

/// Display fields of a student's profile (`users` + `studentProfiles`), as
/// stored. Student-only data (coins, avatars, lifecycle) is not exposed.
class StudentProfileSummary extends Equatable {
  final String name;
  final String? profileImageUrl;
  final String halaqaName;
  final int level;
  final double overallProgressPercent;
  final int totalVersesMemorized;

  const StudentProfileSummary({
    required this.name,
    this.profileImageUrl,
    required this.halaqaName,
    required this.level,
    required this.overallProgressPercent,
    required this.totalVersesMemorized,
  });

  @override
  List<Object?> get props => [
    name,
    profileImageUrl,
    halaqaName,
    level,
    overallProgressPercent,
    totalVersesMemorized,
  ];
}

/// Reads one student's [StudentProfileSummary]. Firestore Rules decide which
/// caller may read which student's profile.
abstract interface class StudentProfileSummaryReader {
  Future<Either<Failure, StudentProfileSummary>> getStudentProfileSummary(
    String studentId,
  );
}

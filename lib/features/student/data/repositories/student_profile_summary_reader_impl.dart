import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/student_profile_summary.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/repositories/student_repository.dart';

/// Serves [StudentProfileSummaryReader] from the existing
/// [StudentRepository.getStudentProfile] read: same documents, same network
/// check, same failures.
class StudentProfileSummaryReaderImpl implements StudentProfileSummaryReader {
  final StudentRepository repository;

  const StudentProfileSummaryReaderImpl(this.repository);

  @override
  Future<Either<Failure, StudentProfileSummary>> getStudentProfileSummary(
    String studentId,
  ) async => (await repository.getStudentProfile(studentId)).map(summaryOf);

  static StudentProfileSummary summaryOf(StudentProfileEntity profile) =>
      StudentProfileSummary(
        name: profile.name,
        profileImageUrl: profile.profileImageUrl,
        halaqaName: profile.halaqaName,
        level: profile.level,
        overallProgressPercent: profile.overallProgressPercent,
        totalVersesMemorized: profile.totalVersesMemorized,
      );
}

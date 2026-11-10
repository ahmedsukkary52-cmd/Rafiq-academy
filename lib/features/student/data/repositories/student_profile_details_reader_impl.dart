import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/student_profile_details.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/repositories/student_repository.dart';
import 'student_profile_summary_reader_impl.dart';

/// Serves [StudentProfileDetailsReader] from the existing
/// [StudentRepository.getStudentProfile] read: same documents, same network
/// check, same failures.
class StudentProfileDetailsReaderImpl implements StudentProfileDetailsReader {
  final StudentRepository repository;

  const StudentProfileDetailsReaderImpl(this.repository);

  @override
  Future<Either<Failure, StudentProfileDetails>> getStudentProfileDetails(
    String studentId,
  ) async => (await repository.getStudentProfile(studentId)).map(_details);

  static StudentProfileDetails _details(StudentProfileEntity profile) =>
      StudentProfileDetails(
        summary: StudentProfileSummaryReaderImpl.summaryOf(profile),
        halaqaId: profile.halaqaId,
        currentPlanName: profile.currentPlanName,
        streakDays: profile.streakDays,
        createdAt: profile.createdAt,
      );
}

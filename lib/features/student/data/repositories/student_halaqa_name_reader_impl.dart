import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/halaqa_name_reader.dart';
import '../../domain/repositories/student_repository.dart';

/// Serves [HalaqaNameReader] from the existing
/// [StudentRepository.getStudentHalaqa] read: same document, same network
/// check, same failures.
class StudentHalaqaNameReaderImpl implements HalaqaNameReader {
  final StudentRepository repository;

  const StudentHalaqaNameReaderImpl(this.repository);

  @override
  Future<Either<Failure, String>> getHalaqaName(String halaqaId) async =>
      (await repository.getStudentHalaqa(halaqaId)).map((h) => h.name);
}

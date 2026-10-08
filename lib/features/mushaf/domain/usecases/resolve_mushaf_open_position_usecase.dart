import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/mushaf_position.dart';
import '../mushaf_page_range.dart';
import '../repositories/mushaf_reading_repository.dart';

class StudentIdParams extends Equatable {
  final String studentId;

  const StudentIdParams(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

/// Resolves open position: last-read if valid, else Al-Fatihah (D23).
@lazySingleton
class ResolveMushafOpenPositionUseCase
    extends UseCase<MushafPosition, StudentIdParams> {
  final MushafReadingRepository repository;

  ResolveMushafOpenPositionUseCase(this.repository);

  @override
  Future<Either<Failure, MushafPosition>> call(StudentIdParams params) async {
    final id = params.studentId.trim();
    if (id.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }

    final result = await repository.getLastRead(id);
    return result.fold(Left.new, (stored) {
      if (stored == null || !stored.isValid) {
        return const Right(MushafPosition.alFatihah);
      }
      if (!MushafPageRange.isValidPage(stored.pageNumber)) {
        return const Right(MushafPosition.alFatihah);
      }
      return Right(stored);
    });
  }
}

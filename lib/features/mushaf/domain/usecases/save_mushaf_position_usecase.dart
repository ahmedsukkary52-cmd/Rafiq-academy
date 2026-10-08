import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/mushaf_position.dart';
import '../mushaf_page_range.dart';
import '../repositories/mushaf_reading_repository.dart';

class SaveMushafPositionParams extends Equatable {
  final String studentId;
  final MushafPosition position;

  const SaveMushafPositionParams({
    required this.studentId,
    required this.position,
  });

  @override
  List<Object?> get props => [studentId, position];
}

@lazySingleton
class SaveMushafPositionUseCase
    extends UseCase<Unit, SaveMushafPositionParams> {
  final MushafReadingRepository repository;

  SaveMushafPositionUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SaveMushafPositionParams params) async {
    final id = params.studentId.trim();
    if (id.isEmpty) {
      return const Left(ValidationFailure('معرّف الطالب مطلوب'));
    }
    if (!params.position.isValid ||
        !MushafPageRange.isValidPage(params.position.pageNumber)) {
      return const Left(ValidationFailure('موضع قراءة غير صالح'));
    }
    return repository.saveLastRead(studentId: id, position: params.position);
  }
}

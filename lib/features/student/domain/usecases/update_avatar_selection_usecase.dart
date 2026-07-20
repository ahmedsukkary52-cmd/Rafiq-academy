import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/student_repository.dart';

@lazySingleton
class UpdateAvatarSelectionUseCase
    extends UseCase<Unit, UpdateAvatarSelectionParams> {
  final StudentRepository repository;

  UpdateAvatarSelectionUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateAvatarSelectionParams params) =>
      repository.updateAvatarSelection(
        studentId: params.studentId,
        avatarId: params.avatarId,
        unlockedAvatarIds: params.unlockedAvatarIds,
        coins: params.coins,
      );
}

class UpdateAvatarSelectionParams extends Equatable {
  final String studentId;
  final String avatarId;
  final List<String> unlockedAvatarIds;
  final int coins;

  const UpdateAvatarSelectionParams({
    required this.studentId,
    required this.avatarId,
    required this.unlockedAvatarIds,
    required this.coins,
  });

  @override
  List<Object?> get props => [studentId, avatarId, unlockedAvatarIds, coins];
}

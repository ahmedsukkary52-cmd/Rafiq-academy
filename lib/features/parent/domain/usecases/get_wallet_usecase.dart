import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../parent_wallet.dart';
import '../repositories/parent_repositories.dart';

@lazySingleton
class GetWalletUseCase extends UseCase<ParentWalletEntity, ParentIdParams> {
  final ParentRepository repository;

  GetWalletUseCase(this.repository);

  @override
  Future<Either<Failure, ParentWalletEntity>> call(ParentIdParams params) {
    final parentId = params.parentId.trim();
    if (parentId.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('معرّف ولي الأمر مطلوب')),
      );
    }
    return repository.getWallet(parentId);
  }
}

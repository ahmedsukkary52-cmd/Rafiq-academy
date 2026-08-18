import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../parent_household.dart';
import '../repositories/parent_repositories.dart';

class ParentHouseholdParams extends Equatable {
  final String parentId;
  final List<String> childrenIds;

  const ParentHouseholdParams({
    required this.parentId,
    required this.childrenIds,
  });

  @override
  List<Object?> get props => [parentId, childrenIds];
}

@lazySingleton
class GetParentHouseholdUseCase
    extends UseCase<ParentHousehold, ParentHouseholdParams> {
  final ParentRepository repository;

  GetParentHouseholdUseCase(this.repository);

  @override
  Future<Either<Failure, ParentHousehold>> call(ParentHouseholdParams params) {
    final parentId = params.parentId.trim();
    if (parentId.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('معرّف ولي الأمر مطلوب')),
      );
    }
    return repository.getHousehold(
      parentId: parentId,
      childrenIds: params.childrenIds,
    );
  }
}

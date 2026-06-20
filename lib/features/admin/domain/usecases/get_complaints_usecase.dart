import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/complaint_entity.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetComplaintsUseCase extends UseCase<List<ComplaintEntity>, NoParams> {
  final AdminRepository repository;

  GetComplaintsUseCase(this.repository);

  @override
  Future<Either<Failure, List<ComplaintEntity>>> call(NoParams params) =>
      repository.getComplaints();
}

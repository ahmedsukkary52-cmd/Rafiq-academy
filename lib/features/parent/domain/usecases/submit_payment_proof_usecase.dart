import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repositories.dart';

class SubmitPaymentProofParams extends Equatable {
  final String parentId;
  final String paymentId;
  final String localFilePath;

  const SubmitPaymentProofParams({
    required this.parentId,
    required this.paymentId,
    required this.localFilePath,
  });

  @override
  List<Object?> get props => [parentId, paymentId, localFilePath];
}

@lazySingleton
class SubmitPaymentProofUseCase
    extends UseCase<Unit, SubmitPaymentProofParams> {
  final ParentRepository repository;

  SubmitPaymentProofUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SubmitPaymentProofParams params) async {
    final parentId = params.parentId.trim();
    final paymentId = params.paymentId.trim();
    final localFilePath = params.localFilePath.trim();
    if (parentId.isEmpty) {
      return const Left(ValidationFailure('معرّف ولي الأمر مطلوب'));
    }
    if (paymentId.isEmpty) {
      return const Left(ValidationFailure('معرّف الدفعة مطلوب'));
    }
    if (localFilePath.isEmpty) {
      return const Left(ValidationFailure('ملف الإيصال مطلوب'));
    }
    return repository.submitPaymentProof(
      parentId: parentId,
      paymentId: paymentId,
      localFilePath: localFilePath,
    );
  }
}

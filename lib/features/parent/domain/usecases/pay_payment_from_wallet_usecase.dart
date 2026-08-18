import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../repositories/parent_repositories.dart';

class PayPaymentFromWalletParams extends Equatable {
  final String parentId;
  final String paymentId;

  const PayPaymentFromWalletParams({
    required this.parentId,
    required this.paymentId,
  });

  @override
  List<Object?> get props => [parentId, paymentId];
}

@lazySingleton
class PayPaymentFromWalletUseCase
    extends UseCase<Unit, PayPaymentFromWalletParams> {
  final ParentRepository repository;

  PayPaymentFromWalletUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(PayPaymentFromWalletParams params) {
    final parentId = params.parentId.trim();
    final paymentId = params.paymentId.trim();
    if (parentId.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('معرّف ولي الأمر مطلوب')),
      );
    }
    if (paymentId.isEmpty) {
      return Future.value(const Left(ValidationFailure('معرّف الدفعة مطلوب')));
    }
    return repository.payPaymentFromWallet(
      parentId: parentId,
      paymentId: paymentId,
    );
  }
}

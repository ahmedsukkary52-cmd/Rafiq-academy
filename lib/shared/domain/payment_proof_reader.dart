import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../core/error/failure.dart';
import '../../core/usecases/usecases.dart';
import 'parent_payment_proof.dart';

/// Read side of a payment proof (`proofStoragePath` through Storage Rules),
/// used by the parent and by Admin / scoped Supervisor review.
abstract interface class PaymentProofReader {
  Future<Either<Failure, Uint8List>> downloadPaymentProof({
    required String parentId,
    required String paymentId,
    required String storagePath,
  });
}

class DownloadPaymentProofParams extends Equatable {
  final String parentId;
  final String paymentId;
  final String storagePath;

  const DownloadPaymentProofParams({
    required this.parentId,
    required this.paymentId,
    required this.storagePath,
  });

  @override
  List<Object?> get props => [parentId, paymentId, storagePath];
}

/// Fails closed before any Storage request when the persisted path is not
/// this payment's own proof object.
@lazySingleton
class DownloadPaymentProofUseCase
    extends UseCase<Uint8List, DownloadPaymentProofParams> {
  final PaymentProofReader repository;

  DownloadPaymentProofUseCase(this.repository);

  @override
  Future<Either<Failure, Uint8List>> call(
    DownloadPaymentProofParams params,
  ) async {
    if (!ParentPaymentProofContract.isTrustedStoragePath(
      params.storagePath,
      parentId: params.parentId,
      paymentId: params.paymentId,
    )) {
      return const Left(
        ValidationFailure(
          'صورة الإيصال غير متاحة. اطلب من ولي الأمر إعادة رفعها',
        ),
      );
    }
    return repository.downloadPaymentProof(
      parentId: params.parentId.trim(),
      paymentId: params.paymentId.trim(),
      storagePath: params.storagePath.trim(),
    );
  }
}

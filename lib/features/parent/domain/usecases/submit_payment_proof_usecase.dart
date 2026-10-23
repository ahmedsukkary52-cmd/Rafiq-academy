import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../parent_payment_proof.dart';
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
  final ParentRepository repository;

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

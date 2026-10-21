import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../../domain/repositories/admin_operations_repository.dart';
import '../datasources/admin_operations_remote_datasource.dart';

@LazySingleton(as: AdminOperationsRepository)
class AdminOperationsRepositoryImpl implements AdminOperationsRepository {
  final AdminOperationsRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const AdminOperationsRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<AdminDirectoryUser>>> listUsersByRole(
    String role,
  ) => _run(() => remoteDatasource.listUsersByRole(role));

  @override
  Future<Either<Failure, List<HalaqaEntity>>> listHalaqat() =>
      _run(remoteDatasource.listHalaqat);

  @override
  Future<Either<Failure, List<String>>> getParentChildrenIds(String parentId) =>
      _run(() => remoteDatasource.getParentChildrenIds(parentId));

  @override
  Future<Either<Failure, ParentLinkResult>> linkParentChild({
    required String parentId,
    required String studentId,
    required ParentLinkOperation operation,
  }) => _run(
    () => remoteDatasource.linkParentChild(
      parentId: parentId,
      studentId: studentId,
      operation: operation,
    ),
  );

  @override
  Future<Either<Failure, String>> createHalaqa({
    required String name,
    required String teacherId,
    String? supervisorId,
    String? meetingLink,
    required List<HalaqaSlotInput> schedule,
    required String requestId,
  }) => _run(
    () => remoteDatasource.createHalaqa(
      name: name,
      teacherId: teacherId,
      supervisorId: supervisorId,
      meetingLink: meetingLink,
      schedule: schedule,
      requestId: requestId,
    ),
  );

  @override
  Future<Either<Failure, String>> addHalaqaSlot({
    required String halaqaId,
    required HalaqaSlotInput slot,
  }) => _run(
    () => remoteDatasource.addHalaqaSlot(halaqaId: halaqaId, slot: slot),
  );

  @override
  Future<Either<Failure, MeetingLinkChange>> setHalaqaMeetingLink({
    required String halaqaId,
    String? meetingLink,
    bool clear = false,
  }) => _run(
    () => remoteDatasource.setHalaqaMeetingLink(
      halaqaId: halaqaId,
      meetingLink: meetingLink,
      clear: clear,
    ),
  );

  @override
  Future<Either<Failure, Unit>> transferStudent({
    required String studentId,
    required String fromHalaqaId,
    required String toHalaqaId,
  }) => _run(() async {
    await remoteDatasource.transferStudent(
      studentId: studentId,
      fromHalaqaId: fromHalaqaId,
      toHalaqaId: toHalaqaId,
    );
    return unit;
  });

  @override
  Future<Either<Failure, List<PaymentReviewItem>>> listPendingPaymentProofs({
    required String reviewerUid,
    required bool isAdmin,
  }) => _run(
    () => remoteDatasource.listPendingPaymentProofs(
      reviewerUid: reviewerUid,
      isAdmin: isAdmin,
    ),
  );

  @override
  Future<Either<Failure, Unit>> reviewPaymentProof({
    required String paymentId,
    required PaymentReviewDecision decision,
    String? notes,
    double? amountPaidConfirmed,
  }) => _run(() async {
    await remoteDatasource.reviewPaymentProof(
      paymentId: paymentId,
      decision: decision,
      notes: notes,
      amountPaidConfirmed: amountPaidConfirmed,
    );
    return unit;
  });
}

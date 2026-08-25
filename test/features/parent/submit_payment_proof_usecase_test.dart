import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_household.dart';
import 'package:rafiq_academy/features/parent/domain/parent_payment_proof.dart';
import 'package:rafiq_academy/features/parent/domain/parent_wallet.dart';
import 'package:rafiq_academy/features/parent/domain/repositories/parent_repositories.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/submit_payment_proof_usecase.dart';

class _FakeParentRepository implements ParentRepository {
  String? proofParentId;
  String? proofPaymentId;
  String? proofPath;
  Either<Failure, Unit> proofResult = const Right(unit);

  @override
  Future<Either<Failure, Unit>> submitPaymentProof({
    required String parentId,
    required String paymentId,
    required String localFilePath,
  }) async {
    proofParentId = parentId;
    proofPaymentId = paymentId;
    proofPath = localFilePath;
    return proofResult;
  }

  @override
  Future<Either<Failure, List<String>>> getChildrenIds(String parentId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, WeeklyReportEntity>> getWeeklyReport({
    required String studentId,
    required DateTime weekStart,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<PaymentEntity>>> getPayments(String parentId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> submitAbsenceRequest(
    AbsenceRequestEntity request,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<AbsenceRequestEntity>>>
  getAbsenceRequestsForParent(String parentId) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<ParentHalaqaOption>>> getHalaqatForStudent(
    String studentId,
  ) => throw UnimplementedError();

  @override
  Stream<Either<Failure, List<String>>> watchChildrenAssignments(
    String parentId,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, PaymentInitiationEntity>> initiatePayment(
    String paymentId,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, ParentWalletEntity>> getWallet(String parentId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> payPaymentFromWallet({
    required String parentId,
    required String paymentId,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, ParentHousehold>> getHousehold({
    required String parentId,
    required List<String> childrenIds,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<ParentAttendanceMark>>> getAttendanceMarks({
    required String studentId,
    required DateTime start,
    required DateTime endExclusive,
  }) => throw UnimplementedError();
}

void main() {
  group('SubmitPaymentProofUseCase', () {
    test('rejects empty fields before repository', () async {
      final repo = _FakeParentRepository();
      final useCase = SubmitPaymentProofUseCase(repo);

      final emptyParent = await useCase(
        const SubmitPaymentProofParams(
          parentId: ' ',
          paymentId: 'pay1',
          localFilePath: '/tmp/a.jpg',
        ),
      );
      final emptyPath = await useCase(
        const SubmitPaymentProofParams(
          parentId: 'p1',
          paymentId: 'pay1',
          localFilePath: '',
        ),
      );

      expect(emptyParent.isLeft(), isTrue);
      expect(emptyPath.isLeft(), isTrue);
      expect(repo.proofPaymentId, isNull);
    });

    test('forwards valid proof upload to repository', () async {
      final repo = _FakeParentRepository();
      final useCase = SubmitPaymentProofUseCase(repo);

      final result = await useCase(
        const SubmitPaymentProofParams(
          parentId: 'p1',
          paymentId: 'pay1',
          localFilePath: '/tmp/shot.png',
        ),
      );

      expect(result.isRight(), isTrue);
      expect(repo.proofParentId, 'p1');
      expect(repo.proofPaymentId, 'pay1');
      expect(repo.proofPath, '/tmp/shot.png');
    });
  });

  group('PaymentProofStatusX', () {
    test('hasProofAwaitingReview when path set and not paid', () {
      final due = DateTime(2026, 1, 1);
      final withProof = PaymentEntity(
        id: 'pay1',
        studentId: 's1',
        parentId: 'p1',
        amount: 100,
        dueDate: due,
        status: PaymentStatus.due,
        proofStoragePath: 'payment_proofs/p1/pay1/1.jpg',
        proofSubmittedAt: due,
        method: ParentPaymentProofContract.externalMethod,
      );
      final paid = PaymentEntity(
        id: 'pay2',
        studentId: 's1',
        parentId: 'p1',
        amount: 100,
        dueDate: due,
        status: PaymentStatus.paid,
        proofStoragePath: 'payment_proofs/p1/pay2/1.jpg',
      );

      expect(withProof.hasProofAwaitingReview, isTrue);
      expect(paid.hasProofAwaitingReview, isFalse);
      expect(withProof.status, isNot(PaymentStatus.paid));
    });
  });
}

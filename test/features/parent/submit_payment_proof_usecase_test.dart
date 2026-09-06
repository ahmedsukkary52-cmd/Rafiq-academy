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
    final due = DateTime(2026, 1, 1);

    PaymentEntity payment({
      PaymentStatus status = PaymentStatus.due,
      String? reviewStatus,
      String? proofStoragePath = 'payment_proofs/p1/pay1/1.jpg',
      DateTime? proofSubmittedAt,
      double? remainingAmount,
      String? reviewNotes,
    }) {
      return PaymentEntity(
        id: 'pay1',
        studentId: 's1',
        parentId: 'p1',
        amount: 100,
        dueDate: due,
        status: status,
        method: ParentPaymentProofContract.externalMethod,
        proofStoragePath: proofStoragePath,
        proofSubmittedAt: proofSubmittedAt,
        reviewStatus: reviewStatus,
        reviewNotes: reviewNotes,
        remainingAmount: remainingAmount,
      );
    }

    test('hasProofAwaitingReview when path set and not paid', () {
      final withProof = payment(proofSubmittedAt: due);
      final paid = payment(status: PaymentStatus.paid);

      expect(withProof.hasProofAwaitingReview, isTrue);
      expect(withProof.hasSupervisorReview, isFalse);
      expect(paid.hasProofAwaitingReview, isFalse);
      expect(withProof.status, isNot(PaymentStatus.paid));
    });

    test('pending_review still awaits Supervisor review', () {
      final pending = payment(
        reviewStatus: ParentPaymentProofContract.pendingReview,
        proofSubmittedAt: due,
      );

      expect(pending.hasProofAwaitingReview, isTrue);
      expect(pending.hasSupervisorReview, isFalse);
    });

    test('pending_review awaits review even without a stored proof path', () {
      final pending = payment(
        reviewStatus: ParentPaymentProofContract.pendingReview,
        proofStoragePath: null,
      );

      expect(pending.hasProofAwaitingReview, isTrue);
    });

    test('rejected is reviewed and no longer awaiting', () {
      final rejected = payment(
        reviewStatus: ParentPaymentProofContract.rejected,
        proofSubmittedAt: due,
        reviewNotes: 'الصورة غير واضحة',
      );

      expect(rejected.hasProofAwaitingReview, isFalse);
      expect(rejected.hasSupervisorReview, isTrue);
      expect(rejected.status, isNot(PaymentStatus.paid));
    });

    test('partial is reviewed and no longer awaiting', () {
      final partial = payment(
        reviewStatus: ParentPaymentProofContract.partial,
        proofSubmittedAt: due,
        remainingAmount: 40,
      );

      expect(partial.hasProofAwaitingReview, isFalse);
      expect(partial.hasSupervisorReview, isTrue);
      expect(partial.remainingAmount, 40);
    });

    test('approved is reviewed and no longer awaiting', () {
      final approved = payment(
        reviewStatus: ParentPaymentProofContract.approved,
        proofSubmittedAt: due,
      );

      expect(approved.hasProofAwaitingReview, isFalse);
      expect(approved.hasSupervisorReview, isTrue);
    });

    test('paid never awaits review regardless of reviewStatus', () {
      final paid = payment(status: PaymentStatus.paid);
      final paidPending = payment(
        status: PaymentStatus.paid,
        reviewStatus: ParentPaymentProofContract.pendingReview,
      );

      expect(paid.hasProofAwaitingReview, isFalse);
      expect(paidPending.hasProofAwaitingReview, isFalse);
    });

    test('no proof and no review is not awaiting', () {
      final clean = payment(proofStoragePath: null);

      expect(clean.hasProofAwaitingReview, isFalse);
      expect(clean.hasSupervisorReview, isFalse);
    });
  });
}

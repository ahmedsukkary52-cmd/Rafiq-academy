import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/domain/entities/parent_entities.dart';
import 'package:rafiq_academy/features/parent/domain/parent_payment_proof.dart';

void main() {
  PaymentEntity payment({
    PaymentStatus status = PaymentStatus.due,
    String? reviewStatus,
    String? proofPath,
  }) {
    return PaymentEntity(
      id: 'p1',
      studentId: 's1',
      parentId: 'par1',
      amount: 100,
      dueDate: DateTime(2026, 1, 1),
      status: status,
      proofStoragePath: proofPath,
      reviewStatus: reviewStatus,
    );
  }

  test('proof with pending_review awaits supervisor', () {
    final p = payment(
      proofPath: 'payment_proofs/a/b/c.jpg',
      reviewStatus: ParentPaymentProofContract.pendingReview,
    );
    expect(p.hasProofAwaitingReview, isTrue);
    expect(p.hasSupervisorReview, isFalse);
  });

  test('approved review is not awaiting', () {
    final p = payment(
      status: PaymentStatus.paid,
      proofPath: 'payment_proofs/a/b/c.jpg',
      reviewStatus: ParentPaymentProofContract.approved,
    );
    expect(p.hasProofAwaitingReview, isFalse);
    expect(p.hasSupervisorReview, isTrue);
  });

  test('rejected review is complete', () {
    final p = payment(
      proofPath: 'payment_proofs/a/b/c.jpg',
      reviewStatus: ParentPaymentProofContract.rejected,
    );
    expect(p.hasProofAwaitingReview, isFalse);
    expect(p.hasSupervisorReview, isTrue);
  });
}

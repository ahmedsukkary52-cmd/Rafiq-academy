import 'package:equatable/equatable.dart';

/// Parent wallet contract (Sprint 2).
///
/// Collection: `wallets/{parentId}`
/// Fields: `balance` (num), `updatedAt` (timestamp)
/// Ledger: `wallets/{parentId}/ledger/{id}`
///   `{ type: debit|credit, amount, paymentId, createdAt }`
///
/// Missing wallet document ⇒ balance 0 (no auto-create on read).
/// Parent UI does not top-up. Academy credit is out of this feature.
/// Pay: Firestore transaction — if `balance >= amount` and payment is not
/// already `paid`, decrement balance, write ledger debit, set payment
/// `status: paid`, `method: wallet`, `paidAt`.
class ParentWalletContract {
  const ParentWalletContract._();

  static const String collection = 'wallets';
  static const String ledgerSubcollection = 'ledger';
  static const String balanceField = 'balance';
  static const String updatedAtField = 'updatedAt';
  static const String typeDebit = 'debit';
  static const String typeCredit = 'credit';
  static const String paymentMethod = 'wallet';
}

class ParentWalletEntity extends Equatable {
  final String parentId;
  final double balance;
  final DateTime? updatedAt;

  const ParentWalletEntity({
    required this.parentId,
    required this.balance,
    this.updatedAt,
  });

  factory ParentWalletEntity.empty(String parentId) =>
      ParentWalletEntity(parentId: parentId, balance: 0);

  @override
  List<Object?> get props => [parentId, balance, updatedAt];
}

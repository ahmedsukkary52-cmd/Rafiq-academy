import 'package:equatable/equatable.dart';

/// Parent wallet contract — **D2 OUT** (Vodafone Cash + screenshot only).
///
/// Collection: `wallets/{parentId}`
/// Fields: `balance` (num), `updatedAt` (timestamp)
/// Ledger: `wallets/{parentId}/ledger/{id}`
///   `{ type: debit|credit, amount, paymentId, createdAt }`
///
/// WA-2: [enabled] is false — client wallet pay path must not set `status: paid`.
/// Firestore Rules deny wallet writes. Historical code retained for quarantine.
class ParentWalletContract {
  const ParentWalletContract._();

  /// Product lock D2 — wallet payment is not a production payment path.
  static const bool enabled = false;

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

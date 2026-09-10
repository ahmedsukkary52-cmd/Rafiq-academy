/// C4 / WA-5 — pricing rules + invoice snapshot fields on `payments`.
class PricingRulesContract {
  const PricingRulesContract._();

  static const String collection = 'pricingRules';

  static const String scopeAcademyDefault = 'academy_default';
  static const String scopeHalaqa = 'halaqa';
  static const String scopeStudent = 'student';

  static const String scopeField = 'scope';
  static const String scopeIdField = 'scopeId';
  static const String amountField = 'amount';
  static const String currencyField = 'currency';
  static const String billingPeriodField = 'billingPeriod';
  static const String effectiveFromField = 'effectiveFrom';
  static const String effectiveToField = 'effectiveTo';
  static const String activeField = 'active';
  static const String versionField = 'version';
  static const String createdAtField = 'createdAt';
  static const String updatedAtField = 'updatedAt';
  static const String updatedByField = 'updatedBy';

  /// Server-owned snapshot fields written only on invoice create (payments).
  static const String pricingRuleIdField = 'pricingRuleId';
  static const String pricingRuleVersionField = 'pricingRuleVersion';
  static const String issuedAtField = 'issuedAt';
  static const String periodKeyField = 'periodKey';
  static const String paymentCurrencyField = 'currency';

  /// Deterministic payment doc id for student+period idempotency.
  static String invoiceDocId({
    required String studentId,
    required String periodKey,
  }) => 'inv_${studentId.trim()}_${periodKey.trim()}';

  /// Calendar period key `yyyy-MM` (invoice idempotency).
  static String periodKeyForDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }
}

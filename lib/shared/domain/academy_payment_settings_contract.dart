/// C3 / WA-4 — academy payment settings (public projection vs Admin defaults).
///
/// Read: Admin + Parent (`paymentPublic` only). Supervisor is not authorized
/// (C3 lists Supervisor R as optional; WAVE_A locks Parent-only).
class AcademyPaymentSettingsContract {
  const AcademyPaymentSettingsContract._();

  static const String collection = 'academySettings';
  static const String paymentPublicDocId = 'paymentPublic';
  static const String pricingDefaultsDocId = 'pricingDefaults';

  // paymentPublic
  static const String vodafoneCashDestinationField = 'vodafoneCashDestination';
  static const String updatedAtField = 'updatedAt';
  static const String updatedByField = 'updatedBy';

  // pricingDefaults (Admin-only)
  static const String gracePeriodDaysField = 'gracePeriodDays';
  static const String defaultCurrencyField = 'defaultCurrency';
  static const String defaultBillingPeriodField = 'defaultBillingPeriod';

  static const String defaultCurrency = 'EGP';
  static const String defaultBillingPeriod = 'monthly';
  static const int defaultGracePeriodDays = 7;
}

import 'package:equatable/equatable.dart';

import 'academy_payment_settings_contract.dart';

class PaymentPublicSettingsEntity extends Equatable {
  final String vodafoneCashDestination;
  final DateTime? updatedAt;
  final String? updatedBy;

  const PaymentPublicSettingsEntity({
    this.vodafoneCashDestination = '',
    this.updatedAt,
    this.updatedBy,
  });

  bool get hasDestination => vodafoneCashDestination.trim().isNotEmpty;

  @override
  List<Object?> get props => [vodafoneCashDestination, updatedAt, updatedBy];
}

class PricingDefaultsEntity extends Equatable {
  final int gracePeriodDays;
  final String defaultCurrency;
  final String defaultBillingPeriod;
  final DateTime? updatedAt;
  final String? updatedBy;

  const PricingDefaultsEntity({
    this.gracePeriodDays =
        AcademyPaymentSettingsContract.defaultGracePeriodDays,
    this.defaultCurrency = AcademyPaymentSettingsContract.defaultCurrency,
    this.defaultBillingPeriod =
        AcademyPaymentSettingsContract.defaultBillingPeriod,
    this.updatedAt,
    this.updatedBy,
  });

  @override
  List<Object?> get props => [
    gracePeriodDays,
    defaultCurrency,
    defaultBillingPeriod,
    updatedAt,
    updatedBy,
  ];
}

class PricingRuleEntity extends Equatable {
  final String id;
  final String scope;
  final String? scopeId;
  final double amount;
  final String currency;
  final String billingPeriod;
  final bool active;
  final int version;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? updatedAt;
  final String? updatedBy;

  const PricingRuleEntity({
    required this.id,
    required this.scope,
    this.scopeId,
    required this.amount,
    this.currency = AcademyPaymentSettingsContract.defaultCurrency,
    this.billingPeriod = AcademyPaymentSettingsContract.defaultBillingPeriod,
    this.active = true,
    this.version = 1,
    this.effectiveFrom,
    this.effectiveTo,
    this.updatedAt,
    this.updatedBy,
  });

  @override
  List<Object?> get props => [
    id,
    scope,
    scopeId,
    amount,
    currency,
    billingPeriod,
    active,
    version,
    effectiveFrom,
    effectiveTo,
    updatedAt,
    updatedBy,
  ];
}

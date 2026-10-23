import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/academy_billing_entities.dart';
import '../domain/academy_payment_settings_contract.dart';

/// `academySettings/paymentPublic` → entity. Non-string values read as unset.
PaymentPublicSettingsEntity paymentPublicSettingsFromData(
  Map<String, dynamic>? data,
) {
  final d = data ?? const <String, dynamic>{};
  String text(String field) {
    final v = d[field];
    return v is String ? v.trim() : '';
  }

  final updated = d[AcademyPaymentSettingsContract.updatedAtField];
  final by = d[AcademyPaymentSettingsContract.updatedByField];
  return PaymentPublicSettingsEntity(
    vodafoneCashDestination: text(
      AcademyPaymentSettingsContract.vodafoneCashDestinationField,
    ),
    instapayDestination: text(
      AcademyPaymentSettingsContract.instapayDestinationField,
    ),
    updatedAt: updated is Timestamp ? updated.toDate() : null,
    updatedBy: by is String ? by : null,
  );
}

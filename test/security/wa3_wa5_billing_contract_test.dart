import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/academy_payment_settings_contract.dart';
import 'package:rafiq_academy/shared/domain/payment_access_contract.dart';

void main() {
  group('WA-3 paymentAccess', () {
    test('accepts only frozen statuses', () {
      expect(PaymentAccessContract.isValidStatus('ok'), isTrue);
      expect(PaymentAccessContract.isValidStatus('reminded'), isTrue);
      expect(PaymentAccessContract.isValidStatus('due_warning'), isTrue);
      expect(PaymentAccessContract.isValidStatus('in_grace'), isTrue);
      expect(PaymentAccessContract.isValidStatus('suspended'), isTrue);
      expect(PaymentAccessContract.isValidStatus('paid'), isFalse);
      expect(PaymentAccessContract.isValidStatus('active'), isFalse);
      expect(PaymentAccessContract.isValidStatus(''), isFalse);
      expect(PaymentAccessContract.isValidStatus(null), isFalse);
    });

    test('suspended is distinct from users.isActive semantics', () {
      expect(PaymentAccessContract.isSuspended('suspended'), isTrue);
      expect(PaymentAccessContract.isSuspended('ok'), isFalse);
    });
  });

  group('WA-4 academy settings contracts', () {
    test('paymentPublic and pricingDefaults doc ids are frozen', () {
      expect(
        AcademyPaymentSettingsContract.paymentPublicDocId,
        'paymentPublic',
      );
      expect(
        AcademyPaymentSettingsContract.pricingDefaultsDocId,
        'pricingDefaults',
      );
      expect(
        AcademyPaymentSettingsContract.vodafoneCashDestinationField,
        'vodafoneCashDestination',
      );
      expect(
        AcademyPaymentSettingsContract.instapayDestinationField,
        'instapayDestination',
      );
    });

    test('paymentPublic rules allow exactly the two independent '
        'destination fields plus audit fields', () {
      final rules = File('firestore.rules').readAsStringSync();
      final block = RegExp(
        r"match /academySettings/\{docId\} \{[\s\S]*?hasOnly\(\[([\s\S]*?)\]\)",
      ).firstMatch(rules);
      expect(block, isNotNull);
      final fields = RegExp(
        r"'(\w+)'",
      ).allMatches(block!.group(1)!).map((m) => m.group(1)).toSet();
      expect(fields, {
        AcademyPaymentSettingsContract.vodafoneCashDestinationField,
        AcademyPaymentSettingsContract.instapayDestinationField,
        AcademyPaymentSettingsContract.updatedAtField,
        AcademyPaymentSettingsContract.updatedByField,
      });
    });
  });

  // WA-5 invoice ids are issued server-side; see
  // functions/test/wa3_wa5_billing.test.mjs (functions/src/billing/paymentHelpers.ts).
}

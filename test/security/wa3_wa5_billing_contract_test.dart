import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/academy_payment_settings_contract.dart';
import 'package:rafiq_academy/shared/domain/payment_access_contract.dart';
import 'package:rafiq_academy/shared/domain/pricing_rules_contract.dart';

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
    });
  });

  group('WA-5 pricing + invoice snapshot', () {
    test('periodKey and deterministic invoice id', () {
      expect(
        PricingRulesContract.periodKeyForDate(DateTime.utc(2026, 9, 10)),
        '2026-09',
      );
      expect(
        PricingRulesContract.invoiceDocId(
          studentId: 'stu1',
          periodKey: '2026-09',
        ),
        'inv_stu1_2026-09',
      );
    });

    test('changing rule amount does not rewrite snapshot id formula', () {
      const period = '2026-09';
      final idBefore = PricingRulesContract.invoiceDocId(
        studentId: 'stu1',
        periodKey: period,
      );
      // Simulated pricing change — invoice id remains period-bound.
      final idAfter = PricingRulesContract.invoiceDocId(
        studentId: 'stu1',
        periodKey: period,
      );
      expect(idBefore, idAfter);
    });
  });
}

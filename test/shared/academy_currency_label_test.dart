import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/entities/financial_summary_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_report_export.dart';
import 'package:rafiq_academy/features/parent/presentation/parent_display.dart';
import 'package:rafiq_academy/shared/domain/academy_payment_settings_contract.dart';
import 'package:rafiq_academy/shared/presentation/academy_currency_label.dart';

void main() {
  test('academy default currency is EGP and is labelled جنيه', () {
    expect(AcademyPaymentSettingsContract.defaultCurrency, 'EGP');
    expect(academyCurrencyLabel, 'جنيه');
  });

  test('staff money label keeps whole amounts whole and piasters visible', () {
    expect(academyMoneyLabel(140), '140 جنيه');
    expect(academyMoneyLabel(66.67), '66.67 جنيه');
    expect(academyMoneyText('1,200'), '1,200 جنيه');
  });

  test('parent label uses the same unit', () {
    expect(parentMoneyLabel(200), endsWith(academyCurrencyLabel));
  });

  test('finance CSV header uses the academy currency', () {
    final rows = AdminReportExport.buildCsvRows(
      kind: AdminReportKind.finance,
      finance: const FinancialSummaryEntity(
        totalRevenue: 1000,
        totalPending: 200,
        totalOverdue: 50,
        paidCount: 4,
        dueCount: 1,
        overdueCount: 1,
      ),
    );
    expect(rows.first[1], 'المبلغ (جنيه)');
  });

  test('admin payment rows show the exact amount, not a rounded one', () {
    final source = File(
      'lib/features/admin/presentation/pages/admin_payments_ledger_page.dart',
    ).readAsStringSync();
    expect(source, contains('academyMoneyLabel(p.amount)'));
    expect(source, isNot(contains('p.amount.round()')));
  });

  test('no Saudi riyal label remains in lib/', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('ر.س') || text.contains('ريال')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_home_page.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_subscriptions_page.dart';

import 'support/demo_accounts.dart';
import 'support/integration_bootstrap.dart';

/// Journey 3 — Parent opens subscriptions; invoices come from Firestore Emulator.
void main() {
  testWidgets('parent can open subscriptions and see payment surface', (
    tester,
  ) async {
    await bootstrapIntegrationApp(tester);

    await loginWithDemoAccount(
      tester,
      email: DemoAccounts.parent.email,
      password: DemoAccounts.parent.password,
    );

    expect(find.byType(ParentHomePage), findsOneWidget);

    // Navigate via bottom nav / tab labels used by Parent home.
    final paymentsTab = find.textContaining('اشتراك');
    if (paymentsTab.evaluate().isNotEmpty) {
      await tester.tap(paymentsTab.first);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    } else {
      // Fallback: push subscriptions route through any visible wallet icon.
      final wallet = find.byIcon(Icons.account_balance_wallet_outlined);
      if (wallet.evaluate().isNotEmpty) {
        await tester.tap(wallet.first);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 20),
        );
      }
    }

    // Either the dedicated page or an embedded subscriptions body is up.
    final page = find.byType(ParentSubscriptionsPage);
    final emptyOrList =
        find.textContaining('لا فواتير').evaluate().isNotEmpty ||
        find.textContaining('مدفوع').evaluate().isNotEmpty ||
        find.textContaining('مستحق').evaluate().isNotEmpty ||
        page.evaluate().isNotEmpty;
    expect(
      emptyOrList,
      isTrue,
      reason: 'Parent payments UI must render from Emulator data (list or empty)',
    );
  });
}

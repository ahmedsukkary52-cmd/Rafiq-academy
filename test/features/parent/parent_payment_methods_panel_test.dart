import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/parent/presentation/widgets/parent_payment_methods_panel.dart';

import '../../helpers/payment_destination_placeholders.dart';

Future<void> _pump(
  WidgetTester tester, {
  SectionStatus status = SectionStatus.loaded,
  String vodafoneCash = '',
  String instapay = '',
  VoidCallback? onRetry,
  PaymentLinkOpener? openLink,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: ParentPaymentMethodsPanel(
              status: status,
              vodafoneCashDestination: vodafoneCash,
              instapayDestination: instapay,
              onRetry: onRetry ?? () {},
              openLink: openLink ?? (_) async => true,
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _k(String key) => find.byKey(Key(key));

void main() {
  testWidgets('shows each configured destination under its own method', (
    tester,
  ) async {
    await _pump(
      tester,
      vodafoneCash: kDevPlaceholderVodafoneCash,
      instapay: kDevPlaceholderInstapayAddress,
    );

    expect(
      find.descendant(
        of: _k('vodafone-cash-destination'),
        matching: find.text(kDevPlaceholderVodafoneCash),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _k('instapay-destination'),
        matching: find.text(kDevPlaceholderInstapayAddress),
      ),
      findsOneWidget,
    );
    expect(_k('instapay-open-link'), findsNothing);
  });

  testWidgets('one method unset does not borrow the other destination', (
    tester,
  ) async {
    await _pump(tester, vodafoneCash: kDevPlaceholderVodafoneCash);

    expect(_k('vodafone-cash-destination'), findsOneWidget);
    expect(_k('instapay-unset'), findsOneWidget);
    expect(find.text(ParentPaymentMethodsText.instapayUnset), findsOneWidget);
    expect(find.text(kDevPlaceholderVodafoneCash), findsOneWidget);
  });

  testWidgets('both unset shows both Arabic notices', (tester) async {
    await _pump(tester);
    expect(
      find.text(ParentPaymentMethodsText.vodafoneCashUnset),
      findsOneWidget,
    );
    expect(find.text(ParentPaymentMethodsText.instapayUnset), findsOneWidget);
  });

  testWidgets('invalid stored values are flagged and not displayed', (
    tester,
  ) async {
    const badWallet = '0110000000';
    const badLink = 'http://dev-placeholder.invalid/pay';
    await _pump(tester, vodafoneCash: badWallet, instapay: badLink);

    expect(_k('vodafone-cash-invalid'), findsOneWidget);
    expect(_k('instapay-invalid'), findsOneWidget);
    expect(find.text(badWallet), findsNothing);
    expect(find.text(badLink), findsNothing);
    expect(_k('instapay-open-link'), findsNothing);
  });

  testWidgets('load failure shows an Arabic error with retry, not "unset"', (
    tester,
  ) async {
    var retries = 0;
    await _pump(tester, status: SectionStatus.error, onRetry: () => retries++);

    expect(_k('payment-methods-load-error'), findsOneWidget);
    expect(find.text(ParentPaymentMethodsText.loadFailed), findsOneWidget);
    expect(_k('vodafone-cash-unset'), findsNothing);
    expect(_k('instapay-unset'), findsNothing);
    await tester.tap(find.text(ParentPaymentMethodsText.retry));
    expect(retries, 1);
  });

  testWidgets('loading state is explicit', (tester) async {
    await _pump(tester, status: SectionStatus.loading);
    expect(_k('payment-methods-loading'), findsOneWidget);
  });

  testWidgets('InstaPay link opens via https and reports failures', (
    tester,
  ) async {
    final opened = <Uri>[];
    var result = true;
    await _pump(
      tester,
      instapay: kDevPlaceholderInstapayLink,
      openLink: (uri) async {
        opened.add(uri);
        return result;
      },
    );

    await tester.tap(_k('instapay-open-link'));
    await tester.pump();
    expect(opened.single.toString(), kDevPlaceholderInstapayLink);
    expect(find.text(ParentPaymentMethodsText.linkOpenFailed), findsNothing);

    result = false;
    await tester.tap(_k('instapay-open-link'));
    await tester.pump();
    expect(find.text(ParentPaymentMethodsText.linkOpenFailed), findsOneWidget);
  });

  testWidgets('a launcher exception is shown as the same Arabic message', (
    tester,
  ) async {
    await _pump(
      tester,
      instapay: kDevPlaceholderInstapayLink,
      openLink: (_) async => throw StateError('no handler'),
    );
    await tester.tap(_k('instapay-open-link'));
    await tester.pump();
    expect(find.text(ParentPaymentMethodsText.linkOpenFailed), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/user_facing_error.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

void main() {
  testWidgets('AppSnackBar.showError sanitizes technical dumps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AppSnackBar.showError(
                  context,
                  "Bad state: field 'x' does not exist",
                ),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    expect(find.text(genericErrorText), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
  });
}

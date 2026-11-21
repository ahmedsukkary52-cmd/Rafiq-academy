import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/parent/presentation/pages/parent_home_page.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_home_page.dart';

import 'support/demo_accounts.dart';
import 'support/integration_bootstrap.dart';

/// Journey 1 — Authentication + role-based routing against Auth+Firestore Emulators.
void main() {
  testWidgets('student demo login reaches StudentHomePage', (tester) async {
    await bootstrapIntegrationApp(tester);

    await loginWithDemoAccount(
      tester,
      email: DemoAccounts.student.email,
      password: DemoAccounts.student.password,
    );

    expect(find.byType(StudentHomePage), findsOneWidget);
    expect(find.byType(ParentHomePage), findsNothing);
  });

  testWidgets('parent demo login reaches ParentHomePage', (tester) async {
    await bootstrapIntegrationApp(tester);

    await loginWithDemoAccount(
      tester,
      email: DemoAccounts.parent.email,
      password: DemoAccounts.parent.password,
    );

    expect(find.byType(ParentHomePage), findsOneWidget);
    expect(find.byType(StudentHomePage), findsNothing);
  });

  testWidgets('wrong password stays on login (Auth Emulator denial)', (
    tester,
  ) async {
    await bootstrapIntegrationApp(tester);

    await loginWithDemoAccount(
      tester,
      email: DemoAccounts.student.email,
      password: 'Wrong!Password999',
    );

    expect(find.byType(StudentHomePage), findsNothing);
    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}

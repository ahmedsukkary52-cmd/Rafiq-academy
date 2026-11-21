import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/presentation/pages/student_home_page.dart';

import 'support/demo_accounts.dart';
import 'support/integration_bootstrap.dart';

/// Journey 2 — Student home loads profile-backed UI from Firestore Emulator.
void main() {
  testWidgets('student home shows seeded display name from Firestore', (
    tester,
  ) async {
    await bootstrapIntegrationApp(tester);

    await loginWithDemoAccount(
      tester,
      email: DemoAccounts.student.email,
      password: DemoAccounts.student.password,
    );

    expect(find.byType(StudentHomePage), findsOneWidget);
    // Seeded `users/{demo-student-01}.name` must surface after profile load.
    expect(find.textContaining(DemoAccounts.student.name), findsWidgets);
  });
}

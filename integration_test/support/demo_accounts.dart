/// Emulator-only demo accounts — mirrored from
/// `functions/scripts/seed-emulator-dataset.mjs` (`DEMO_ACCOUNTS`).
///
/// These credentials exist solely inside the local `demo-rafiq-rules`
/// Emulator Suite after `seed:emulator` / `seed-integration-fixture`.
/// They are not Production accounts.
class DemoAccount {
  const DemoAccount({
    required this.uid,
    required this.email,
    required this.password,
    required this.role,
    required this.name,
  });

  final String uid;
  final String email;
  final String password;
  final String role;
  final String name;
}

abstract final class DemoAccounts {
  static const admin = DemoAccount(
    uid: 'demo-admin-01',
    email: 'admin@rafiq.demo',
    password: 'Admin!Rafiq2026a',
    role: 'admin',
    name: 'خالد عبدالرحمن',
  );

  static const parent = DemoAccount(
    uid: 'demo-parent-01',
    email: 'parent@rafiq.demo',
    password: 'Parent!Rafiq2026d',
    role: 'parent',
    name: 'محمد العتيبي',
  );

  static const student = DemoAccount(
    uid: 'demo-student-01',
    email: 'student01@rafiq.demo',
    password: 'Stud01!Rafiq2026e',
    role: 'student',
    name: 'أحمد محمد',
  );

  static const teacher = DemoAccount(
    uid: 'demo-teacher-01',
    email: 'teacher@rafiq.demo',
    password: 'Teach!Rafiq2026c',
    role: 'teacher',
    name: 'عبدالله الحربي',
  );
}

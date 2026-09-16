/// C14 / WA-15 — student operational lifecycle (the fourth status dimension).
///
/// Mirrors `functions/src/lifecycle/studentLifecycleContract.ts`.
///
/// Lifecycle is independent of the other three dimensions and never implies
/// any of them:
///
/// * login/auth  → `users.isActive`
/// * payment     → `paymentAccess/{parentId}.status`
/// * membership  → `halaqat.studentIds`
/// * lifecycle   → `studentProfiles.lifecycle` (this contract)
///
/// Clients read it only. Rules deny every client write, including Admin;
/// transitions go through the `adminSetStudentLifecycle` callable.
enum StudentLifecycle {
  active,
  archived;

  String get wireValue => switch (this) {
    StudentLifecycle.active => StudentLifecycleContract.active,
    StudentLifecycle.archived => StudentLifecycleContract.archived,
  };

  bool get isArchived => this == StudentLifecycle.archived;
}

class StudentLifecycleContract {
  const StudentLifecycleContract._();

  static const String field = 'lifecycle';

  static const String active = 'active';
  static const String archived = 'archived';

  static const Set<String> allowedValues = {active, archived};

  /// Missing or malformed lifecycle reads as [StudentLifecycle.active].
  ///
  /// This is what makes WA-15 migration-free: every student document written
  /// before WA-15 is already correct without being rewritten.
  static StudentLifecycle parse(Object? raw) {
    if (raw is! String) return StudentLifecycle.active;
    return raw.trim() == archived
        ? StudentLifecycle.archived
        : StudentLifecycle.active;
  }
}

/// C14.2 / WA-15 — composes the four independent status dimensions into one
/// display label.
///
/// This is a PRESENTATION composition. Nothing here is ever persisted: there
/// is no combined status field, and the composed label must never be written
/// to `studentSearch` (WA-14 forbids it).
///
/// Pure by construction — no Firebase, no Flutter, no IO — so the whole truth
/// table is unit-testable.
library;

import '../../core/constants/app_constants.dart';
import 'payment_access_contract.dart';
import 'student_lifecycle_contract.dart';

/// The five display labels, in precedence order (first match wins).
enum StudentStatusLabel {
  /// lifecycle = archived — outranks everything else.
  archived,

  /// users.isActive == false. The login dimension, NOT lifecycle.
  loginDisabled,

  /// paymentAccess.status == suspended.
  paymentSuspended,

  /// No halaqa roster contains the student (D21 waiting state).
  awaitingHalaqa,

  /// Every dimension nominal.
  active;

  String get labelAr => switch (this) {
    StudentStatusLabel.archived => 'مؤرشف',
    StudentStatusLabel.loginDisabled => 'معطّل',
    StudentStatusLabel.paymentSuspended => 'موقوف دفع',
    StudentStatusLabel.awaitingHalaqa => 'بانتظار حلقة',
    StudentStatusLabel.active => 'نشط',
  };
}

/// Which dimensions a viewing role is permitted to compose.
///
/// This mirrors the existing Rules rather than relaxing them. A Teacher cannot
/// read `paymentAccess` (`firestore.rules` restricts it to Admin, Supervisor,
/// and the owning Parent), so [canSeePayment] is false for Teacher and the
/// payment tier is skipped instead of guessed.
class StudentStatusVisibility {
  final bool canSeeLifecycle;
  final bool canSeeLogin;
  final bool canSeePayment;
  final bool canSeeMembership;

  const StudentStatusVisibility({
    required this.canSeeLifecycle,
    required this.canSeeLogin,
    required this.canSeePayment,
    required this.canSeeMembership,
  });

  static const StudentStatusVisibility full = StudentStatusVisibility(
    canSeeLifecycle: true,
    canSeeLogin: true,
    canSeePayment: true,
    canSeeMembership: true,
  );

  /// Teacher: operational dimensions only — never payment.
  static const StudentStatusVisibility withoutPayment = StudentStatusVisibility(
    canSeeLifecycle: true,
    canSeeLogin: true,
    canSeePayment: false,
    canSeeMembership: true,
  );

  static const StudentStatusVisibility none = StudentStatusVisibility(
    canSeeLifecycle: false,
    canSeeLogin: false,
    canSeePayment: false,
    canSeeMembership: false,
  );

  /// Student sees no composed badge at all — the existing D21 "waiting for
  /// assignment" copy remains their status surface.
  static StudentStatusVisibility forRole(String? role) =>
      switch (role?.trim()) {
        AppRoles.admin => full,
        AppRoles.supervisor => full,
        AppRoles.parent => full,
        AppRoles.teacher => withoutPayment,
        _ => none,
      };
}

/// The facts required to compose a status.
///
/// [paymentStatus] is nullable on purpose: `null` means "the viewer has no
/// access to this fact", which is a different thing from `ok`.
class StudentStatusFacts {
  final StudentLifecycle lifecycle;

  /// `users.isActive`.
  final bool isActive;

  /// Raw `paymentAccess.status`, or null when the viewer cannot read it.
  final String? paymentStatus;

  /// Roster-derived membership (`halaqat.studentIds`) — the ONLY membership
  /// authority. Never the `studentProfiles.halaqaId` pointer.
  final List<String> halaqaIds;

  /// Display-only pointer, kept for primary-halaqa resolution. It is never
  /// consulted when deciding whether the student has a membership.
  final String? primaryHalaqaPointer;

  const StudentStatusFacts({
    required this.lifecycle,
    required this.isActive,
    this.paymentStatus,
    this.halaqaIds = const [],
    this.primaryHalaqaPointer,
  });

  bool get hasMembership => halaqaIds.isNotEmpty;
}

class StudentStatusComposition {
  const StudentStatusComposition._();

  /// Frozen precedence: archived → login disabled → payment suspended →
  /// awaiting halaqa → active.
  ///
  /// A dimension the viewer cannot see is skipped, never assumed. With
  /// [StudentStatusVisibility.withoutPayment] a suspended student therefore
  /// composes to the next applicable tier rather than leaking the payment
  /// fact through the badge.
  static StudentStatusLabel compose(
    StudentStatusFacts facts, {
    StudentStatusVisibility visibility = StudentStatusVisibility.full,
  }) {
    if (visibility.canSeeLifecycle && facts.lifecycle.isArchived) {
      return StudentStatusLabel.archived;
    }
    if (visibility.canSeeLogin && !facts.isActive) {
      return StudentStatusLabel.loginDisabled;
    }
    if (visibility.canSeePayment &&
        PaymentAccessContract.isSuspended(facts.paymentStatus)) {
      return StudentStatusLabel.paymentSuspended;
    }
    if (visibility.canSeeMembership && !facts.hasMembership) {
      return StudentStatusLabel.awaitingHalaqa;
    }
    return StudentStatusLabel.active;
  }

  /// Role-scoped composition. Returns null for roles that get no badge
  /// (Student, and any unknown role).
  static StudentStatusLabel? composeForRole({
    required String? viewerRole,
    required StudentStatusFacts facts,
  }) {
    final visibility = StudentStatusVisibility.forRole(viewerRole);
    if (!visibility.canSeeLifecycle &&
        !visibility.canSeeLogin &&
        !visibility.canSeePayment &&
        !visibility.canSeeMembership) {
      return null;
    }
    return compose(facts, visibility: visibility);
  }

  /// Display primary halaqa, resolved by the WA-14 rule
  /// (`resolvePrimaryHalaqaId` in `studentSearchProjection.ts`):
  /// the pointer when it is a real membership, otherwise the lowest-sorted
  /// membership, otherwise null.
  ///
  /// A stale pointer therefore degrades the *display* choice only — it can
  /// never create or imply a membership.
  static String? resolvePrimaryHalaqaId({
    required String? pointer,
    required List<String> halaqaIds,
  }) {
    final memberships =
        halaqaIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (memberships.isEmpty) return null;

    final trimmed = pointer?.trim() ?? '';
    if (trimmed.isNotEmpty && memberships.contains(trimmed)) return trimmed;
    return memberships.first;
  }
}

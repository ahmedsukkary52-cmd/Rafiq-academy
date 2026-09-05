import '../../../../core/constants/app_constants.dart';

/// Product contract for completed academy membership (Dual-Halaqa / W8 update).
///
/// Business Owner: **Academy Admission Workflow**.
/// The invariant itself is the contract — no field is definitive SSOT.
///
/// Per-pair membership `(studentId, halaqaId)` is complete when:
/// 1. roster (`halaqat.studentIds`) contains the student
/// 2. `role == student`
/// 3. `users.isActive == true`
///
/// `studentProfiles.halaqaId` is **not** part of membership completeness —
/// it is the primary/default UI pointer only (Student/Parent Phase 1).
///
/// Cap: a student may belong to at most [maxHalaqatPerStudent] halaqat.
class AcademyMembershipInvariant {
  const AcademyMembershipInvariant._();

  static const int maxHalaqatPerStudent = 2;

  /// True when the per-pair membership invariant holds.
  static bool isComplete({
    required bool rosterContainsStudent,
    required String? role,
    required bool? isActive,
  }) {
    return rosterContainsStudent &&
        role == AppRoles.student &&
        isActive == true;
  }

  /// Whether establish/add may set `studentProfiles.halaqaId` to the target.
  ///
  /// - First membership (no other roster memberships) → yes, even if primary
  ///   is empty or an orphan pointer that is not a current membership.
  /// - Add-second / already has other memberships → no (preserve primary).
  static bool shouldSetPrimaryOnEstablish({
    required String? currentPrimary,
    required Iterable<String> membershipHalaqaIdsExcludingTarget,
  }) {
    // [currentPrimary] kept for call-site clarity; orphans are healed when
    // this is the first roster membership.
    final others = membershipHalaqaIdsExcludingTarget
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (others.isEmpty) {
      return true;
    }
    // Preserve an existing primary when adding a second membership.
    final _ = currentPrimary;
    return false;
  }

  /// Primary after an atomic move: remove [sourceHalaqaId], add [targetHalaqaId].
  ///
  /// - If primary was source → becomes target.
  /// - If primary was non-source → unchanged.
  /// - Empty primary → target.
  static String? primaryAfterTransfer({
    required String? currentPrimary,
    required String sourceHalaqaId,
    required String targetHalaqaId,
  }) {
    final primary = currentPrimary?.trim() ?? '';
    final source = sourceHalaqaId.trim();
    final target = targetHalaqaId.trim();
    if (target.isEmpty) return primary.isEmpty ? null : primary;

    if (primary.isEmpty || primary == source) return target;
    return primary;
  }

  /// Clears orphan primary when the student has no remaining roster memberships,
  /// or rebinds primary when it no longer points at a remaining halaqa.
  static String? primaryAfterMembershipsChanged({
    required String? currentPrimary,
    required Iterable<String> remainingHalaqaIds,
  }) {
    final remaining = remainingHalaqaIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (remaining.isEmpty) return null;

    final primary = currentPrimary?.trim() ?? '';
    if (primary.isEmpty) return remaining.first;
    if (remaining.contains(primary)) return primary;
    final sorted = remaining.toList()..sort();
    return sorted.first;
  }
}

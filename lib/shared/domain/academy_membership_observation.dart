import 'academy_membership_invariant.dart';

/// Externally observable membership completeness (W8 Rule 8).
///
/// Academy Admission exposes **only** these two states to consumers.
/// Never invent a third “partial” membership state from individual fields.
enum AcademyMembershipObservation {
  /// Approved invariant holds (workflow contract satisfied).
  established,

  /// Membership not established — including any incomplete / partial storage.
  notEstablished,
}

/// Maps workflow / surface inputs to [AcademyMembershipObservation] (Rule 8).
class AcademyMembershipObservations {
  const AcademyMembershipObservations._();

  /// Full contract observation from the approved invariant members.
  static AcademyMembershipObservation fromInvariant({
    required bool rosterContainsStudent,
    required String? profileHalaqaId,
    required String expectedHalaqaId,
    required String? role,
    required bool? isActive,
  }) {
    final complete = AcademyMembershipInvariant.isComplete(
      rosterContainsStudent: rosterContainsStudent,
      profileHalaqaId: profileHalaqaId,
      expectedHalaqaId: expectedHalaqaId,
      role: role,
      isActive: isActive,
    );
    return complete
        ? AcademyMembershipObservation.established
        : AcademyMembershipObservation.notEstablished;
  }

  /// Student-facing surfaces: profile pointer present ⇒ established for that
  /// surface; otherwise not established. Does **not** consult `isActive` alone.
  static AcademyMembershipObservation forStudentFacing(
    String? profileHalaqaId,
  ) {
    final trimmed = profileHalaqaId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return AcademyMembershipObservation.notEstablished;
    }
    return AcademyMembershipObservation.established;
  }

  /// Day-ops roster membership for one student id (teacher / W2 / W3 / W6 / W7).
  /// On roster ⇒ established for that halaqa's day ops; otherwise not.
  /// Does **not** consult `isActive` alone.
  static AcademyMembershipObservation forDayOpsRosterMember({
    required Iterable<String> halaqaStudentIds,
    required String studentId,
  }) {
    final id = studentId.trim();
    if (id.isEmpty) return AcademyMembershipObservation.notEstablished;
    final onRoster = halaqaStudentIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .contains(id);
    return onRoster
        ? AcademyMembershipObservation.established
        : AcademyMembershipObservation.notEstablished;
  }
}

import 'academy_membership_observation.dart';

/// How W1–W7 **consume** academy membership without local membership logic.
///
/// Rule 7: storage may change later; consumers keep reading these surfaces.
/// They must not invent `isMember` flags or treat `isActive` alone as membership.
///
/// Rule 8: expose only [AcademyMembershipObservation.established] /
/// [AcademyMembershipObservation.notEstablished] — never a partial state.
///
/// Dual-Halaqa: operational membership is per-halaqa via `halaqat.studentIds`.
/// [studentFacingHalaqaId] / profile `halaqaId` is the **primary UI pointer**
/// only (Student/Parent Phase 1 remain primary-only).
///
/// Business Owner remains **Academy Admission Workflow**.
class AcademyMembershipConsumption {
  const AcademyMembershipConsumption._();

  /// Teacher / W2 / W3 / W6 / W7 day-ops roster input: `halaqat.studentIds`.
  ///
  /// Does **not** filter by `users.isActive` (Verified teacher roster behavior).
  static List<String> dayOpsRosterStudentIds(
    Iterable<String> halaqaStudentIds,
  ) {
    return halaqaStudentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  /// Student home / schedule / chat **primary** pointer: `studentProfiles.halaqaId`.
  ///
  /// Not membership SSOT. `null` / empty ⇒ not established for student-facing
  /// primary surfaces (Phase 1 does not show dual schedules).
  static String? studentFacingHalaqaId(String? profileHalaqaId) {
    final trimmed = profileHalaqaId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Login supporting gate only — **not** membership completion by itself.
  static bool loginGateAllows(bool? isActive) => isActive == true;

  /// Rule 8 observation for student UI from the primary pointer surface.
  static AcademyMembershipObservation studentObservation(
    String? profileHalaqaId,
  ) => AcademyMembershipObservations.forStudentFacing(profileHalaqaId);
}

import 'academy_membership_observation.dart';

/// How W1–W7 **consume** academy membership without local membership logic (W8).
///
/// Rule 7: storage may change later; consumers keep reading these surfaces.
/// They must not invent `isMember` flags or treat `isActive` alone as membership.
///
/// Rule 8: expose only [AcademyMembershipObservation.established] /
/// [AcademyMembershipObservation.notEstablished] — never a partial state.
///
/// Business Owner remains **Academy Admission Workflow** — this type only
/// documents / normalizes consumption inputs.
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

  /// Student home / schedule / chat pointer: `studentProfiles.halaqaId`.
  ///
  /// `null` / empty ⇒ [AcademyMembershipObservation.notEstablished] for
  /// student-facing surfaces.
  static String? studentFacingHalaqaId(String? profileHalaqaId) {
    final trimmed = profileHalaqaId?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Login supporting gate only — **not** membership completion by itself.
  static bool loginGateAllows(bool? isActive) => isActive == true;

  /// Rule 8 observation for student UI from the profile pointer surface.
  static AcademyMembershipObservation studentObservation(
    String? profileHalaqaId,
  ) => AcademyMembershipObservations.forStudentFacing(profileHalaqaId);
}

import '../../../../core/constants/app_constants.dart';

/// Product contract for completed academy membership (W8 D-W8-7).
///
/// Business Owner: **Academy Admission Workflow**.
/// The invariant itself is the contract — no field is definitive SSOT.
///
/// Rule 5: membership is only **complete** when all members hold
/// simultaneously, or else **not established**. No intermediate state.
///
/// Rule 7: evaluate members as a set — never treat one field as authority
/// to imply the others.
class AcademyMembershipInvariant {
  const AcademyMembershipInvariant._();

  /// True only when every approved invariant member is satisfied together.
  static bool isComplete({
    required bool rosterContainsStudent,
    required String? profileHalaqaId,
    required String expectedHalaqaId,
    required String? role,
    required bool? isActive,
  }) {
    return rosterContainsStudent &&
        profileHalaqaId == expectedHalaqaId &&
        role == AppRoles.student &&
        isActive == true;
  }
}

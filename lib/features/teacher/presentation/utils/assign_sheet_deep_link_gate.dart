/// Pure gate for W3 Slice 3 assign-sheet deep-link.
///
/// Ensures the existing assign sheet opens **once**, and only when the
/// students roster in [TeacherBloc] belongs to [expectedHalaqaId] — never
/// against a stale `loaded` roster from a previous halaqa.
class AssignSheetDeepLinkGate {
  final String expectedHalaqaId;
  final bool _armed;
  bool _opened = false;

  AssignSheetDeepLinkGate({required this.expectedHalaqaId, required bool armed})
    : _armed = armed;

  bool get isArmed => _armed;
  bool get hasOpened => _opened;

  /// Call on every students-section observation while the page is live.
  ///
  /// Returns `true` exactly once when it is safe to open the sheet.
  bool onStudentsStatus({
    required bool isLoaded,
    required String? studentsHalaqaId,
  }) {
    if (!_armed || _opened) return false;
    if (!isLoaded) return false;
    if (studentsHalaqaId != expectedHalaqaId) return false;
    _opened = true;
    return true;
  }
}

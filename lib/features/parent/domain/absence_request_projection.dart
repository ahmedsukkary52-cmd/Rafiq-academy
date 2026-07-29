import 'entities/parent_entities.dart';

/// Presentation projection helpers for استئذان (W7 Rule 2).
///
/// Labels only — never invents status, sync flags, or attendance meaning.
class AbsenceRequestProjection {
  const AbsenceRequestProjection._();

  static String statusLabel(AbsenceRequestStatus status) => switch (status) {
    AbsenceRequestStatus.pending => 'قيد المراجعة',
    AbsenceRequestStatus.approved => 'مقبول',
    AbsenceRequestStatus.rejected => 'مرفوض',
  };

  /// True when the request document already carries a teacher decision.
  static bool isDecided(AbsenceRequestEntity request) =>
      request.status == AbsenceRequestStatus.approved ||
      request.status == AbsenceRequestStatus.rejected;
}

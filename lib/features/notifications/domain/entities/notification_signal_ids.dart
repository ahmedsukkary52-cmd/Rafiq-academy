/// Deterministic in-app delivery document ids.
///
/// Channel concern — not part of [AcademyEvent] identity. Keeps one inbox card
/// per (observer, academy fact) so corrections replace rather than duplicate.
class NotificationSignalIds {
  const NotificationSignalIds._();

  static String forObserver({
    required String observerId,
    required String eventId,
  }) => '${observerId}_$eventId';
}

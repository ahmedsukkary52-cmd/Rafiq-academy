import 'package:equatable/equatable.dart';

/// Outcome of a committed day-register save.
///
/// The attendance write is the primary operation; the count describes the
/// business events its status transitions produced. [eventsPublished] reports
/// whether those events reached the event sink — it says nothing about which
/// channels, if any, the sink used.
class AttendanceSaveResult extends Equatable {
  final int eventCount;
  final bool eventsPublished;

  const AttendanceSaveResult({
    required this.eventCount,
    required this.eventsPublished,
  });

  /// Saved register whose statuses did not transition.
  const AttendanceSaveResult.noEvents()
    : eventCount = 0,
      eventsPublished = true;

  /// Attendance is stored, but its events could not be handed over.
  bool get hasUnpublishedEvents => eventCount > 0 && !eventsPublished;

  @override
  List<Object?> get props => [eventCount, eventsPublished];
}

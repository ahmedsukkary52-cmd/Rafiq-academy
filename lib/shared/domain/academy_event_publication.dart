import 'package:equatable/equatable.dart';

/// Outcome of handing academy events to [AcademyEventSink] after a successful
/// SSOT write (attendance, assignment, …).
///
/// The business write is primary; [eventsPublished] reports whether events
/// reached the sink — not which handlers/channels ran inside it.
class AcademyEventPublication extends Equatable {
  final int eventCount;
  final bool eventsPublished;

  const AcademyEventPublication({
    required this.eventCount,
    required this.eventsPublished,
  });

  /// Successful write that produced no events.
  const AcademyEventPublication.none() : eventCount = 0, eventsPublished = true;

  /// SSOT is stored, but events could not be handed over.
  bool get hasUnpublishedEvents => eventCount > 0 && !eventsPublished;

  @override
  List<Object?> get props => [eventCount, eventsPublished];
}

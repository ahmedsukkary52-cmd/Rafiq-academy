import 'package:equatable/equatable.dart';

import 'academy_event_sink.dart';

/// Academy-domain outcome of handing facts to [AcademyEventSink] after a
/// successful SSOT write.
///
/// Answers workflow questions without delivery-channel types:
/// - Was the fact published? → [eventsPublished]
/// - Which handlers processed it? → [succeededHandlerNames]
/// - Which handlers failed? → [failedHandlerNames]
///
/// Delivery metrics (inbox opens, FCM receipts, …) must not appear here.
class AcademyEventPublication extends Equatable {
  final int eventCount;
  final bool eventsPublished;

  /// Channel-neutral per-handler outcomes from the fan-out publish.
  final List<AcademyEventHandlerReport> handlerReports;

  const AcademyEventPublication({
    required this.eventCount,
    required this.eventsPublished,
    this.handlerReports = const [],
  });

  /// Successful write that produced no events.
  const AcademyEventPublication.none()
    : eventCount = 0,
      eventsPublished = true,
      handlerReports = const [];

  /// SSOT is stored, but events could not be handed over / all handlers failed.
  bool get hasUnpublishedEvents => eventCount > 0 && !eventsPublished;

  List<String> get succeededHandlerNames => handlerReports
      .where((r) => r.succeeded)
      .map((r) => r.handlerName)
      .toList(growable: false);

  List<String> get failedHandlerNames => handlerReports
      .where((r) => !r.succeeded)
      .map((r) => r.handlerName)
      .toList(growable: false);

  @override
  List<Object?> get props => [eventCount, eventsPublished, handlerReports];
}

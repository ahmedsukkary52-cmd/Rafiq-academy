import 'package:equatable/equatable.dart';

import 'academy_event.dart';

/// Port for projecting [AcademyEvent]s onward.
///
/// Workflow emitters depend on this port only — they must not know which
/// handlers are registered. The [Iterable] order is the publisher's logical
/// fact order and must be preserved for handlers.
abstract class AcademyEventSink {
  /// Delivers [events] in the given order. Returns a per-handler report.
  Future<AcademyEventPublishReport> publish(Iterable<AcademyEvent> events);
}

/// Independent consumer of academy facts.
///
/// Must tolerate duplicate delivery of the same [AcademyEvent.eventId].
/// Must not depend on registration order among handlers.
abstract class AcademyEventHandler {
  /// Stable name for per-handler reporting (not shown to end users).
  String get name;

  Future<void> handle(Iterable<AcademyEvent> events);
}

/// One handler's outcome for a single [AcademyEventSink.publish] call.
class AcademyEventHandlerReport extends Equatable {
  final String handlerName;
  final bool succeeded;
  final Object? error;

  const AcademyEventHandlerReport({
    required this.handlerName,
    required this.succeeded,
    this.error,
  });

  @override
  List<Object?> get props => [handlerName, succeeded, error];
}

/// Aggregated fan-out result. Best-effort: individual handler failures are
/// retained even when other handlers succeed.
class AcademyEventPublishReport extends Equatable {
  final List<AcademyEventHandlerReport> handlers;

  const AcademyEventPublishReport(this.handlers);

  const AcademyEventPublishReport.empty() : handlers = const [];

  /// True when at least one handler succeeded, or there was nothing to run.
  bool get anySucceeded => handlers.isEmpty || handlers.any((h) => h.succeeded);

  /// True when handlers were invoked and every one failed.
  bool get allFailed =>
      handlers.isNotEmpty && handlers.every((h) => !h.succeeded);

  @override
  List<Object?> get props => [handlers];
}

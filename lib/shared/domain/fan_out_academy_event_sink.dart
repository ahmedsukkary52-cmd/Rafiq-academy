import 'academy_event.dart';
import 'academy_event_sink.dart';

/// Fans each publish out to registered [AcademyEventHandler]s independently.
///
/// This is the **sole** [AcademyEventSink] implementation in production DI
/// (H3 / A-H4). Handlers are registered once in [DiModule.academyEventSink].
///
/// - Preserves the publisher's event order for every handler.
/// - Best-effort: one handler failure never stops the rest.
/// - Returns a per-handler [AcademyEventPublishReport].
/// - Throws only when **every** handler fails (so a sole in-app handler still
///   surfaces unpublished warnings for the teacher).
class FanOutAcademyEventSink implements AcademyEventSink {
  final List<AcademyEventHandler> handlers;

  const FanOutAcademyEventSink({required this.handlers});

  @override
  Future<AcademyEventPublishReport> publish(
    Iterable<AcademyEvent> events,
  ) async {
    // Materialize once so every handler sees the same ordered snapshot.
    final pending = List<AcademyEvent>.unmodifiable(events.toList());
    if (pending.isEmpty) return const AcademyEventPublishReport.empty();
    if (handlers.isEmpty) return const AcademyEventPublishReport.empty();

    final reports = <AcademyEventHandlerReport>[];
    for (final handler in handlers) {
      try {
        await handler.handle(pending);
        reports.add(
          AcademyEventHandlerReport(handlerName: handler.name, succeeded: true),
        );
      } catch (e) {
        reports.add(
          AcademyEventHandlerReport(
            handlerName: handler.name,
            succeeded: false,
            error: e,
          ),
        );
      }
    }

    final report = AcademyEventPublishReport(reports);
    if (report.allFailed) {
      final firstError = reports
          .map((r) => r.error)
          .firstWhere((e) => e != null, orElse: () => null);
      if (firstError is Exception) throw firstError;
      throw Exception(firstError?.toString() ?? 'all handlers failed');
    }
    return report;
  }
}

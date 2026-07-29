import 'academy_event.dart';
import 'academy_event_sink.dart';

/// Fans each publish out to registered [AcademyEventHandler]s independently.
///
/// The publisher never sees the handler list — only [AcademyEventSink].
/// One handler's failure does not stop the others; the call fails only if
/// **every** handler fails (so a sole in-app handler still surfaces unpublished
/// warnings for the teacher).
class FanOutAcademyEventSink implements AcademyEventSink {
  final List<AcademyEventHandler> handlers;

  const FanOutAcademyEventSink({required this.handlers});

  @override
  Future<void> publish(Iterable<AcademyEvent> events) async {
    final pending = events.toList();
    if (pending.isEmpty) return;
    if (handlers.isEmpty) return;

    final errors = <Object>[];
    for (final handler in handlers) {
      try {
        await handler.handle(pending);
      } catch (e) {
        errors.add(e);
      }
    }

    if (errors.length == handlers.length) {
      final first = errors.first;
      if (first is Exception) throw first;
      throw Exception(first.toString());
    }
  }
}

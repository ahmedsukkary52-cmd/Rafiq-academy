import 'academy_event.dart';

/// Port for projecting [AcademyEvent]s onward.
///
/// Workflow emitters depend on this port only — they must not know which
/// observers/handlers are registered (observer independence).
abstract class AcademyEventSink {
  Future<void> publish(Iterable<AcademyEvent> events);
}

/// Independent consumer of academy facts.
///
/// Handlers must not assume they are alone. A failure in one handler must not
/// prevent others from running (enforced by the fan-out sink).
abstract class AcademyEventHandler {
  Future<void> handle(Iterable<AcademyEvent> events);
}

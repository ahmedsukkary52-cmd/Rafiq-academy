import 'academy_event.dart';

/// Port for projecting [AcademyEvent]s to delivery channels.
///
/// Attendance workflow depends on this port only — never on a concrete
/// notification / FCM / SMS implementation. W4 registers an in-app sink;
/// additional sinks can be added without changing attendance save.
abstract class AcademyEventSink {
  Future<void> publish(Iterable<AcademyEvent> events);
}

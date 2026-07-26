import 'package:injectable/injectable.dart';

import 'academy_event.dart';

/// Port for projecting [AcademyEvent]s to delivery channels.
///
/// Attendance workflow depends on this port only — never on a concrete
/// notification / FCM / SMS implementation. W4 ships an in-app sink later;
/// additional sinks can be registered without changing attendance save.
abstract class AcademyEventSink {
  Future<void> publish(Iterable<AcademyEvent> events);
}

/// Pre-Slice placeholder: discards events.
///
/// Slice 1 replaces DI registration with the in-app notification sink.
@LazySingleton(as: AcademyEventSink)
class NoOpAcademyEventSink implements AcademyEventSink {
  const NoOpAcademyEventSink();

  @override
  Future<void> publish(Iterable<AcademyEvent> events) async {}
}

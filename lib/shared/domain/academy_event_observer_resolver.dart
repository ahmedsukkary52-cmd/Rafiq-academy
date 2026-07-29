import 'academy_event.dart';

/// Resolves observer specs into concrete user ids.
///
/// Belongs to the observer layer: emitters never call this; delivery may, so
/// it knows **who** to inform without owning eligibility rules.
///
/// Implementations live outside pure domain (they need relationship lookups).
abstract class AcademyEventObserverResolver {
  /// Returns observer user ids keyed by [AcademyEvent.eventId].
  Future<Map<String, List<String>>> resolve(Iterable<AcademyEvent> events);
}

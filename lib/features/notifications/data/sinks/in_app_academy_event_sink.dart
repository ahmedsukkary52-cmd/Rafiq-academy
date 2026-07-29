import 'package:injectable/injectable.dart';

import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/academy_event_observer_resolver.dart';
import '../../../../shared/domain/academy_event_sink.dart';
import '../../domain/services/in_app_academy_signal_composer.dart';
import '../datasources/notifications_remote_datasource.dart';

/// In-app delivery projection of academy facts.
///
/// Responsibilities stay narrow:
/// - ask the **observer layer** who should know
/// - ask the **composer** how to present the fact in-app
/// - write signals
///
/// Does not decide eligibility rules or invent business facts.
@LazySingleton(as: AcademyEventSink)
class InAppAcademyEventSink implements AcademyEventSink {
  final AcademyEventObserverResolver observerResolver;
  final NotificationsRemoteDatasource notificationsDatasource;

  const InAppAcademyEventSink({
    required this.observerResolver,
    required this.notificationsDatasource,
  });

  @override
  Future<void> publish(Iterable<AcademyEvent> events) async {
    final pending = events.toList();
    if (pending.isEmpty) return;

    final observersByEventId = await observerResolver.resolve(pending);

    final signals = InAppAcademySignalComposer.compose(
      events: pending,
      observerIdsByEventId: observersByEventId,
    );

    // No resolved observers is a real state, not an error.
    if (signals.isEmpty) return;

    await notificationsDatasource.upsertSignals(signals);
  }
}

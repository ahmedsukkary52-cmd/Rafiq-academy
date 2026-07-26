import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/academy_event_sink.dart';
import '../../../parent/domain/repositories/parent_repositories.dart';
import '../../domain/services/absence_signal_composer.dart';
import '../datasources/notifications_remote_datasource.dart';

/// First consumer of academy events: turns them into in-app messages.
///
/// This is the only place where the three responsibilities meet — attendance
/// supplies facts, the parent feature supplies relationships, and this feature
/// supplies presentation. Adding FCM/SMS/email later means adding another sink,
/// not touching the attendance workflow.
@LazySingleton(as: AcademyEventSink)
class InAppAcademyEventSink implements AcademyEventSink {
  final ParentRepository parentRepository;
  final NotificationsRemoteDatasource notificationsDatasource;

  const InAppAcademyEventSink({
    required this.parentRepository,
    required this.notificationsDatasource,
  });

  @override
  Future<void> publish(Iterable<AcademyEvent> events) async {
    final pending = events.toList();
    if (pending.isEmpty) return;

    final studentIds = pending.map(AbsenceSignalComposer.studentIdOf).toList();

    final recipients = await parentRepository.getParentIdsByStudentIds(
      studentIds,
    );

    final parentIdsByStudentId = recipients.fold(
      // A lookup failure must not be reported as "delivered".
      (failure) => throw ServerException(failure.message),
      (map) => map,
    );

    final signals = AbsenceSignalComposer.compose(
      events: pending,
      parentIdsByStudentId: parentIdsByStudentId,
    );

    // No linked parent is a real state, not an error.
    if (signals.isEmpty) return;

    await notificationsDatasource.upsertSignals(signals);
  }
}

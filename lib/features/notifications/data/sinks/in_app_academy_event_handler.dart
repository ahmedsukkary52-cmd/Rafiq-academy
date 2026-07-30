import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/academy_event_observer_resolver.dart';
import '../../../../shared/domain/academy_event_sink.dart';
import '../../../../shared/utils/firestore_in_query.dart';
import '../../domain/services/in_app_academy_signal_composer.dart';
import '../datasources/notifications_remote_datasource.dart';

/// In-app delivery handler — one independent observer of the event stream.
///
/// Production DI registers this as the **only** [AcademyEventHandler] today
/// (H3 / A-H4). Name [name] stays `'in_app'` for publish reports.
///
/// Tolerates duplicate delivery via deterministic [NotificationSignal] ids
/// (upsert). Must not assume it is the only handler forever (B-FCM may add more).
@lazySingleton
class InAppAcademyEventHandler implements AcademyEventHandler {
  final AcademyEventObserverResolver observerResolver;
  final NotificationsRemoteDatasource notificationsDatasource;
  final FirebaseFirestore firestore;

  const InAppAcademyEventHandler({
    required this.observerResolver,
    required this.notificationsDatasource,
    required this.firestore,
  });

  @override
  String get name => 'in_app';

  @override
  Future<void> handle(Iterable<AcademyEvent> events) async {
    final pending = events.toList();
    if (pending.isEmpty) return;

    final observersByEventId = await observerResolver.resolve(pending);
    final studentNamesById = await _studentNamesFor(pending);

    final signals = InAppAcademySignalComposer.compose(
      events: pending,
      observerIdsByEventId: observersByEventId,
      studentNamesById: studentNamesById,
    );

    if (signals.isEmpty) return;

    await notificationsDatasource.upsertSignals(signals);
  }

  /// Delivery enrichment — not part of the event payload.
  Future<Map<String, String>> _studentNamesFor(
    List<AcademyEvent> events,
  ) async {
    final ids = events
        .map((e) => e.studentId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    try {
      final names = <String, String>{};
      for (final chunk in FirestoreInQuery.chunkIds(ids)) {
        final snap = await firestore
            .collection(FirestoreCollections.users)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final name = (data['name'] as String?)?.trim() ?? '';
          if (name.isNotEmpty) names[doc.id] = name;
        }
      }
      return names;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}

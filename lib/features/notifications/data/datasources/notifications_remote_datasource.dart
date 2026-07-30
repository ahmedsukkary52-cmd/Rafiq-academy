import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../domain/entities/notification_signal.dart';
import '../models/notification_model.dart';

abstract class NotificationsRemoteDatasource {
  Stream<List<NotificationModel>> watchNotifications({
    required String uid,
    required String role,
  });

  Future<void> markAsRead({
    required String notificationId,
    required String uid,
  });

  Future<void> markAllAsRead({
    required List<String> notificationIds,
    required String uid,
  });

  /// Write in-app messages under caller-supplied deterministic IDs.
  ///
  /// Re-publishing the same signal replaces its content and makes it unread
  /// again, which is what a corrected record must do.
  Future<void> upsertSignals(List<NotificationSignal> signals);
}

@LazySingleton(as: NotificationsRemoteDatasource)
class NotificationsRemoteDatasourceImpl
    implements NotificationsRemoteDatasource {
  final FirebaseFirestore firestore;

  const NotificationsRemoteDatasourceImpl({required this.firestore});

  CollectionReference get _notificationsRef =>
      firestore.collection(FirestoreCollections.notifications);

  @override
  Stream<List<NotificationModel>> watchNotifications({
    required String uid,
    required String role,
  }) {
    // whereIn بتغطي الحالات التلاتة مع بعض في query واحد بسيط:
    // إشعار شخصي ليّا (audience == uid)، إشعار لكل أصحاب دوري
    // (audience == role)، أو إشعار للكل (audience == 'all').
    return _notificationsRef
        .where('audience', whereIn: [uid, role, 'all'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => NotificationModel.fromFirestore(doc, currentUid: uid),
              )
              .toList(),
        );
  }

  @override
  Future<void> markAsRead({
    required String notificationId,
    required String uid,
  }) async {
    try {
      await _notificationsRef.doc(notificationId).update({
        'readBy': FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> markAllAsRead({
    required List<String> notificationIds,
    required String uid,
  }) async {
    try {
      final batch = firestore.batch();
      for (final id in notificationIds) {
        batch.update(_notificationsRef.doc(id), {
          'readBy': FieldValue.arrayUnion([uid]),
        });
      }
      await batch.commit();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> upsertSignals(List<NotificationSignal> signals) async {
    if (signals.isEmpty) return;

    try {
      for (var i = 0; i < signals.length; i += _writeBatchLimit) {
        final end = (i + _writeBatchLimit < signals.length)
            ? i + _writeBatchLimit
            : signals.length;
        final batch = firestore.batch();

        for (final signal in signals.sublist(i, end)) {
          batch.set(_notificationsRef.doc(signal.id), {
            'audience': signal.audience,
            'title': signal.title,
            'body': signal.body,
            'type': signal.type,
            'readBy': <String>[],
            'hasAudioAlert': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        await batch.commit();
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}

/// Firestore allows 500 writes per batch; stay clear of the ceiling.
const int _writeBatchLimit = 400;

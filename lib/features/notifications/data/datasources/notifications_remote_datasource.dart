import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
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
}

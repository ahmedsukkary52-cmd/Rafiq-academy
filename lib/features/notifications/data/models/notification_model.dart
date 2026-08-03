import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.title,
    required super.body,
    required super.type,
    required super.hasAudioAlert,
    required super.createdAt,
    required super.isRead,
    super.channel,
  });

  /// محتاجين [currentUid] هنا عشان نحسب isRead بمقارنته مع مصفوفة
  /// readBy المخزّنة في المستند (راجع شرح المشكلة اللي كانت في
  /// التصميم القديم باستخدام isRead كـ bool واحد على مستوى الإشعار).
  factory NotificationModel.fromFirestore(
    DocumentSnapshot doc, {
    required String currentUid,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final readBy = List<String>.from(data['readBy'] ?? []);

    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      hasAudioAlert: data['hasAudioAlert'] as bool? ?? false,
      // Null while a server timestamp is still pending on the writing client.
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: readBy.contains(currentUid),
      channel: (data['channel'] as String?)?.trim() ?? '',
    );
  }
}

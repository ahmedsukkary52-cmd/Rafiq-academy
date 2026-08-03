import 'package:equatable/equatable.dart';

class NotificationEntity extends Equatable {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool hasAudioAlert;
  final DateTime createdAt;

  /// محسوبة بالنسبة للمستخدم الحالي وقت الجلب (الـ Model هو اللي بيقارن
  /// uid المستخدم مع قائمة readBy المخزّنة)، عشان الـ Entity تفضل بسيطة
  /// ومالهاش علاقة بمين هو "المستخدم الحالي" - بنفس فكرة unreadCount
  /// في ميزة الشات.
  final bool isRead;

  /// Optional ops channel (e.g. [AdminOpsBroadcast.channel]). Empty for
  /// ordinary inbox signals.
  final String channel;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.hasAudioAlert,
    required this.createdAt,
    required this.isRead,
    this.channel = '',
  });

  @override
  List<Object?> get props => [
    id,
    title,
    body,
    type,
    hasAudioAlert,
    createdAt,
    isRead,
    channel,
  ];
}

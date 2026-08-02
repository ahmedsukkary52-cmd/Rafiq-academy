import 'package:equatable/equatable.dart';

/// Latest admin ops broadcast projected for Teacher Home.
///
/// Source today: in-app `notifications` with [NotificationTypes.general]
/// (written by [AdminOpsBroadcast]). Not a separate Firestore collection.
class TeacherAdminAnnouncement extends Equatable {
  final String id;
  final String message;
  final DateTime createdAt;

  const TeacherAdminAnnouncement({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, message, createdAt];
}

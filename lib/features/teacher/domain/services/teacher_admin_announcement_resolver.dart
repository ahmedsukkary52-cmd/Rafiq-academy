import '../../../../core/constants/app_constants.dart';
import '../../../admin/domain/admin_ops_broadcast.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../read_models/teacher_admin_announcement.dart';

/// Projects the latest **admin ops** announcement from an already-watched
/// notification list — **no extra Firestore query**.
///
/// Only docs written via [AdminOpsBroadcast] (`channel` + `type: general`)
/// qualify. Ordinary inbox items with `type: general` are ignored.
class TeacherAdminAnnouncementResolver {
  const TeacherAdminAnnouncementResolver();

  TeacherAdminAnnouncement? resolve(List<NotificationEntity> notifications) {
    final announcements = notifications.where(_isAdminAnnouncement).toList();
    if (announcements.isEmpty) return null;

    announcements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final newest = announcements.first;
    final body = newest.body.trim();
    final title = newest.title.trim();
    final message = body.isNotEmpty ? body : title;
    if (message.isEmpty) return null;

    return TeacherAdminAnnouncement(
      id: newest.id,
      message: message,
      createdAt: newest.createdAt,
    );
  }

  bool _isAdminAnnouncement(NotificationEntity n) {
    if (n.type != NotificationTypes.general) return false;
    return n.channel == AdminOpsBroadcast.channel;
  }
}

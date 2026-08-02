import '../../../../core/constants/app_constants.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../read_models/teacher_admin_announcement.dart';

/// Projects the latest admin announcement from an already-watched notification
/// list — **no extra Firestore query**.
class TeacherAdminAnnouncementResolver {
  const TeacherAdminAnnouncementResolver();

  TeacherAdminAnnouncement? resolve(List<NotificationEntity> notifications) {
    final general = notifications
        .where((n) => n.type == NotificationTypes.general)
        .toList();
    if (general.isEmpty) return null;

    general.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final newest = general.first;
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
}

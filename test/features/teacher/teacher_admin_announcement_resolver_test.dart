import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/admin/domain/admin_ops_broadcast.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/notification_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/services/teacher_admin_announcement_resolver.dart';

void main() {
  const resolver = TeacherAdminAnnouncementResolver();

  NotificationEntity n({
    required String id,
    required String type,
    required String body,
    String title = 'عنوان',
    String channel = '',
    required DateTime at,
  }) {
    return NotificationEntity(
      id: id,
      title: title,
      body: body,
      type: type,
      hasAudioAlert: false,
      createdAt: at,
      isRead: false,
      channel: channel,
    );
  }

  test('returns null when no admin-channel announcements exist', () {
    final result = resolver.resolve([
      n(
        id: '1',
        type: NotificationTypes.general,
        body: 'ترحيب بالبذرة — ليس إعلاناً إدارياً',
        at: DateTime(2024, 1, 1),
      ),
      n(
        id: '2',
        type: NotificationTypes.assignment,
        body: 'واجب',
        at: DateTime(2024, 1, 2),
      ),
    ]);
    expect(result, isNull);
  });

  test('picks newest AdminOpsBroadcast announcement body', () {
    final result = resolver.resolve([
      n(
        id: 'old',
        type: NotificationTypes.general,
        channel: AdminOpsBroadcast.channel,
        body: 'قديم',
        at: DateTime(2024, 1, 1),
      ),
      n(
        id: 'new',
        type: NotificationTypes.general,
        channel: AdminOpsBroadcast.channel,
        body: 'تذكير: موعد التقييمات',
        at: DateTime(2024, 6, 1),
      ),
      n(
        id: 'noise',
        type: NotificationTypes.general,
        body: 'يجب تجاهله',
        at: DateTime(2024, 7, 1),
      ),
    ]);
    expect(result, isNotNull);
    expect(result!.id, 'new');
    expect(result.message, 'تذكير: موعد التقييمات');
  });

  test('falls back to title when body is empty', () {
    final result = resolver.resolve([
      n(
        id: 't',
        type: NotificationTypes.general,
        channel: AdminOpsBroadcast.channel,
        body: '  ',
        title: 'إعلان مهم',
        at: DateTime(2024, 6, 1),
      ),
    ]);
    expect(result?.message, 'إعلان مهم');
  });
}

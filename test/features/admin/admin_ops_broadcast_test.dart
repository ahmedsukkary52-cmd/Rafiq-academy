import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/admin/domain/admin_ops_broadcast.dart';

void main() {
  group('AdminOpsBroadcast (H3 / A-H15 quarantine)', () {
    test('notification fields match pre-H3 write shape', () {
      final fields = AdminOpsBroadcast.notificationFields(
        title: 'عنوان',
        body: 'محتوى',
        targetRole: 'all',
      );

      expect(fields, {
        'audience': 'all',
        'title': 'عنوان',
        'body': 'محتوى',
        'type': NotificationTypes.general,
        'readBy': <String>[],
        'hasAudioAlert': false,
      });
    });
  });
}

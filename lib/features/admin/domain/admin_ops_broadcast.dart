import '../../../core/constants/app_constants.dart';

/// Admin **ops** broadcast — quarantined outside the academy-event pipeline (H3 / A-H15).
///
/// This is **not** an [AcademyEvent], does **not** go through [AcademyEventSink],
/// and must not be confused with W4/W5 in-app signal upserts.
///
/// Write shape: Firestore `notifications.add` with role/`all` [audienceField].
/// Product UI for broadcast is currently absent (admin home = admit only).
/// H6 / A-H9: non-admit AdminBloc writers remain quarantined (no UI).
class AdminOpsBroadcast {
  const AdminOpsBroadcast._();

  /// Stable channel label written on every admin broadcast doc so Home can
  /// distinguish ops announcements from other `general` inbox noise.
  static const String channel = 'admin_ops_broadcast';

  static const String channelField = 'channel';
  static const String audienceField = 'audience';
  static const String titleField = 'title';
  static const String bodyField = 'body';
  static const String typeField = 'type';
  static const String readByField = 'readBy';
  static const String hasAudioAlertField = 'hasAudioAlert';
  static const String createdAtField = 'createdAt';

  /// Fields written to `notifications` (excluding server timestamp).
  ///
  /// [targetRole] is `'all'` or a role name (e.g. `student`) — same as before H3.
  static Map<String, Object?> notificationFields({
    required String title,
    required String body,
    required String targetRole,
  }) {
    return {
      channelField: channel,
      audienceField: targetRole,
      titleField: title,
      bodyField: body,
      typeField: NotificationTypes.general,
      readByField: <String>[],
      hasAudioAlertField: false,
    };
  }
}

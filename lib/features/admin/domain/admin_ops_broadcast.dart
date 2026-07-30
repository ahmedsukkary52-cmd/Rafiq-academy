import '../../../core/constants/app_constants.dart';

/// Admin **ops** broadcast — quarantined outside the academy-event pipeline (H3 / A-H15).
///
/// This is **not** an [AcademyEvent], does **not** go through [AcademyEventSink],
/// and must not be confused with W4/W5 in-app signal upserts.
///
/// Write shape: Firestore `notifications.add` with role/`all` [audienceField].
/// Product UI for broadcast is currently absent (admin home = admit only).
/// Full removal may follow H6 (A-H9) if product agrees.
class AdminOpsBroadcast {
  const AdminOpsBroadcast._();

  /// Stable channel label for docs / observability — not stored on the doc.
  static const String channel = 'admin_ops_broadcast';

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
      audienceField: targetRole,
      titleField: title,
      bodyField: body,
      typeField: NotificationTypes.general,
      readByField: <String>[],
      hasAudioAlertField: false,
    };
  }
}

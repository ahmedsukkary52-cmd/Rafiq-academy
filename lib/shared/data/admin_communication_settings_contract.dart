/// Firestore contract for admin communication policy (`academySettings/communication`).
class AdminCommunicationSettingsContract {
  const AdminCommunicationSettingsContract._();

  static const String docPath = 'academySettings/communication';

  static const String autoReplyOutsideHoursField = 'autoReplyOutsideHours';
  static const String broadcastsNeedApprovalField = 'broadcastsNeedApproval';
  static const String maxFileSizeMbField = 'maxFileSizeMb';
  static const String allowedFileTypesField = 'allowedFileTypes';
  static const String conversationRetentionDaysField = 'conversationRetentionDays';
  static const String updatedAtField = 'updatedAt';

  static Map<String, Object?> defaults() {
    return {
      autoReplyOutsideHoursField: true,
      broadcastsNeedApprovalField: true,
      maxFileSizeMbField: 25,
      allowedFileTypesField: 'PDF, JPG, MP3, MP4',
      conversationRetentionDaysField: 365,
    };
  }
}

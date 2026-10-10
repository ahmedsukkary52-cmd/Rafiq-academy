import 'package:equatable/equatable.dart';

class CommunicationSettingsEntity extends Equatable {
  final bool autoReplyOutsideHours;
  final bool broadcastsNeedApproval;
  final int maxFileSizeMb;
  final String allowedFileTypes;
  final int conversationRetentionDays;

  const CommunicationSettingsEntity({
    required this.autoReplyOutsideHours,
    required this.broadcastsNeedApproval,
    required this.maxFileSizeMb,
    required this.allowedFileTypes,
    required this.conversationRetentionDays,
  });

  factory CommunicationSettingsEntity.defaults() {
    return const CommunicationSettingsEntity(
      autoReplyOutsideHours: true,
      broadcastsNeedApproval: true,
      maxFileSizeMb: 25,
      allowedFileTypes: 'PDF, JPG, MP3, MP4',
      conversationRetentionDays: 365,
    );
  }

  @override
  List<Object?> get props => [
    autoReplyOutsideHours,
    broadcastsNeedApproval,
    maxFileSizeMb,
    allowedFileTypes,
    conversationRetentionDays,
  ];
}

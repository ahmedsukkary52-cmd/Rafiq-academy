import '../../awards/data/award_payload_json.dart';
import '../../awards/domain/award_submission_id.dart';
import '../domain/admin_grant_reward_params.dart';

/// Saved form of an admin `grantAward` request.
class AdminGrantRewardPayloadCodec
    extends AwardPayloadCodec<AdminGrantRewardParams> {
  const AdminGrantRewardPayloadCodec();

  @override
  String idOf(AdminGrantRewardParams payload) => payload.awardId;

  @override
  Map<String, Object?> encode(AdminGrantRewardParams payload) => {
    'awardId': payload.awardId,
    'targetKind': payload.targetKind.name,
    'targetId': payload.targetId,
    'type': payload.type,
    'title': payload.title,
    'description': payload.description,
    'grantedBy': payload.grantedBy,
    'halaqaId': payload.halaqaId,
    'halaqaName': payload.halaqaName,
    'studentName': payload.studentName,
    'recipientStudentIds': payload.recipientStudentIds,
  };

  /// A record without its resolved halaqa and recipients cannot be resent
  /// exactly, so it is rejected and must be abandoned.
  @override
  AdminGrantRewardParams decode(Map<String, Object?> json) {
    final halaqaId = json.requireString('halaqaId');
    final recipients = json.requireStringList('recipientStudentIds');
    if (halaqaId.isEmpty || recipients.isEmpty) {
      throw const FormatException('award payload: recipients');
    }
    return AdminGrantRewardParams(
      awardId: json.requireString('awardId'),
      targetKind: json.requireEnum('targetKind', AdminRewardTargetKind.values),
      targetId: json.requireString('targetId'),
      type: json.requireString('type'),
      title: json.requireString('title'),
      description: json.optionalString('description'),
      grantedBy: json.requireString('grantedBy'),
      halaqaId: halaqaId,
      halaqaName: json.optionalString('halaqaName'),
      studentName: json.optionalString('studentName'),
      recipientStudentIds: recipients,
    );
  }
}

import '../../awards/data/award_payload_json.dart';
import '../../awards/domain/award_submission_id.dart';
import '../domain/entities/achievement_issue_entity.dart';

/// Saved form of a staff `issueAchievement` request.
class AchievementIssuePayloadCodec
    extends AwardPayloadCodec<AchievementIssueEntity> {
  const AchievementIssuePayloadCodec();

  @override
  String idOf(AchievementIssueEntity payload) => payload.achievementId;

  @override
  Map<String, Object?> encode(AchievementIssueEntity payload) => {
    'achievementId': payload.achievementId,
    'studentId': payload.studentId,
    'type': payload.type,
    'title': payload.title,
    'issuedBy': payload.issuedBy,
    'halaqaId': payload.halaqaId,
  };

  @override
  AchievementIssueEntity decode(Map<String, Object?> json) =>
      AchievementIssueEntity(
        achievementId: json.requireString('achievementId'),
        studentId: json.requireString('studentId'),
        type: json.requireString('type'),
        title: json.requireString('title'),
        issuedBy: json.requireString('issuedBy'),
        halaqaId: json.requireString('halaqaId'),
      );
}

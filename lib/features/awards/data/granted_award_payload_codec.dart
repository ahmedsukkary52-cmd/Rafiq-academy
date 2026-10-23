import '../domain/award_submission_id.dart';
import '../domain/entities/award_entities.dart';
import 'award_payload_json.dart';

/// Saved form of a teacher `grantAward` request.
///
/// The picked image's local path and any uploaded storage path are not
/// saved: a path does not prove the file content is unchanged. Only
/// `imageAttached` is kept, so a restored image request is reported as not
/// restorable instead of being resent with a different or missing image.
class GrantedAwardPayloadCodec extends AwardPayloadCodec<GrantedAwardEntity> {
  const GrantedAwardPayloadCodec();

  static const String imageAttachedField = 'imageAttached';

  @override
  String idOf(GrantedAwardEntity payload) => payload.id;

  @override
  Map<String, Object?> encode(GrantedAwardEntity payload) => {
    'id': payload.id,
    'studentId': payload.studentId,
    'studentName': payload.studentName,
    'studentImageUrl': payload.studentImageUrl,
    'type': payload.type.name,
    'note': payload.note,
    'title': payload.title,
    'description': payload.description,
    'grantedBy': payload.grantedBy,
    'halaqaId': payload.halaqaId,
    'halaqaName': payload.halaqaName,
    'halaqaIds': payload.halaqaIds,
    'halaqaNames': payload.halaqaNames,
    'grantedAtUs': payload.grantedAt.microsecondsSinceEpoch,
    'recipientStudentIds': payload.recipientStudentIds,
    'recipientCount': payload.recipientCount,
    imageAttachedField: _hasImage(payload),
  };

  @override
  GrantedAwardEntity decode(Map<String, Object?> json) {
    json.requireBool(imageAttachedField);
    return GrantedAwardEntity(
      id: json.requireString('id'),
      studentId: json.requireString('studentId'),
      studentName: json.requireString('studentName'),
      studentImageUrl: json.optionalString('studentImageUrl'),
      type: json.requireEnum('type', AwardType.values),
      note: json.optionalString('note'),
      title: json.requireString('title'),
      description: json.optionalString('description'),
      grantedBy: json.requireString('grantedBy'),
      halaqaId: json.requireString('halaqaId'),
      halaqaName: json.optionalString('halaqaName'),
      halaqaIds: json.requireStringList('halaqaIds'),
      halaqaNames: json.requireStringList('halaqaNames'),
      grantedAt: DateTime.fromMicrosecondsSinceEpoch(
        json.requireInt('grantedAtUs'),
      ),
      recipientStudentIds: json.requireStringList('recipientStudentIds'),
      recipientCount: json.requireInt('recipientCount'),
    );
  }

  @override
  AwardRecoveryProblem? problemOf(Map<String, Object?> json) =>
      json[imageAttachedField] == true
      ? AwardRecoveryProblem.imageNotRestorable
      : null;

  static bool _hasImage(GrantedAwardEntity payload) => [
    payload.localImagePath,
    payload.imageUrl,
    payload.imageStoragePath,
  ].any((v) => (v ?? '').trim().isNotEmpty);
}

import '../../../shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';
import '../domain/entities/halaqa_activity_entity.dart';

/// Maps domain activity entities ↔ approved presentation UI models.
class HalaqaActivityUiMapper {
  const HalaqaActivityUiMapper._();

  static HalaqaActivityUi toUi(HalaqaActivityEntity entity) {
    return HalaqaActivityUi(
      id: entity.id,
      halaqaId: entity.halaqaId,
      prompt: entity.prompt,
      createdAt: entity.createdAt,
      deadline: entity.deadline,
      allowedResponseTypes: entity.allowedResponseTypes
          .map(_toUiType)
          .toSet(),
      sharedToPosts: entity.alsoShareAsPost,
      teacherName: entity.teacherName,
      thread: entity.thread.map(_toUiMessage).toList(growable: false),
      listedResponseCount: entity.responseCount,
      respondentStudentIds: entity.respondentStudentIds,
    );
  }

  static ActivityResponseTypeUi _toUiType(HalaqaActivityResponseType type) =>
      switch (type) {
        HalaqaActivityResponseType.text => ActivityResponseTypeUi.text,
        HalaqaActivityResponseType.image => ActivityResponseTypeUi.image,
        HalaqaActivityResponseType.audio => ActivityResponseTypeUi.audio,
      };

  static HalaqaActivityResponseType toDomainType(ActivityResponseTypeUi type) =>
      switch (type) {
        ActivityResponseTypeUi.text => HalaqaActivityResponseType.text,
        ActivityResponseTypeUi.image => HalaqaActivityResponseType.image,
        ActivityResponseTypeUi.audio => HalaqaActivityResponseType.audio,
      };

  static ActivityThreadMessageUi _toUiMessage(
    HalaqaActivityResponseEntity response,
  ) {
    return ActivityThreadMessageUi(
      id: response.id,
      authorId: response.studentId,
      authorName: response.studentName,
      createdAt: response.createdAt,
      isTeacher: false,
      text: response.text,
      hasImage: response.hasImage,
      hasAudio: response.hasAudio,
      imageLabel: response.imageLabel,
      audioLabel: response.audioLabel,
    );
  }
}

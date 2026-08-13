import 'dart:io';

import '../../domain/entities/halaqa_activity_entity.dart';
import '../../../../shared/domain/academy_event.dart';

abstract class HalaqaActivityRemoteDatasource {
  Future<({String activityId, List<AcademyEvent> events})> publishActivity({
    required String halaqaId,
    required String teacherId,
    required String teacherName,
    required String prompt,
    required Set<HalaqaActivityResponseType> allowedResponseTypes,
    DateTime? deadline,
    bool alsoShareAsPost = false,
  });

  Future<void> attachMirroredPostId({
    required String activityId,
    required String postId,
  });

  Future<List<HalaqaActivityEntity>> listActivitiesForHalaqa(String halaqaId);

  Future<HalaqaActivityEntity> getActivity({
    required String halaqaId,
    required String activityId,
    bool includeThread = true,
  });

  Future<HalaqaActivityResponseEntity> submitResponse({
    required String activityId,
    required String halaqaId,
    required String studentId,
    required String studentName,
    String? text,
    File? imageFile,
    File? audioFile,
  });
}

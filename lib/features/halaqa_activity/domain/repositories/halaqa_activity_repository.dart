import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../entities/halaqa_activity_entity.dart';

abstract class HalaqaActivityRepository {
  Future<Either<Failure, AcademyEventPublication>> publishActivity({
    required String halaqaId,
    required String teacherId,
    required String teacherName,
    required String prompt,
    required Set<HalaqaActivityResponseType> allowedResponseTypes,
    DateTime? deadline,
    bool alsoShareAsPost = false,
  });

  Future<Either<Failure, List<HalaqaActivityEntity>>> listActivitiesForHalaqa(
    String halaqaId,
  );

  Future<Either<Failure, HalaqaActivityEntity>> getActivity({
    required String halaqaId,
    required String activityId,
    bool includeThread = true,
  });

  Future<Either<Failure, HalaqaActivityResponseEntity>> submitResponse({
    required String activityId,
    required String halaqaId,
    required String studentId,
    required String studentName,
    String? text,
    File? imageFile,
    File? audioFile,
  });
}

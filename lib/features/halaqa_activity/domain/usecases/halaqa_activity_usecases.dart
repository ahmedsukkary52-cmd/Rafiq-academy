import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../entities/halaqa_activity_entity.dart';
import '../repositories/halaqa_activity_repository.dart';

@lazySingleton
class PublishHalaqaActivityUseCase
    extends UseCase<AcademyEventPublication, PublishHalaqaActivityParams> {
  final HalaqaActivityRepository repository;

  PublishHalaqaActivityUseCase(this.repository);

  @override
  Future<Either<Failure, AcademyEventPublication>> call(
    PublishHalaqaActivityParams params,
  ) {
    final prompt = params.prompt.trim();
    if (prompt.isEmpty) {
      return Future.value(const Left(ValidationFailure('اكتب نص المهمة أولاً')));
    }
    if (params.allowedResponseTypes.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('اختر نوع رد واحد على الأقل')),
      );
    }
    return repository.publishActivity(
      halaqaId: params.halaqaId,
      teacherId: params.teacherId,
      teacherName: params.teacherName,
      prompt: prompt,
      allowedResponseTypes: params.allowedResponseTypes,
      deadline: params.deadline,
      alsoShareAsPost: params.alsoShareAsPost,
    );
  }
}

@lazySingleton
class ListHalaqaActivitiesUseCase
    extends UseCase<List<HalaqaActivityEntity>, HalaqaActivityHalaqaParams> {
  final HalaqaActivityRepository repository;

  ListHalaqaActivitiesUseCase(this.repository);

  @override
  Future<Either<Failure, List<HalaqaActivityEntity>>> call(
    HalaqaActivityHalaqaParams params,
  ) =>
      repository.listActivitiesForHalaqa(params.halaqaId);
}

@lazySingleton
class GetHalaqaActivityUseCase
    extends UseCase<HalaqaActivityEntity, GetHalaqaActivityParams> {
  final HalaqaActivityRepository repository;

  GetHalaqaActivityUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaActivityEntity>> call(
    GetHalaqaActivityParams params,
  ) =>
      repository.getActivity(
        halaqaId: params.halaqaId,
        activityId: params.activityId,
        includeThread: params.includeThread,
      );
}

@lazySingleton
class SubmitHalaqaActivityResponseUseCase
    extends
        UseCase<HalaqaActivityResponseEntity, SubmitHalaqaActivityResponseParams> {
  final HalaqaActivityRepository repository;

  SubmitHalaqaActivityResponseUseCase(this.repository);

  @override
  Future<Either<Failure, HalaqaActivityResponseEntity>> call(
    SubmitHalaqaActivityResponseParams params,
  ) {
    final text = params.text?.trim();
    final hasText = text != null && text.isNotEmpty;
    final hasImage = params.imageFile != null;
    final hasAudio = params.audioFile != null;
    if (!hasText && !hasImage && !hasAudio) {
      return Future.value(
        const Left(ValidationFailure('أضف نصاً أو مرفقاً قبل الإرسال')),
      );
    }
    return repository.submitResponse(
      activityId: params.activityId,
      halaqaId: params.halaqaId,
      studentId: params.studentId,
      studentName: params.studentName,
      text: hasText ? text : null,
      imageFile: params.imageFile,
      audioFile: params.audioFile,
    );
  }
}

class PublishHalaqaActivityParams extends Equatable {
  final String halaqaId;
  final String teacherId;
  final String teacherName;
  final String prompt;
  final Set<HalaqaActivityResponseType> allowedResponseTypes;
  final DateTime? deadline;
  final bool alsoShareAsPost;

  const PublishHalaqaActivityParams({
    required this.halaqaId,
    required this.teacherId,
    required this.teacherName,
    required this.prompt,
    required this.allowedResponseTypes,
    this.deadline,
    this.alsoShareAsPost = false,
  });

  @override
  List<Object?> get props => [
    halaqaId,
    teacherId,
    teacherName,
    prompt,
    allowedResponseTypes,
    deadline,
    alsoShareAsPost,
  ];
}

class HalaqaActivityHalaqaParams extends Equatable {
  final String halaqaId;

  const HalaqaActivityHalaqaParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

class GetHalaqaActivityParams extends Equatable {
  final String halaqaId;
  final String activityId;
  final bool includeThread;

  const GetHalaqaActivityParams({
    required this.halaqaId,
    required this.activityId,
    this.includeThread = true,
  });

  @override
  List<Object?> get props => [halaqaId, activityId, includeThread];
}

class SubmitHalaqaActivityResponseParams extends Equatable {
  final String activityId;
  final String halaqaId;
  final String studentId;
  final String studentName;
  final String? text;
  final File? imageFile;
  final File? audioFile;

  const SubmitHalaqaActivityResponseParams({
    required this.activityId,
    required this.halaqaId,
    required this.studentId,
    required this.studentName,
    this.text,
    this.imageFile,
    this.audioFile,
  });

  @override
  List<Object?> get props => [
    activityId,
    halaqaId,
    studentId,
    studentName,
    text,
    imageFile?.path,
    audioFile?.path,
  ];
}

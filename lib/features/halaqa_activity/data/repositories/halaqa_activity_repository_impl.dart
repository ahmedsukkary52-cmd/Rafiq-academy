import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/academy_event_publication.dart';
import '../../../../shared/domain/academy_event_sink.dart';
import '../../../post/domain/entities/posts_entities.dart';
import '../../../post/domain/repositories/posts_repository.dart';
import '../../domain/entities/halaqa_activity_entity.dart';
import '../../domain/repositories/halaqa_activity_repository.dart';
import '../datasources/halaqa_activity_remote_datasource.dart';

@LazySingleton(as: HalaqaActivityRepository)
class HalaqaActivityRepositoryImpl implements HalaqaActivityRepository {
  final HalaqaActivityRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;
  final AcademyEventSink eventSink;
  final PostsRepository postsRepository;

  const HalaqaActivityRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
    required this.eventSink,
    required this.postsRepository,
  });

  Future<AcademyEventPublication> _publishAfterCommit(
    List<AcademyEvent> events,
  ) async {
    if (events.isEmpty) return const AcademyEventPublication.none();
    try {
      final report = await eventSink.publish(events);
      return AcademyEventPublication(
        eventCount: events.length,
        eventsPublished: report.anySucceeded,
        handlerReports: report.handlers,
      );
    } catch (e) {
      return AcademyEventPublication(
        eventCount: events.length,
        eventsPublished: false,
        handlerReports: [
          AcademyEventHandlerReport(
            handlerName: 'publish',
            succeeded: false,
            error: e,
          ),
        ],
      );
    }
  }

  @override
  Future<Either<Failure, AcademyEventPublication>> publishActivity({
    required String halaqaId,
    required String teacherId,
    required String teacherName,
    required String prompt,
    required Set<HalaqaActivityResponseType> allowedResponseTypes,
    DateTime? deadline,
    bool alsoShareAsPost = false,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final result = await remoteDatasource.publishActivity(
        halaqaId: halaqaId,
        teacherId: teacherId,
        teacherName: teacherName,
        prompt: prompt,
        allowedResponseTypes: allowedResponseTypes,
        deadline: deadline,
        alsoShareAsPost: alsoShareAsPost,
      );

      if (alsoShareAsPost) {
        // Mirror only — Activity remains SSOT. Failure does not roll back.
        try {
          await postsRepository.createPost(
            authorId: teacherId,
            authorName: teacherName,
            content: prompt,
            halaqaId: halaqaId,
            audience: PostAudience.specificHalaqa,
            attachmentFiles: const [],
            attachmentTypes: const [],
          );
        } catch (_) {
          // Keep activity; UI already published.
        }
      }

      return Right(await _publishAfterCommit(result.events));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<HalaqaActivityEntity>>> listActivitiesForHalaqa(
    String halaqaId,
  ) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await remoteDatasource.listActivitiesForHalaqa(halaqaId));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, HalaqaActivityEntity>> getActivity({
    required String halaqaId,
    required String activityId,
    bool includeThread = true,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.getActivity(
          halaqaId: halaqaId,
          activityId: activityId,
          includeThread: includeThread,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, HalaqaActivityResponseEntity>> submitResponse({
    required String activityId,
    required String halaqaId,
    required String studentId,
    required String studentName,
    String? text,
    File? imageFile,
    File? audioFile,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(
        await remoteDatasource.submitResponse(
          activityId: activityId,
          halaqaId: halaqaId,
          studentId: studentId,
          studentName: studentName,
          text: text,
          imageFile: imageFile,
          audioFile: audioFile,
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}

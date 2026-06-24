import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/posts_entities.dart';
import '../../domain/repositories/posts_repository.dart';
import '../datasources/posts_remote_datasource.dart';

@LazySingleton(as: PostsRepository)
class PostsRepositoryImpl implements PostsRepository {
  final PostsRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const PostsRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Stream<Either<Failure, List<PostEntity>>> watchPosts({
    required String halaqaId,
  }) {
    return remoteDatasource
        .watchPosts(halaqaId: halaqaId)
        .map<Either<Failure, List<PostEntity>>>((list) => Right(list))
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Stream<Either<Failure, List<CommentEntity>>> watchComments(String postId) {
    return remoteDatasource
        .watchComments(postId)
        .map<Either<Failure, List<CommentEntity>>>((list) => Right(list))
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Future<Either<Failure, Unit>> createPost({
    required String authorId,
    required String authorName,
    required String content,
    required String? halaqaId,
    required PostAudience audience,
    List<File> attachmentFiles = const [],
    List<AttachmentType> attachmentTypes = const [],
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.createPost(
        authorId: authorId,
        authorName: authorName,
        content: content,
        halaqaId: halaqaId,
        audience: audience,
        attachmentFiles: attachmentFiles,
        attachmentTypes: attachmentTypes,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleLike({
    required String postId,
    required String uid,
    required bool isCurrentlyLiked,
  }) async {
    // الإعجاب عملية خفيفة جداً - منتحققش من الاتصال عشان
    // متوقفش المستخدم بـ loading، والـ Firestore SDK بيعمل cache محلي
    // ويرسل التحديث لما يرجع الاتصال تلقائياً.
    try {
      await remoteDatasource.toggleLike(
        postId: postId,
        uid: uid,
        isCurrentlyLiked: isCurrentlyLiked,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.addComment(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        content: content,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> togglePin({
    required String postId,
    required bool isPinned,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.togglePin(postId: postId, isPinned: isPinned);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> deletePost(String postId) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.deletePost(postId);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}

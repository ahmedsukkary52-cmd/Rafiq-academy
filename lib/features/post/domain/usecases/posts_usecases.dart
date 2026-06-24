import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/posts_entities.dart';
import '../repositories/posts_repository.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WatchPostsUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class WatchPostsUseCase
    extends StreamUseCase<List<PostEntity>, WatchPostsParams> {
  final PostsRepository repository;

  WatchPostsUseCase(this.repository);

  @override
  Stream<Either<Failure, List<PostEntity>>> call(WatchPostsParams params) =>
      repository.watchPosts(halaqaId: params.halaqaId);
}

// ══════════════════════════════════════════════════════════════════════════════
// WatchCommentsUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class WatchCommentsUseCase
    extends StreamUseCase<List<CommentEntity>, PostIdParams> {
  final PostsRepository repository;

  WatchCommentsUseCase(this.repository);

  @override
  Stream<Either<Failure, List<CommentEntity>>> call(PostIdParams params) =>
      repository.watchComments(params.postId);
}

// ══════════════════════════════════════════════════════════════════════════════
// CreatePostUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class CreatePostUseCase extends UseCase<Unit, CreatePostParams> {
  final PostsRepository repository;

  CreatePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CreatePostParams params) {
    if (params.content.trim().isEmpty && params.attachmentFiles.isEmpty) {
      return Future.value(
        const Left(ValidationFailure('لا يمكن نشر منشور فارغ')),
      );
    }

    return repository.createPost(
      authorId: params.authorId,
      authorName: params.authorName,
      content: params.content.trim(),
      halaqaId: params.halaqaId,
      audience: params.audience,
      attachmentFiles: params.attachmentFiles,
      attachmentTypes: params.attachmentTypes,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ToggleLikeUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class ToggleLikeUseCase extends UseCase<Unit, ToggleLikeParams> {
  final PostsRepository repository;

  ToggleLikeUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ToggleLikeParams params) =>
      repository.toggleLike(
        postId: params.postId,
        uid: params.uid,
        isCurrentlyLiked: params.isCurrentlyLiked,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// AddCommentUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class AddCommentUseCase extends UseCase<Unit, AddCommentParams> {
  final PostsRepository repository;

  AddCommentUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(AddCommentParams params) {
    if (params.content.trim().isEmpty) {
      return Future.value(
        const Left(ValidationFailure('لا يمكن إضافة تعليق فارغ')),
      );
    }

    return repository.addComment(
      postId: params.postId,
      authorId: params.authorId,
      authorName: params.authorName,
      content: params.content.trim(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TogglePinUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class TogglePinUseCase extends UseCase<Unit, TogglePinParams> {
  final PostsRepository repository;

  TogglePinUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(TogglePinParams params) =>
      repository.togglePin(postId: params.postId, isPinned: params.isPinned);
}

// ══════════════════════════════════════════════════════════════════════════════
// DeletePostUseCase
// ══════════════════════════════════════════════════════════════════════════════

@lazySingleton
class DeletePostUseCase extends UseCase<Unit, PostIdParams> {
  final PostsRepository repository;

  DeletePostUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(PostIdParams params) =>
      repository.deletePost(params.postId);
}

// ══════════════════════════════════════════════════════════════════════════════
// Params
// ══════════════════════════════════════════════════════════════════════════════

class WatchPostsParams extends Equatable {
  final String halaqaId;

  const WatchPostsParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

class PostIdParams extends Equatable {
  final String postId;

  const PostIdParams(this.postId);

  @override
  List<Object?> get props => [postId];
}

class CreatePostParams extends Equatable {
  final String authorId;
  final String authorName;
  final String content;
  final String? halaqaId;
  final PostAudience audience;
  final List<File> attachmentFiles;
  final List<AttachmentType> attachmentTypes;

  const CreatePostParams({
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.halaqaId,
    required this.audience,
    this.attachmentFiles = const [],
    this.attachmentTypes = const [],
  });

  @override
  List<Object?> get props => [
    authorId,
    authorName,
    content,
    halaqaId,
    audience,
  ];
}

class ToggleLikeParams extends Equatable {
  final String postId;
  final String uid;
  final bool isCurrentlyLiked;

  const ToggleLikeParams({
    required this.postId,
    required this.uid,
    required this.isCurrentlyLiked,
  });

  @override
  List<Object?> get props => [postId, uid, isCurrentlyLiked];
}

class AddCommentParams extends Equatable {
  final String postId;
  final String authorId;
  final String authorName;
  final String content;

  const AddCommentParams({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
  });

  @override
  List<Object?> get props => [postId, authorId, authorName, content];
}

class TogglePinParams extends Equatable {
  final String postId;
  final bool isPinned;

  const TogglePinParams({required this.postId, required this.isPinned});

  @override
  List<Object?> get props => [postId, isPinned];
}

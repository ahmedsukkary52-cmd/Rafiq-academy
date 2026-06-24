import 'dart:io';

import '../../domain/entities/posts_entities.dart';
import '../models/post_models.dart';

abstract class PostsRemoteDatasource {
  Stream<List<PostModel>> watchPosts({required String halaqaId});

  Stream<List<CommentModel>> watchComments(String postId);

  Future<void> createPost({
    required String authorId,
    required String authorName,
    required String content,
    required String? halaqaId,
    required PostAudience audience,
    List<File> attachmentFiles,
    List<AttachmentType> attachmentTypes,
  });

  Future<void> toggleLike({
    required String postId,
    required String uid,
    required bool isCurrentlyLiked,
  });

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  });

  Future<void> togglePin({required String postId, required bool isPinned});

  Future<void> deletePost(String postId);
}

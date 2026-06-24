import 'dart:io';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/posts_entities.dart';

abstract class PostsRepository {
  /// Stream لمنشورات حلقة معيّنة (+ المنشورات العامة لكل الحلقات)
  /// مرتبة: المثبّتة أولاً ثم الأحدث
  Stream<Either<Failure, List<PostEntity>>> watchPosts({
    required String halaqaId,
  });

  /// Stream لتعليقات منشور معيّن
  Stream<Either<Failure, List<CommentEntity>>> watchComments(String postId);

  /// نشر منشور جديد (مع رفع المرفقات لـ Firebase Storage أولاً)
  Future<Either<Failure, Unit>> createPost({
    required String authorId,
    required String authorName,
    required String content,
    required String? halaqaId,
    required PostAudience audience,
    List<File> attachmentFiles,
    List<AttachmentType> attachmentTypes,
  });

  /// إضافة/إزالة إعجاب - بنستخدم arrayUnion/arrayRemove بدل ما نقرأ القيمة
  /// الحالية ونغيّرها (يتجنب race condition لو أكتر من حد ضغط في نفس الوقت)
  Future<Either<Failure, Unit>> toggleLike({
    required String postId,
    required String uid,
    required bool isCurrentlyLiked,
  });

  /// إضافة تعليق
  Future<Either<Failure, Unit>> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  });

  /// تثبيت/إلغاء تثبيت منشور (صلاحية المعلم والمشرف فقط)
  Future<Either<Failure, Unit>> togglePin({
    required String postId,
    required bool isPinned,
  });

  /// حذف منشور (صاحبه فقط أو الإدارة)
  Future<Either<Failure, Unit>> deletePost(String postId);
}

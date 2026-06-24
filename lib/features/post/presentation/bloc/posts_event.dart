import 'dart:io';

import 'package:equatable/equatable.dart';

import '../../domain/entities/posts_entities.dart';

abstract class PostsEvent extends Equatable {
  const PostsEvent();

  @override
  List<Object?> get props => [];
}

/// بدء مراقبة منشورات حلقة معيّنة
class WatchPostsEvent extends PostsEvent {
  final String halaqaId;

  const WatchPostsEvent(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}

/// نشر منشور جديد (نص + مرفقات اختيارية)
class CreatePostEvent extends PostsEvent {
  final String authorId;
  final String authorName;
  final String content;
  final String? halaqaId;
  final PostAudience audience;
  final List<File> attachmentFiles;
  final List<AttachmentType> attachmentTypes;

  const CreatePostEvent({
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.halaqaId,
    required this.audience,
    this.attachmentFiles = const [],
    this.attachmentTypes = const [],
  });

  @override
  List<Object?> get props => [authorId, content, halaqaId, audience];
}

class ResetCreatePostEvent extends PostsEvent {
  const ResetCreatePostEvent();
}

/// إعجاب أو إلغاء إعجاب بمنشور
class ToggleLikeEvent extends PostsEvent {
  final String postId;
  final String uid;
  final bool isCurrentlyLiked;

  const ToggleLikeEvent({
    required this.postId,
    required this.uid,
    required this.isCurrentlyLiked,
  });

  @override
  List<Object?> get props => [postId, uid, isCurrentlyLiked];
}

/// فتح تعليقات منشور معيّن (بدء stream التعليقات)
class WatchCommentsEvent extends PostsEvent {
  final String postId;

  const WatchCommentsEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

/// إرسال تعليق جديد
class AddCommentEvent extends PostsEvent {
  final String postId;
  final String authorId;
  final String authorName;
  final String content;

  const AddCommentEvent({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
  });

  @override
  List<Object?> get props => [postId, authorId, content];
}

/// تثبيت أو إلغاء تثبيت منشور
class TogglePinEvent extends PostsEvent {
  final String postId;
  final bool isPinned;

  const TogglePinEvent({required this.postId, required this.isPinned});

  @override
  List<Object?> get props => [postId, isPinned];
}

/// حذف منشور
class DeletePostEvent extends PostsEvent {
  final String postId;

  const DeletePostEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}

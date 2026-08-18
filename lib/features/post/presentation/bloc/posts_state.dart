import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/posts_entities.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class PostsState extends Equatable {
  // ── قائمة المنشورات ───────────────────────────────────────────────────
  final SectionStatus postsStatus;
  final List<PostEntity> posts;
  final String? postsError;

  /// Halaqa currently being watched — used to clear stale posts on switch.
  final String? watchedHalaqaId;

  // ── التعليقات (لمنشور محدد) ────────────────────────────────────────────
  final SectionStatus commentsStatus;
  final List<CommentEntity> comments;
  final String? activePostId; // الـ post اللي بنشوف تعليقاته حالياً
  final String? commentsError;

  // ── نشر منشور جديد ────────────────────────────────────────────────────
  final SubmissionStatus createPostStatus;
  final String? createPostError;

  // ── إضافة تعليق ───────────────────────────────────────────────────────
  final SubmissionStatus addCommentStatus;
  final String? addCommentError;

  const PostsState({
    this.postsStatus = SectionStatus.initial,
    this.posts = const [],
    this.postsError,
    this.watchedHalaqaId,
    this.commentsStatus = SectionStatus.initial,
    this.comments = const [],
    this.activePostId,
    this.commentsError,
    this.createPostStatus = SubmissionStatus.idle,
    this.createPostError,
    this.addCommentStatus = SubmissionStatus.idle,
    this.addCommentError,
  });

  factory PostsState.initial() => const PostsState();

  PostsState copyWith({
    SectionStatus? postsStatus,
    List<PostEntity>? posts,
    Object? postsError = _unset,
    Object? watchedHalaqaId = _unset,
    SectionStatus? commentsStatus,
    List<CommentEntity>? comments,
    Object? activePostId = _unset,
    Object? commentsError = _unset,
    SubmissionStatus? createPostStatus,
    Object? createPostError = _unset,
    SubmissionStatus? addCommentStatus,
    Object? addCommentError = _unset,
  }) {
    return PostsState(
      postsStatus: postsStatus ?? this.postsStatus,
      posts: posts ?? this.posts,
      postsError: identical(postsError, _unset)
          ? this.postsError
          : postsError as String?,
      watchedHalaqaId: identical(watchedHalaqaId, _unset)
          ? this.watchedHalaqaId
          : watchedHalaqaId as String?,
      commentsStatus: commentsStatus ?? this.commentsStatus,
      comments: comments ?? this.comments,
      activePostId: identical(activePostId, _unset)
          ? this.activePostId
          : activePostId as String?,
      commentsError: identical(commentsError, _unset)
          ? this.commentsError
          : commentsError as String?,
      createPostStatus: createPostStatus ?? this.createPostStatus,
      createPostError: identical(createPostError, _unset)
          ? this.createPostError
          : createPostError as String?,
      addCommentStatus: addCommentStatus ?? this.addCommentStatus,
      addCommentError: identical(addCommentError, _unset)
          ? this.addCommentError
          : addCommentError as String?,
    );
  }

  @override
  List<Object?> get props => [
    postsStatus,
    posts,
    postsError,
    watchedHalaqaId,
    commentsStatus,
    comments,
    activePostId,
    commentsError,
    createPostStatus,
    createPostError,
    addCommentStatus,
    addCommentError,
  ];
}

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/posts_entities.dart';
import '../../domain/usecases/posts_usecases.dart';
import 'posts_event.dart';
import 'posts_state.dart';

/// @singleton لأن قائمة المنشورات واحدة طول ما المستخدم في نافذته،
/// والـ stream لازم يفضل مفتوح عشان التحديثات تظهر real-time.
@singleton
class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final WatchPostsUseCase watchPosts;
  final WatchCommentsUseCase watchComments;
  final CreatePostUseCase createPost;
  final ToggleLikeUseCase toggleLike;
  final AddCommentUseCase addComment;
  final TogglePinUseCase togglePin;
  final DeletePostUseCase deletePost;

  /// Bumped on logout so in-flight post/comment snapshots are ignored (H1).
  int _sessionGeneration = 0;

  PostsBloc({
    required this.watchPosts,
    required this.watchComments,
    required this.createPost,
    required this.toggleLike,
    required this.addComment,
    required this.togglePin,
    required this.deletePost,
  }) : super(PostsState.initial()) {
    on<WatchPostsEvent>(_onWatchPosts, transformer: restartable());
    on<WatchCommentsEvent>(_onWatchComments, transformer: restartable());
    on<CreatePostEvent>(_onCreatePost);
    on<ResetCreatePostEvent>(_onResetCreatePost);
    on<ToggleLikeEvent>(_onToggleLike);
    on<AddCommentEvent>(_onAddComment);
    on<TogglePinEvent>(_onTogglePin);
    on<DeletePostEvent>(_onDeletePost);
    on<ClearPostsSessionEvent>(_onClearSession);
  }

  void _onClearSession(
    ClearPostsSessionEvent event,
    Emitter<PostsState> emit,
  ) {
    _sessionGeneration++;
    emit(PostsState.initial());
  }

  // ══════════════════════════════════════════════════════════════════════
  // قائمة المنشورات - Stream
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onWatchPosts(
    WatchPostsEvent event,
    Emitter<PostsState> emit,
  ) async {
    final generation = _sessionGeneration;
    emit(state.copyWith(postsStatus: SectionStatus.loading, postsError: null));

    await emit.forEach(
      watchPosts(WatchPostsParams(event.halaqaId)),
      onData: (either) {
        if (generation != _sessionGeneration) return state;
        return either.fold(
          (failure) => state.copyWith(
            postsStatus: SectionStatus.error,
            postsError: failure.message,
          ),
          (posts) =>
              state.copyWith(postsStatus: SectionStatus.loaded, posts: posts),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // التعليقات - Stream (restartable عشان كل منشور يبدأ stream جديد)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onWatchComments(
    WatchCommentsEvent event,
    Emitter<PostsState> emit,
  ) async {
    final generation = _sessionGeneration;
    emit(
      state.copyWith(
        commentsStatus: SectionStatus.loading,
        commentsError: null,
        activePostId: event.postId,
        comments: const [],
      ),
    );

    await emit.forEach(
      watchComments(PostIdParams(event.postId)),
      onData: (either) {
        if (generation != _sessionGeneration) return state;
        return either.fold(
          (failure) => state.copyWith(
            commentsStatus: SectionStatus.error,
            commentsError: failure.message,
          ),
          (comments) => state.copyWith(
            commentsStatus: SectionStatus.loaded,
            comments: comments,
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // نشر منشور جديد
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onCreatePost(
    CreatePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    emit(
      state.copyWith(
        createPostStatus: SubmissionStatus.submitting,
        createPostError: null,
      ),
    );

    final result = await createPost(
      CreatePostParams(
        authorId: event.authorId,
        authorName: event.authorName,
        content: event.content,
        halaqaId: event.halaqaId,
        audience: event.audience,
        attachmentFiles: event.attachmentFiles,
        attachmentTypes: event.attachmentTypes,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          createPostStatus: SubmissionStatus.error,
          createPostError: failure.message,
        ),
      ),
      // الـ stream (WatchPostsEvent) هيحدّث القائمة تلقائياً من Firestore
      // بعد نجاح النشر، مفيش داعي نضيف المنشور يدوياً للقائمة.
      (_) => emit(state.copyWith(createPostStatus: SubmissionStatus.success)),
    );
  }

  void _onResetCreatePost(
    ResetCreatePostEvent event,
    Emitter<PostsState> emit,
  ) {
    emit(
      state.copyWith(
        createPostStatus: SubmissionStatus.idle,
        createPostError: null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // الإعجاب - Optimistic (نفس نمط تسجيل الحضور)
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onToggleLike(
    ToggleLikeEvent event,
    Emitter<PostsState> emit,
  ) async {
    // نحدّث الـ UI فوراً بدل ما ننتظر Firestore
    final optimisticPosts = state.posts.map((post) {
      if (post.id != event.postId) return post;

      final updatedLikedBy = List<String>.from(post.likedBy);
      if (event.isCurrentlyLiked) {
        updatedLikedBy.remove(event.uid);
      } else {
        updatedLikedBy.add(event.uid);
      }

      // PostEntity مش مutable، محتاجين نعمل copy بيانوي
      // (مش عندنا copyWith لأن مش استخدمنا freezed)
      return PostEntity(
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        authorImageUrl: post.authorImageUrl,
        content: post.content,
        attachments: post.attachments,
        halaqaId: post.halaqaId,
        audience: post.audience,
        createdAt: post.createdAt,
        isPinned: post.isPinned,
        likedBy: updatedLikedBy,
        commentsCount: post.commentsCount,
      );
    }).toList();

    emit(state.copyWith(posts: optimisticPosts));

    // Firestore بيتحدّث في الخلفية - لو فشل الـ stream هيرجع
    // للقيمة الحقيقية تلقائياً في الـ emit.forEach القديم
    await toggleLike(
      ToggleLikeParams(
        postId: event.postId,
        uid: event.uid,
        isCurrentlyLiked: event.isCurrentlyLiked,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // إضافة تعليق
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onAddComment(
    AddCommentEvent event,
    Emitter<PostsState> emit,
  ) async {
    emit(
      state.copyWith(
        addCommentStatus: SubmissionStatus.submitting,
        addCommentError: null,
      ),
    );

    final result = await addComment(
      AddCommentParams(
        postId: event.postId,
        authorId: event.authorId,
        authorName: event.authorName,
        content: event.content,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          addCommentStatus: SubmissionStatus.error,
          addCommentError: failure.message,
        ),
      ),
      // نفس فكرة الـ like - الـ stream هيحدّث التعليقات تلقائياً
      (_) => emit(state.copyWith(addCommentStatus: SubmissionStatus.success)),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // تثبيت / إلغاء تثبيت
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onTogglePin(
    TogglePinEvent event,
    Emitter<PostsState> emit,
  ) async {
    // تحديث محلي فوري للـ UI (Optimistic)
    final optimisticPosts = state.posts.map((post) {
      if (post.id != event.postId) return post;
      return PostEntity(
        id: post.id,
        authorId: post.authorId,
        authorName: post.authorName,
        authorImageUrl: post.authorImageUrl,
        content: post.content,
        attachments: post.attachments,
        halaqaId: post.halaqaId,
        audience: post.audience,
        createdAt: post.createdAt,
        isPinned: event.isPinned,
        likedBy: post.likedBy,
        commentsCount: post.commentsCount,
      );
    }).toList();

    // إعادة ترتيب: المثبّت يطلع فوق
    optimisticPosts.sort((a, b) {
      if (a.isPinned == b.isPinned) return 0;
      return a.isPinned ? -1 : 1;
    });

    emit(state.copyWith(posts: optimisticPosts));
    await togglePin(
      TogglePinParams(postId: event.postId, isPinned: event.isPinned),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // حذف منشور
  // ══════════════════════════════════════════════════════════════════════

  Future<void> _onDeletePost(
    DeletePostEvent event,
    Emitter<PostsState> emit,
  ) async {
    // Optimistic: نشيل المنشور من القائمة فوراً
    final optimisticPosts = state.posts
        .where((p) => p.id != event.postId)
        .toList();
    emit(state.copyWith(posts: optimisticPosts));

    // لو الحذف فشل، الـ stream هيرجع المنشور في القائمة تلقائياً
    await deletePost(PostIdParams(event.postId));
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/post/domain/entities/posts_entities.dart';
import 'package:rafiq_academy/features/post/domain/post_audience_target.dart';
import 'package:rafiq_academy/features/post/domain/repositories/posts_repository.dart';
import 'package:rafiq_academy/features/post/domain/usecases/posts_usecases.dart';
import 'package:rafiq_academy/features/post/presentation/bloc/posts_bloc.dart';
import 'package:rafiq_academy/features/post/presentation/bloc/posts_event.dart';

PostEntity _post({
  required String id,
  required String halaqaId,
  String content = 'مرحبا',
}) {
  return PostEntity(
    id: id,
    authorId: 't1',
    authorName: 'معلم',
    content: content,
    halaqaId: halaqaId,
    audience: PostAudience.specificHalaqa,
    createdAt: DateTime(2026, 8, 16),
  );
}

class _FakePostsRepository implements PostsRepository {
  final controllers =
      <String, StreamController<Either<Failure, List<PostEntity>>>>{};
  final created = <CreatePostParams>[];
  Either<Failure, Unit> createResult = const Right(unit);

  StreamController<Either<Failure, List<PostEntity>>> controllerFor(
    String halaqaId,
  ) {
    return controllers.putIfAbsent(
      halaqaId,
      () => StreamController<Either<Failure, List<PostEntity>>>.broadcast(),
    );
  }

  @override
  Stream<Either<Failure, List<PostEntity>>> watchPosts({
    required String halaqaId,
  }) {
    return controllerFor(halaqaId).stream;
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
    created.add(
      CreatePostParams(
        authorId: authorId,
        authorName: authorName,
        content: content,
        halaqaId: halaqaId,
        audience: audience,
        attachmentFiles: attachmentFiles,
        attachmentTypes: attachmentTypes,
      ),
    );
    return createResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('resolvePostAudienceTarget', () {
    test('maps allHalaqat to all', () {
      expect(
        resolvePostAudienceTarget(
          audience: PostAudience.allHalaqat,
          halaqaId: 'h1',
        ),
        'all',
      );
    });

    test('maps specificHalaqa to trimmed halaqaId', () {
      expect(
        resolvePostAudienceTarget(
          audience: PostAudience.specificHalaqa,
          halaqaId: '  h-class  ',
        ),
        'h-class',
      );
    });

    test('returns null when specificHalaqa has no halaqaId', () {
      expect(
        resolvePostAudienceTarget(
          audience: PostAudience.specificHalaqa,
          halaqaId: null,
        ),
        isNull,
      );
      expect(
        resolvePostAudienceTarget(
          audience: PostAudience.specificHalaqa,
          halaqaId: '  ',
        ),
        isNull,
      );
    });
  });

  group('normalizePostsWatchHalaqaId', () {
    test('trims and rejects blank ids', () {
      expect(normalizePostsWatchHalaqaId(' h1 '), 'h1');
      expect(normalizePostsWatchHalaqaId(null), isNull);
      expect(normalizePostsWatchHalaqaId(''), isNull);
      expect(normalizePostsWatchHalaqaId('  '), isNull);
    });
  });

  group('CreatePostUseCase', () {
    late _FakePostsRepository repo;
    late CreatePostUseCase useCase;

    setUp(() {
      repo = _FakePostsRepository();
      useCase = CreatePostUseCase(repo);
    });

    test('rejects empty content with no attachments', () async {
      final result = await useCase(
        const CreatePostParams(
          authorId: 't1',
          authorName: 'معلم',
          content: '  ',
          halaqaId: 'h1',
          audience: PostAudience.specificHalaqa,
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(repo.created, isEmpty);
    });

    test('rejects specificHalaqa without halaqaId', () async {
      final result = await useCase(
        const CreatePostParams(
          authorId: 't1',
          authorName: 'معلم',
          content: 'منشور',
          halaqaId: null,
          audience: PostAudience.specificHalaqa,
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(repo.created, isEmpty);
    });

    test('creates for the current halaqa with specific audience', () async {
      final result = await useCase(
        const CreatePostParams(
          authorId: 't1',
          authorName: 'معلم',
          content: 'منشور الحلقة',
          halaqaId: 'h-class',
          audience: PostAudience.specificHalaqa,
        ),
      );
      expect(result, const Right(unit));
      expect(repo.created.single.halaqaId, 'h-class');
      expect(repo.created.single.audience, PostAudience.specificHalaqa);
    });

    test('allows allHalaqat without inventing a fake halaqa target', () async {
      final result = await useCase(
        const CreatePostParams(
          authorId: 't1',
          authorName: 'معلم',
          content: 'للجميع',
          halaqaId: 'h-class',
          audience: PostAudience.allHalaqat,
        ),
      );
      expect(result, const Right(unit));
      expect(repo.created.single.audience, PostAudience.allHalaqat);
      expect(repo.created.single.halaqaId, 'h-class');
    });
  });

  group('PostsBloc watch / create', () {
    late _FakePostsRepository repo;
    late PostsBloc bloc;

    setUp(() {
      repo = _FakePostsRepository();
      bloc = PostsBloc(
        watchPosts: WatchPostsUseCase(repo),
        watchComments: WatchCommentsUseCase(repo),
        createPost: CreatePostUseCase(repo),
        toggleLike: ToggleLikeUseCase(repo),
        addComment: AddCommentUseCase(repo),
        togglePin: TogglePinUseCase(repo),
        deletePost: DeletePostUseCase(repo),
      );
    });

    tearDown(() async {
      await bloc.close();
      for (final c in repo.controllers.values) {
        await c.close();
      }
    });

    test('loads posts for the watched halaqaId', () async {
      bloc.add(const WatchPostsEvent('h1'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.postsStatus, SectionStatus.loading);
      expect(bloc.state.watchedHalaqaId, 'h1');

      final loaded = bloc.stream.firstWhere(
        (s) => s.postsStatus == SectionStatus.loaded && s.posts.length == 1,
      );
      repo.controllerFor('h1').add(Right([_post(id: 'p1', halaqaId: 'h1')]));
      await loaded;

      expect(bloc.state.posts.single.id, 'p1');
      expect(bloc.state.watchedHalaqaId, 'h1');
    });

    test('clears posts when switching halaqaId (isolation)', () async {
      bloc.add(const WatchPostsEvent('h1'));
      await Future<void>.delayed(Duration.zero);
      repo.controllerFor('h1').add(Right([_post(id: 'p1', halaqaId: 'h1')]));
      await bloc.stream.firstWhere(
        (s) => s.postsStatus == SectionStatus.loaded && s.posts.isNotEmpty,
      );

      bloc.add(const WatchPostsEvent('h2'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.watchedHalaqaId, 'h2');
      expect(bloc.state.posts, isEmpty);
      expect(bloc.state.postsStatus, SectionStatus.loading);

      repo.controllerFor('h2').add(Right([_post(id: 'p2', halaqaId: 'h2')]));
      await bloc.stream.firstWhere(
        (s) =>
            s.postsStatus == SectionStatus.loaded &&
            s.posts.length == 1 &&
            s.posts.first.id == 'p2',
      );
      expect(bloc.state.posts.single.halaqaId, 'h2');
    });

    test('emits error and supports retry for the same halaqa', () async {
      bloc.add(const WatchPostsEvent('h1'));
      await Future<void>.delayed(Duration.zero);

      final errored = bloc.stream.firstWhere(
        (s) => s.postsStatus == SectionStatus.error,
      );
      repo.controllerFor('h1').add(const Left(ServerFailure('فشل التحميل')));
      await errored;
      expect(bloc.state.postsError, 'فشل التحميل');

      bloc.add(const WatchPostsEvent('h1'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.postsStatus, SectionStatus.loading);

      repo.controllerFor('h1').add(const Right(<PostEntity>[]));
      await bloc.stream.firstWhere(
        (s) => s.postsStatus == SectionStatus.loaded && s.posts.isEmpty,
      );
    });

    test('rejects blank watch halaqaId', () async {
      bloc.add(const WatchPostsEvent('  '));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.postsStatus, SectionStatus.error);
      expect(bloc.state.watchedHalaqaId, isNull);
      expect(bloc.state.posts, isEmpty);
    });

    test('create success for current halaqa updates create status', () async {
      bloc.add(const WatchPostsEvent('h1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(
        const CreatePostEvent(
          authorId: 't1',
          authorName: 'معلم',
          content: 'منشور جديد',
          halaqaId: 'h1',
          audience: PostAudience.specificHalaqa,
        ),
      );

      await bloc.stream.firstWhere(
        (s) => s.createPostStatus == SubmissionStatus.success,
      );
      expect(repo.created.single.halaqaId, 'h1');

      // Simulate Firestore stream refresh after create.
      repo.controllerFor('h1').add(
        Right([_post(id: 'new', halaqaId: 'h1', content: 'منشور جديد')]),
      );
      await bloc.stream.firstWhere(
        (s) => s.posts.any((p) => p.id == 'new'),
      );
    });

    test('create fails when specific halaqa id is missing', () async {
      bloc.add(
        const CreatePostEvent(
          authorId: 't1',
          authorName: 'معلم',
          content: 'منشور',
          halaqaId: null,
          audience: PostAudience.specificHalaqa,
        ),
      );
      await bloc.stream.firstWhere(
        (s) => s.createPostStatus == SubmissionStatus.error,
      );
      expect(repo.created, isEmpty);
    });
  });
}

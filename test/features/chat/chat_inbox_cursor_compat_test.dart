import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_event.dart';

const _teacher = ChatParticipantEntity(
  uid: 't1',
  name: 'أحمد',
  role: AppRoles.teacher,
);

ConversationEntity _conv(String id, int minute, {DateTime? at}) =>
    ConversationEntity(
      id: id,
      participants: const [_teacher],
      unreadCount: 0,
      lastMessageAt: at ?? DateTime(2026, 1, 1, 0, minute),
    );

class _PagingRepo extends Fake implements ChatRepository {
  final live = StreamController<Either<Failure, List<ConversationEntity>>>();
  final cursors = <String>[];
  final pages = <String, List<ConversationEntity>>{};

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchAllConversations({
    required String observerUid,
    int? limit,
  }) => live.stream;

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations(
    String uid, {
    int? limit,
  }) => const Stream.empty();

  @override
  Future<Either<Failure, List<ConversationEntity>>> fetchConversationsAfter({
    String? participantUid,
    required String viewerUid,
    required String afterConversationId,
    required int limit,
  }) async {
    cursors.add(afterConversationId);
    return Right(pages[afterConversationId] ?? const []);
  }
}

void main() {
  test(
    'LoadMore cursor stays on Firestore page tip after equal-timestamp re-sort',
    () async {
      final repo = _PagingRepo();
      final bloc = ChatConversationsBloc(
        watchConversations: WatchConversationsUseCase(repo),
        watchAllConversations: WatchAllConversationsUseCase(repo),
        getOrCreateConversation: GetOrCreateConversationUseCase(repo),
      );
      addTearDown(bloc.close);

      final same = DateTime(2026, 1, 1, 12);
      bloc.add(const StartWatchingAllConversationsEvent('a1', pageSize: 2));
      await Future<void>.delayed(Duration.zero);
      repo.live.add(
        Right([
          _conv('c3', 3),
          _conv('c2', 2, at: same),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.hasMoreConversations, isTrue);

      repo.pages['c2'] = [
        _conv('c1', 1, at: same),
        _conv('c0', 0, at: same),
      ];
      bloc.add(const LoadMoreConversationsEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.cursors, ['c2']);

      repo.pages['c0'] = [_conv('c-1', -1)];
      bloc.add(const LoadMoreConversationsEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        repo.cursors,
        ['c2', 'c0'],
        reason: 'second page must start after raw tip c0, not a re-sorted id',
      );
      expect(
        bloc.state.conversations.map((c) => c.id).toSet(),
        containsAll(['c3', 'c2', 'c1', 'c0', 'c-1']),
      );
    },
  );

  test('concurrent LoadMore is dropped while a page is in flight', () async {
    final repo = _PagingRepo();
    final bloc = ChatConversationsBloc(
      watchConversations: WatchConversationsUseCase(repo),
      watchAllConversations: WatchAllConversationsUseCase(repo),
      getOrCreateConversation: GetOrCreateConversationUseCase(repo),
    );
    addTearDown(bloc.close);

    bloc.add(const StartWatchingAllConversationsEvent('a1', pageSize: 2));
    await Future<void>.delayed(Duration.zero);
    repo.live.add(Right([_conv('c3', 3), _conv('c2', 2)]));
    await Future<void>.delayed(Duration.zero);

    repo.pages['c2'] = [_conv('c1', 1)];
    bloc.add(const LoadMoreConversationsEvent());
    bloc.add(const LoadMoreConversationsEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.cursors.length, 1);
  });
}

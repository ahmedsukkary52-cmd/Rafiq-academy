import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_event.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_state.dart';

/// Acceptance matrix for BASMA-103 cursor pagination (D2 final validation).
/// Uses a deterministic in-memory message store so multi-page traversal,
/// realtime overlap, and lifecycle races are asserted on actual message sets.

typedef OlderPageResult = Either<Failure, List<MessageEntity>>;

MessageEntity _msg(
  String id, {
  required DateTime at,
  String sender = 's1',
  String text = '',
}) =>
    MessageEntity(
      id: id,
      conversationId: 'c1',
      senderId: sender,
      text: text.isEmpty ? id : text,
      sentAt: at,
    );

class _PagingRepo implements ChatRepository {
  _PagingRepo(this.store);

  /// Full conversation history, ascending by time then id.
  final List<MessageEntity> store;

  final messages =
      StreamController<Either<Failure, List<MessageEntity>>>.broadcast();
  final watchLimits = <int>[];
  final olderFetches = <({String beforeMessageId, int limit})>[];
  int markReadCalls = 0;

  /// Optional override queue for failure / delayed older pages.
  final List<Future<OlderPageResult> Function()?> olderOverrides = [];

  List<MessageEntity> liveWindow({int limit = ChatRoomState.pageSize}) {
    if (store.isEmpty) return const [];
    final start = store.length > limit ? store.length - limit : 0;
    return store.sublist(start);
  }

  void emitLive() {
    messages.add(Right(liveWindow()));
  }

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId, {
    required int limit,
  }) {
    watchLimits.add(limit);
    return messages.stream;
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> fetchMessagesBefore({
    required String conversationId,
    required String beforeMessageId,
    required int limit,
  }) async {
    olderFetches.add((beforeMessageId: beforeMessageId, limit: limit));
    if (olderOverrides.isNotEmpty) {
      final next = olderOverrides.removeAt(0);
      if (next != null) return next();
    }

    final idx = store.indexWhere((m) => m.id == beforeMessageId);
    if (idx <= 0) return const Right([]);
    final from = (idx - limit).clamp(0, idx);
    return Right(store.sublist(from, idx));
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> fetchMessagesByIds({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    final byId = {for (final m in store) m.id: m};
    return Right([
      for (final id in messageIds)
        if (byId.containsKey(id)) byId[id]!,
    ]);
  }

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String uid,
  }) async {
    markReadCalls++;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
    String? replyToMessageId,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, ChatUploadTask>> startAttachmentUpload({
    required String conversationId,
    required String messageId,
    required String uploaderId,
    required ChatAttachmentDraft draft,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> discardUpload(String storagePath) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> softDeleteMessage({
    required String conversationId,
    required String messageId,
  }) async =>
      const Right(unit);

  @override
  Future<Either<Failure, Unit>> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) async =>
      const Right(unit);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatRoomBloc _bloc(_PagingRepo repo) => ChatRoomBloc(
      WatchMessagesUseCase(repo),
      FetchOlderMessagesUseCase(repo),
      FetchMessagesByIdsUseCase(repo),
      SendMessageUseCase(repo),
      MarkConversationAsReadUseCase(repo),
      SoftDeleteChatMessageUseCase(repo),
      EditChatMessageUseCase(repo),
      StartChatUploadUseCase(repo),
      DiscardChatUploadUseCase(repo),
      'c1',
      't1',
    );

List<MessageEntity> _buildStore(int count, {DateTime? base}) {
  final t0 = base ?? DateTime(2026, 1, 1, 12);
  return [
    for (var i = 0; i < count; i++)
      _msg('m${i.toString().padLeft(3, '0')}', at: t0.add(Duration(minutes: i))),
  ];
}

void main() {
  late _PagingRepo repo;
  late ChatRoomBloc bloc;

  Future<ChatRoomState> until(bool Function(ChatRoomState s) test) async {
    if (test(bloc.state)) return bloc.state;
    return bloc.stream.firstWhere(test).timeout(const Duration(seconds: 3));
  }

  Future<void> openLive() async {
    await Future<void>.delayed(Duration.zero);
    repo.emitLive();
    await until((s) => s.messagesStatus == SectionStatus.loaded);
  }

  setUp(() {
    repo = _PagingRepo(_buildStore(95));
    bloc = _bloc(repo);
  });

  tearDown(() async {
    await bloc.close();
    await repo.messages.close();
  });

  group('A. Initial load', () {
    test('loads only the newest 30; older remain unloaded; live limit fixed',
        () async {
      await openLive();
      expect(repo.watchLimits, [30]);
      expect(bloc.state.limit, 30);
      expect(bloc.state.messages, hasLength(30));
      expect(bloc.state.messages.first.id, 'm065');
      expect(bloc.state.messages.last.id, 'm094');
      expect(bloc.state.hasMore, isTrue);
      expect(repo.olderFetches, isEmpty);
      expect(
        bloc.state.messages.map((m) => m.id),
        isNot(contains('m000')),
      );
    });

    test('messages are ascending by sentAt then id', () async {
      await openLive();
      final ids = bloc.state.messages.map((m) => m.id).toList();
      expect(ids, List.generate(30, (i) => 'm${(65 + i).toString().padLeft(3, '0')}'));
      for (var i = 1; i < bloc.state.messages.length; i++) {
        final a = bloc.state.messages[i - 1];
        final b = bloc.state.messages[i];
        final cmp = a.sentAt.compareTo(b.sentAt);
        expect(cmp <= 0, isTrue);
        if (cmp == 0) expect(a.id.compareTo(b.id) <= 0, isTrue);
      }
    });
  });

  group('B. Older pages — full traversal without gaps/dupes', () {
    test('sequential pages reach conversation start; all 95 reachable',
        () async {
      await openLive();
      final seen = <String>{for (final m in bloc.state.messages) m.id};

      while (bloc.state.hasMore) {
        final beforeLen = bloc.state.messages.length;
        final beforeFirst = bloc.state.messages.first.id;
        bloc.add(const LoadOlderMessagesRequestedEvent());
        await until(
          (s) =>
              !s.loadingOlder &&
              (s.messages.length > beforeLen || !s.hasMoreOlder),
        );
        expect(repo.olderFetches.last.beforeMessageId, beforeFirst);
        expect(repo.watchLimits, everyElement(30));
        for (final m in bloc.state.messages) {
          seen.add(m.id);
        }
        final ids = bloc.state.messages.map((m) => m.id).toList();
        expect(ids.toSet().length, ids.length, reason: 'no duplicates');
        // No gaps relative to store prefix of current window.
        final expected = repo.store
            .where((m) => seen.contains(m.id))
            .map((m) => m.id)
            .toList();
        expect(ids, expected);
      }

      expect(seen, repo.store.map((m) => m.id).toSet());
      expect(bloc.state.messages, hasLength(95));
      expect(bloc.state.messages.first.id, 'm000');
      expect(bloc.state.hasMore, isFalse);

      // No further fetches after exhaustion.
      final fetches = repo.olderFetches.length;
      bloc.add(const LoadOlderMessagesRequestedEvent());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repo.olderFetches.length, fetches);
    });

    test('does not re-fetch previously loaded live messages as older page body',
        () async {
      await openLive();
      final liveIds = bloc.state.messages.map((m) => m.id).toSet();
      bloc.add(const LoadOlderMessagesRequestedEvent());
      await until((s) => s.messages.length == 60 && !s.loadingOlder);
      final olderOnly = bloc.state.messages
          .where((m) => !liveIds.contains(m.id))
          .map((m) => m.id)
          .toSet();
      expect(olderOnly.intersection(liveIds), isEmpty);
      expect(repo.olderFetches, hasLength(1));
    });
  });

  group('C. Realtime during pagination', () {
    test('new messages during older fetch are retained with older page',
        () async {
      await openLive();
      repo.olderOverrides.add(
        () => Future.delayed(
          const Duration(milliseconds: 50),
          () {
            final idx = repo.store.indexWhere((m) => m.id == 'm065');
            return Right(repo.store.sublist(idx - 30, idx));
          },
        ),
      );
      bloc.add(const LoadOlderMessagesRequestedEvent());
      await until((s) => s.loadingOlder);

      final tNew = DateTime(2026, 1, 1, 14);
      repo.store.addAll([
        _msg('n1', at: tNew),
        _msg('n2', at: tNew.add(const Duration(seconds: 1))),
      ]);
      repo.emitLive();
      await until((s) => s.messages.any((m) => m.id == 'n2'));

      final done = await until(
        (s) => !s.loadingOlder && s.messages.any((m) => m.id == 'm035'),
      );
      expect(done.messages.any((m) => m.id == 'n1'), isTrue);
      expect(done.messages.any((m) => m.id == 'n2'), isTrue);
      expect(done.messages.any((m) => m.id == 'm035'), isTrue);
      final ids = done.messages.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('tied timestamp from live merges with deterministic id order',
        () async {
      await bloc.close();
      await repo.messages.close();
      final t = DateTime(2026, 6, 1, 10);
      repo = _PagingRepo([
        _msg('a', at: t),
        _msg('c', at: t),
      ]);
      bloc = _bloc(repo);
      await openLive();
      expect(bloc.state.messages.map((m) => m.id), ['a', 'c']);

      repo.store.add(_msg('b', at: t));
      repo.emitLive();
      final s = await until((st) => st.messages.length == 3);
      expect(s.messages.map((m) => m.id), ['a', 'b', 'c']);
    });
  });

  group('D. Ordering and identity', () {
    test('dedupe key is message id when older overlaps live', () async {
      await openLive();
      // Force overlap: return last 5 of live as "older".
      repo.olderOverrides.add(() async {
        return Right(repo.store.sublist(60, 70));
      });
      bloc.add(const LoadOlderMessagesRequestedEvent());
      final s = await until((st) => !st.loadingOlder && st.messages.length >= 30);
      final ids = s.messages.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('E. Concurrency and lifecycle', () {
    test('triple load-older yields a single fetch (droppable + guard)',
        () async {
      await openLive();
      repo.olderOverrides.add(
        () => Future.delayed(
          const Duration(milliseconds: 80),
          () {
            final idx = repo.store.indexWhere((m) => m.id == 'm065');
            return Right(repo.store.sublist(idx - 30, idx));
          },
        ),
      );
      bloc.add(const LoadOlderMessagesRequestedEvent());
      bloc.add(const LoadOlderMessagesRequestedEvent());
      bloc.add(const LoadOlderMessagesRequestedEvent());
      await until((s) => s.loadingOlder);
      await until((s) => !s.loadingOlder);
      expect(repo.olderFetches, hasLength(1));
    });

    test('closing during older fetch ignores late result (no throw)', () async {
      await openLive();
      final completer = Completer<OlderPageResult>();
      repo.olderOverrides.add(() => completer.future);
      bloc.add(const LoadOlderMessagesRequestedEvent());
      await until((s) => s.loadingOlder);
      await bloc.close();
      completer.complete(Right(repo.store.sublist(0, 30)));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      // New bloc for a different room must not see prior buffer.
      final repo2 = _PagingRepo(_buildStore(5));
      final bloc2 = _bloc(repo2);
      addTearDown(() async {
        await bloc2.close();
        await repo2.messages.close();
      });
      await Future<void>.delayed(Duration.zero);
      repo2.emitLive();
      await bloc2.stream
          .firstWhere((s) => s.messagesStatus == SectionStatus.loaded)
          .timeout(const Duration(seconds: 2));
      expect(bloc2.state.messages.map((m) => m.id), [
        'm000',
        'm001',
        'm002',
        'm003',
        'm004',
      ]);
      expect(bloc2.state.hasMore, isFalse);
    });
  });

  group('F. Failure and retry', () {
    test('initial stream failure then recover keeps retryable watch', () async {
      await Future<void>.delayed(Duration.zero);
      repo.messages.add(const Left(ServerFailure('network')));
      await until((s) => s.messagesStatus == SectionStatus.error);
      expect(bloc.state.messages, isEmpty);

      bloc.add(const WatchMessagesStartedEvent());
      await until((s) => s.messagesStatus == SectionStatus.loading);
      repo.emitLive();
      final s = await until((st) => st.messagesStatus == SectionStatus.loaded);
      expect(s.messages, hasLength(30));
      expect(s.hasMore, isTrue);
    });

    test('older failure preserves cursor capability for retry', () async {
      await openLive();
      repo.olderOverrides.add(
        () async => const Left(ServerFailure('تعذر تحميل الصفحة')),
      );
      bloc.add(const LoadOlderMessagesRequestedEvent());
      final failed = await until(
        (s) => !s.loadingOlder && s.messagesError != null,
      );
      expect(failed.messages, hasLength(30));
      expect(failed.hasMore, isTrue);

      bloc.add(const LoadOlderMessagesRequestedEvent());
      final ok = await until((s) => s.messages.length == 60 && !s.loadingOlder);
      expect(ok.messagesError, isNull);
      expect(ok.messages.first.id, 'm035');
    });
  });

  group('G. State correctness', () {
    test('loadingOlder true only while older request in flight', () async {
      await openLive();
      expect(bloc.state.loadingOlder, isFalse);
      repo.olderOverrides.add(
        () => Future.delayed(
          const Duration(milliseconds: 40),
          () {
            final idx = repo.store.indexWhere((m) => m.id == 'm065');
            // Full page ⇒ hasMore remains true.
            return Right(repo.store.sublist(idx - 30, idx));
          },
        ),
      );
      bloc.add(const LoadOlderMessagesRequestedEvent());
      await until((s) => s.loadingOlder);
      expect(bloc.state.messagesStatus, SectionStatus.loaded);
      await until((s) => !s.loadingOlder);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.messages, hasLength(60));
    });
  });
}

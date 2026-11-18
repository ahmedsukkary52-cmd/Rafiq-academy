import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_event.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_state.dart';

typedef _Feed = Either<Failure, List<ConversationEntity>>;

const _teacher = ChatParticipantEntity(
  uid: 't1',
  name: 'T',
  role: AppRoles.teacher,
);
const _parent = ChatParticipantEntity(
  uid: 'p1',
  name: 'P',
  role: AppRoles.parent,
);

const _conversation = ConversationEntity(
  id: 'p1_t1',
  participants: [_parent],
  unreadCount: 2,
);

class _Watch extends Fake implements WatchConversationsUseCase {
  final params = <ChatUidParams>[];
  final streams = <StreamController<_Feed>>[];

  StreamController<_Feed> get latest => streams.last;

  @override
  Stream<_Feed> call(ChatUidParams p) {
    params.add(p);
    final c = StreamController<_Feed>();
    streams.add(c);
    return c.stream;
  }
}

class _Start extends Fake implements GetOrCreateConversationUseCase {
  Either<Failure, ConversationEntity> result = const Right(_conversation);
  final params = <GetOrCreateConversationParams>[];

  @override
  Future<Either<Failure, ConversationEntity>> call(
    GetOrCreateConversationParams p,
  ) async {
    params.add(p);
    return result;
  }
}

class _UnusedWatchAll extends Fake implements WatchAllConversationsUseCase {}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Watch watch;
  late _Start start;
  late ChatConversationsBloc bloc;

  setUp(() {
    watch = _Watch();
    start = _Start();
    bloc = ChatConversationsBloc(
      watchConversations: watch,
      watchAllConversations: _UnusedWatchAll(),
      getOrCreateConversation: start,
    );
  });

  tearDown(() => bloc.close());

  test('initial state is idle', () {
    expect(bloc.state, ChatConversationsState.initial());
  });

  group('inbox stream', () {
    test('loading, loaded, empty and error', () async {
      bloc.add(const StartWatchingConversationsEvent('t1'));
      await _settle();
      expect(watch.params.single.uid, 't1');
      expect(
        watch.params.single.limit,
        ChatConversationsBloc.defaultInboxPageSize,
        reason: 'BASMA-104: omitted pageSize must still bound the live inbox',
      );
      expect(bloc.state.conversationsStatus, SectionStatus.loading);

      watch.latest.add(const Right([_conversation]));
      await _settle();
      expect(bloc.state.conversationsStatus, SectionStatus.loaded);
      expect(bloc.state.conversations, [_conversation]);

      watch.latest.add(const Right([]));
      await _settle();
      expect(bloc.state.conversations, isEmpty);

      watch.latest.add(
        const Left(ServerFailure('لم يعد لديك وصول إلى هذه المحادثة')),
      );
      await _settle();
      expect(bloc.state.conversationsStatus, SectionStatus.error);
      expect(bloc.state.conversationsError, 'لم يعد لديك وصول إلى هذه المحادثة');
    });

    test('retry after error re-subscribes and recovers', () async {
      bloc.add(const StartWatchingConversationsEvent('t1'));
      await _settle();
      watch.latest.add(const Left(ServerFailure('x')));
      await _settle();
      final failed = watch.latest;

      bloc.add(const StartWatchingConversationsEvent('t1'));
      await _settle();
      watch.latest.add(const Right([_conversation]));
      await _settle();

      expect(failed.hasListener, isFalse);
      expect(bloc.state.conversationsStatus, SectionStatus.loaded);
      expect(bloc.state.conversationsError, isNull);
    });

    test('account switch starts from an empty inbox', () async {
      bloc.add(const StartWatchingConversationsEvent('t1'));
      await _settle();
      watch.latest.add(const Right([_conversation]));
      await _settle();

      bloc.add(const StartWatchingConversationsEvent('p9'));
      await _settle();

      expect(bloc.state.conversationsStatus, SectionStatus.loading);
      expect(bloc.state.conversations, isEmpty);
    });

    test('logout clears the inbox and ignores late snapshots', () async {
      bloc.add(const StartWatchingConversationsEvent('t1'));
      await _settle();
      final stream = watch.latest;

      bloc.add(const ClearChatConversationsSessionEvent());
      await _settle();
      stream.add(const Right([_conversation]));
      await _settle();

      expect(bloc.state, ChatConversationsState.initial());
    });
  });

  group('start conversation', () {
    test('success exposes the conversation, reset clears it', () async {
      bloc.add(
        const StartConversationEvent(currentUser: _teacher, otherUser: _parent),
      );
      await _settle();

      expect(start.params.single.otherUser, _parent);
      expect(bloc.state.startConversationStatus, SubmissionStatus.success);
      expect(bloc.state.startedConversation, _conversation);

      bloc.add(const ResetStartConversationEvent());
      await _settle();
      expect(bloc.state.startConversationStatus, SubmissionStatus.idle);
      expect(bloc.state.startedConversation, isNull);
    });

    test('server denial is surfaced', () async {
      start.result = const Left(ServerFailure('No active relationship'));
      bloc.add(
        const StartConversationEvent(currentUser: _teacher, otherUser: _parent),
      );
      await _settle();

      expect(bloc.state.startConversationStatus, SubmissionStatus.error);
      expect(bloc.state.startConversationError, 'No active relationship');
      expect(bloc.state.startedConversation, isNull);
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_event.dart';

class _FakeChatRepository implements ChatRepository {
  final messages =
      StreamController<Either<Failure, List<MessageEntity>>>.broadcast();
  Either<Failure, Unit> sendResult = const Right(unit);
  String? lastSendText;
  int markReadCalls = 0;

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId,
  ) => messages.stream;

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    lastSendText = text;
    return sendResult;
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeChatRepository repo;
  late ChatRoomBloc bloc;

  setUp(() {
    repo = _FakeChatRepository();
    bloc = ChatRoomBloc(
      WatchMessagesUseCase(repo),
      SendMessageUseCase(repo),
      MarkConversationAsReadUseCase(repo),
      'c1',
      't1',
    );
  });

  tearDown(() async {
    await bloc.close();
    await repo.messages.close();
  });

  test('loads empty messages then a sent message; retry after error', () async {
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.messagesStatus, SectionStatus.loading);
    expect(repo.markReadCalls, 1);

    final loadedEmpty = bloc.stream.firstWhere(
      (s) => s.messagesStatus == SectionStatus.loaded && s.messages.isEmpty,
    );
    repo.messages.add(const Right(<MessageEntity>[]));
    await loadedEmpty;

    final sentOk = bloc.stream.firstWhere(
      (s) => s.sendStatus == SubmissionStatus.success,
    );
    bloc.add(const SendMessageRequestedEvent('test message'));
    await sentOk;
    expect(repo.lastSendText, 'test message');

    final sent = MessageEntity(
      id: 'm1',
      conversationId: 'c1',
      senderId: 't1',
      text: 'test message',
      sentAt: DateTime(2026, 8, 14, 12),
    );
    final loadedOne = bloc.stream.firstWhere((s) => s.messages.length == 1);
    repo.messages.add(Right([sent]));
    await loadedOne;
    expect(bloc.state.messages.single.text, 'test message');

    final errored = bloc.stream.firstWhere(
      (s) => s.messagesStatus == SectionStatus.error,
    );
    repo.messages.add(const Left(ServerFailure('unavailable')));
    await errored;
    expect(bloc.state.messagesError, 'unavailable');

    final loadingAgain = bloc.stream.firstWhere(
      (s) => s.messagesStatus == SectionStatus.loading,
    );
    bloc.add(const WatchMessagesStartedEvent());
    await loadingAgain;

    final loadedAfterRetry = bloc.stream.firstWhere(
      (s) => s.messagesStatus == SectionStatus.loaded && s.messages.length == 1,
    );
    repo.messages.add(Right([sent]));
    await loadedAfterRetry;
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSendConversationId;
  String? lastSendSenderId;
  String? lastSendText;
  int sendCalls = 0;

  String? lastReadConversationId;
  String? lastReadUid;
  int markReadCalls = 0;

  Either<Failure, Unit> sendResult = const Right(unit);
  Either<Failure, Unit> markReadResult = const Right(unit);

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    sendCalls++;
    lastSendConversationId = conversationId;
    lastSendSenderId = senderId;
    lastSendText = text;
    return sendResult;
  }

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String uid,
  }) async {
    markReadCalls++;
    lastReadConversationId = conversationId;
    lastReadUid = uid;
    return markReadResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('SendMessageUseCase', () {
    test(
      'rejects empty / whitespace-only text without repository call',
      () async {
        final repo = _FakeChatRepository();
        final useCase = SendMessageUseCase(repo);

        final empty = await useCase(
          const SendMessageParams(
            conversationId: 'c1',
            senderId: 'u1',
            text: '   ',
          ),
        );

        expect(empty.isLeft(), isTrue);
        empty.fold(
          (f) => expect(f, isA<ValidationFailure>()),
          (_) => fail('expected Left'),
        );
        expect(repo.sendCalls, 0);
      },
    );

    test('trims text before forwarding', () async {
      final repo = _FakeChatRepository();
      final useCase = SendMessageUseCase(repo);

      final result = await useCase(
        const SendMessageParams(
          conversationId: 'c1',
          senderId: 'u1',
          text: '  مرحبا  ',
        ),
      );

      expect(result, const Right(unit));
      expect(repo.sendCalls, 1);
      expect(repo.lastSendText, 'مرحبا');
      expect(repo.lastSendConversationId, 'c1');
      expect(repo.lastSendSenderId, 'u1');
    });

    test('surfaces repository failure', () async {
      final repo = _FakeChatRepository()
        ..sendResult = const Left(NetworkFailure());
      final useCase = SendMessageUseCase(repo);

      final result = await useCase(
        const SendMessageParams(
          conversationId: 'c1',
          senderId: 'u1',
          text: 'hi',
        ),
      );

      expect(result, const Left(NetworkFailure()));
    });
  });

  group('MarkConversationAsReadUseCase', () {
    test('forwards conversationId and uid', () async {
      final repo = _FakeChatRepository();
      final useCase = MarkConversationAsReadUseCase(repo);

      final result = await useCase(
        const MarkAsReadParams(conversationId: 'c1', uid: 'u1'),
      );

      expect(result, const Right(unit));
      expect(repo.markReadCalls, 1);
      expect(repo.lastReadConversationId, 'c1');
      expect(repo.lastReadUid, 'u1');
    });

    test('surfaces repository failure', () async {
      final repo = _FakeChatRepository()
        ..markReadResult = const Left(ServerFailure('deny'));
      final useCase = MarkConversationAsReadUseCase(repo);

      final result = await useCase(
        const MarkAsReadParams(conversationId: 'c1', uid: 'u1'),
      );

      expect(result, const Left(ServerFailure('deny')));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';

class _FakeChatRepository implements ChatRepository {
  String? lastSendConversationId;
  String? lastSendMessageId;
  ChatMessageType? lastSendType;
  String? lastSendText;
  ChatSendMedia? lastSendMedia;
  int sendCalls = 0;

  String? lastReadConversationId;
  String? lastReadUid;
  int markReadCalls = 0;

  Either<Failure, Unit> sendResult = const Right(unit);
  Either<Failure, Unit> markReadResult = const Right(unit);

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
  }) async {
    sendCalls++;
    lastSendConversationId = conversationId;
    lastSendMessageId = messageId;
    lastSendType = type;
    lastSendText = text;
    lastSendMedia = media;
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

const _id = 'AbCdEfGhIj0123456789';

void main() {
  group('SendMessageUseCase', () {
    test('rejects empty / whitespace-only text without repository call', () async {
      final repo = _FakeChatRepository();
      final result = await SendMessageUseCase(repo)(
        const SendMessageParams(conversationId: 'c1', messageId: _id, text: '   '),
      );
      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<ValidationFailure>()), (_) => fail('Left'));
      expect(repo.sendCalls, 0);
    });

    test('rejects text above the server limit', () async {
      final repo = _FakeChatRepository();
      final result = await SendMessageUseCase(repo)(
        SendMessageParams(
          conversationId: 'c1',
          messageId: _id,
          text: 'ا' * (ChatMediaPolicy.textMaxChars + 1),
        ),
      );
      expect(result.isLeft(), isTrue);
      expect(repo.sendCalls, 0);
    });

    test('rejects malformed client message ids', () async {
      final repo = _FakeChatRepository();
      final result = await SendMessageUseCase(repo)(
        const SendMessageParams(conversationId: 'c1', messageId: '../x', text: 'hi'),
      );
      expect(result.isLeft(), isTrue);
      expect(repo.sendCalls, 0);
    });

    test('trims text and forwards id; no sender identity is sent', () async {
      final repo = _FakeChatRepository();
      final result = await SendMessageUseCase(repo)(
        const SendMessageParams(
          conversationId: 'c1',
          messageId: _id,
          text: '  السلام عليكم  ',
        ),
      );
      expect(result, const Right(unit));
      expect(repo.lastSendText, 'السلام عليكم');
      expect(repo.lastSendConversationId, 'c1');
      expect(repo.lastSendMessageId, _id);
      expect(repo.lastSendType, ChatMessageType.text);
      expect(repo.lastSendMedia, isNull);
    });

    test('media message may have an empty caption', () async {
      final repo = _FakeChatRepository();
      const media = ChatSendMedia(
        storagePath: 'chat_media/c1/$_id/image.jpg',
        fileName: 'صورة.jpg',
      );
      final result = await SendMessageUseCase(repo)(
        const SendMessageParams(
          conversationId: 'c1',
          messageId: _id,
          type: ChatMessageType.image,
          text: '',
          media: media,
        ),
      );
      expect(result, const Right(unit));
      expect(repo.lastSendMedia, media);
      expect(repo.lastSendType, ChatMessageType.image);
    });

    test('surfaces repository failure', () async {
      final repo = _FakeChatRepository()..sendResult = const Left(NetworkFailure());
      final result = await SendMessageUseCase(repo)(
        const SendMessageParams(conversationId: 'c1', messageId: _id, text: 'hi'),
      );
      expect(result, const Left(NetworkFailure()));
    });
  });

  group('MarkConversationAsReadUseCase', () {
    test('forwards conversationId and uid', () async {
      final repo = _FakeChatRepository();
      final result = await MarkConversationAsReadUseCase(repo)(
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
      final result = await MarkConversationAsReadUseCase(repo)(
        const MarkAsReadParams(conversationId: 'c1', uid: 'u1'),
      );
      expect(result, const Left(ServerFailure('deny')));
    });
  });
}

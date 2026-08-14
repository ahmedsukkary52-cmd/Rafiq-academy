import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/network/network_info.dart';
import 'package:rafiq_academy/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:rafiq_academy/features/chat/data/models/chat_models.dart';
import 'package:rafiq_academy/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

class _FakeChatRemoteDatasource implements ChatRemoteDatasource {
  Stream<List<ConversationModel>> conversations = const Stream.empty();
  Stream<List<MessageModel>> messages = const Stream.empty();

  @override
  Stream<List<ConversationModel>> watchConversations(String uid) =>
      conversations;

  @override
  Stream<List<MessageModel>> watchMessages(String conversationId) => messages;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ChatRepositoryImpl.watchConversations', () {
    test('emits Left when the Firestore stream errors', () async {
      final ds = _FakeChatRemoteDatasource()
        ..conversations = Stream<List<ConversationModel>>.error(
          Exception('FAILED_PRECONDITION: index'),
        );
      final repo = ChatRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Online(),
      );

      final events = await repo.watchConversations('t1').toList();

      expect(events, hasLength(1));
      expect(events.single.isLeft(), isTrue);
      events.single.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('emits Right on data', () async {
      const conversation = ConversationModel(
        id: 'c1',
        participants: [
          ChatParticipantEntity(uid: 't1', name: 'معلم', role: 'teacher'),
        ],
        unreadCount: 0,
      );
      final ds = _FakeChatRemoteDatasource()
        ..conversations = Stream.value(const [conversation]);
      final repo = ChatRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Online(),
      );

      final events = await repo.watchConversations('t1').toList();
      expect(events.single.isRight(), isTrue);
    });
  });

  group('ChatRepositoryImpl.watchMessages', () {
    test('emits Left when the Firestore stream errors', () async {
      final ds = _FakeChatRemoteDatasource()
        ..messages = Stream<List<MessageModel>>.error(Exception('permission'));
      final repo = ChatRepositoryImpl(
        remoteDatasource: ds,
        networkInfo: _Online(),
      );

      final events = await repo.watchMessages('c1').toList();
      expect(events.single.isLeft(), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:rafiq_academy/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/shared/domain/halaqa_group_chat_contract.dart';

import '../support/fake_callables.dart';

/// WA-11: chat writes are authorized by the server callables. The client must
/// route every write through them (never write Firestore directly), must not
/// send a sender identity, and must surface a server denial as a failure.
void main() {
  late FakeFunctions functions;
  late FakeNetworkInfo network;
  late ChatRepositoryImpl repository;

  setUp(() {
    functions = FakeFunctions();
    network = FakeNetworkInfo();
    repository = ChatRepositoryImpl(
      remoteDatasource: ChatRemoteDatasourceImpl(
        firestore: UnusedFirestore(),
        functions: functions,
        storage: UnusedStorage(),
      ),
      networkInfo: network,
    );
  });

  void denyAll(String message) {
    for (final name in const [
      'createDirectConversation',
      'sendChatMessage',
      'editChatMessage',
      'softDeleteChatMessage',
    ]) {
      functions.handlers[name] = (_) =>
          throw FakeFunctionsError('permission-denied', message);
    }
  }

  const teacher = ChatParticipantEntity(
    uid: 'teacher1',
    name: 'T',
    role: AppRoles.teacher,
  );
  const student = ChatParticipantEntity(
    uid: 'student1',
    name: 'S',
    role: AppRoles.student,
  );
  const admin = ChatParticipantEntity(
    uid: 'admin1',
    name: 'A',
    role: AppRoles.admin,
  );

  group('writes go through server callables only', () {
    setUp(() {
      for (final name in const [
        'sendChatMessage',
        'editChatMessage',
        'softDeleteChatMessage',
      ]) {
        functions.handlers[name] = (_) => null;
      }
    });

    test('send carries no sender identity; server derives it', () async {
      final result = await repository.sendMessage(
        conversationId: ' a_b ',
        messageId: 'msgId_0123456789',
        type: ChatMessageType.text,
        text: '  hello  ',
      );

      expect(result, const Right<Failure, Unit>(unit));
      expect(functions.calledNames, ['sendChatMessage']);
      final payload = functions.payloadOf('sendChatMessage') as Map;
      expect(payload, {
        'conversationId': 'a_b',
        'messageId': 'msgId_0123456789',
        'type': 'text',
        'text': 'hello',
      });
      expect(payload.keys, isNot(contains('senderId')));
    });

    test('media send references the uploaded path only', () async {
      await repository.sendMessage(
        conversationId: 'a_b',
        messageId: 'msgId_0123456789',
        type: ChatMessageType.voice,
        text: '',
        media: const ChatSendMedia(
          storagePath: 'chat_media/a_b/m/v.m4a',
          fileName: 'v.m4a',
          durationMs: 1200,
        ),
      );

      final payload = functions.payloadOf('sendChatMessage') as Map;
      expect(payload.containsKey('text'), isFalse);
      expect(payload['media'], {
        'storagePath': 'chat_media/a_b/m/v.m4a',
        'fileName': 'v.m4a',
        'durationMs': 1200,
      });
    });

    test('edit and soft-delete use their callables', () async {
      expect(
        await repository.editMessage(
          conversationId: 'a_b',
          messageId: 'm1',
          text: ' fixed ',
        ),
        const Right<Failure, Unit>(unit),
      );
      expect(
        await repository.softDeleteMessage(conversationId: 'a_b', messageId: 'm1'),
        const Right<Failure, Unit>(unit),
      );

      expect(functions.calledNames, ['editChatMessage', 'softDeleteChatMessage']);
      expect(functions.payloadOf('editChatMessage'), {
        'conversationId': 'a_b',
        'messageId': 'm1',
        'text': 'fixed',
      });
      expect(functions.payloadOf('softDeleteChatMessage'), {
        'conversationId': 'a_b',
        'messageId': 'm1',
      });
    });
  });

  group('server denial is surfaced, never reported as success', () {
    test('non-Arabic permission-denied maps to the Arabic denial', () async {
      denyAll('Not a participant');
      const denied = ServerFailure('غير مسموح بهذا الإجراء في هذه المحادثة');

      expect(
        await repository.sendMessage(
          conversationId: 'x_y',
          messageId: 'msgId_0123456789',
          type: ChatMessageType.text,
          text: 'hi',
        ),
        const Left<Failure, Unit>(denied),
      );
      expect(
        await repository.editMessage(
          conversationId: 'x_y',
          messageId: 'm1',
          text: 'hi',
        ),
        const Left<Failure, Unit>(denied),
      );
      expect(
        await repository.softDeleteMessage(conversationId: 'x_y', messageId: 'm1'),
        const Left<Failure, Unit>(denied),
      );
    });

    test('Arabic server reason is shown as-is', () async {
      denyAll('انتهت مهلة تعديل الرسالة');

      final result = await repository.editMessage(
        conversationId: 'a_b',
        messageId: 'm1',
        text: 'late',
      );

      expect(
        result,
        const Left<Failure, Unit>(ServerFailure('انتهت مهلة تعديل الرسالة')),
      );
    });

    test('conversation creation denied by the relationship check', () async {
      denyAll('No active relationship');

      final result = await GetOrCreateConversationUseCase(repository)(
        const GetOrCreateConversationParams(
          currentUser: teacher,
          otherUser: student,
        ),
      );

      expect(functions.calledNames, ['createDirectConversation']);
      expect(functions.payloadOf('createDirectConversation'), {
        'otherUid': 'student1',
      });
      expect(result.isLeft(), isTrue);
      result.match(
        (f) => expect(f.message, 'No active relationship'),
        (_) => fail('denied conversation must not succeed'),
      );
    });
  });

  group('client-side guards stop before the server', () {
    test('disallowed role pair never calls createDirectConversation', () async {
      final result = await GetOrCreateConversationUseCase(repository)(
        const GetOrCreateConversationParams(
          currentUser: admin,
          otherUser: student,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.match(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('admin → student must be rejected'),
      );
      expect(functions.calls, isEmpty);
    });

    test('offline write fails without reaching the server', () async {
      network.connected = false;

      final result = await repository.sendMessage(
        conversationId: 'a_b',
        messageId: 'msgId_0123456789',
        type: ChatMessageType.text,
        text: 'hi',
      );

      expect(result, const Left<Failure, Unit>(NetworkFailure()));
      expect(functions.calls, isEmpty);
    });

    test('blank edit is rejected locally', () async {
      final result = await EditChatMessageUseCase(repository)(
        const EditChatMessageParams(
          conversationId: 'a_b',
          messageId: 'm1',
          text: '   ',
        ),
      );

      expect(result.isLeft(), isTrue);
      expect(functions.calls, isEmpty);
    });
  });

  group('WA-11 / WA-10 group identity compatibility', () {
    test('halaqa group id remains deterministic', () {
      expect(
        HalaqaGroupChatContract.conversationIdForHalaqa('h1'),
        'halaqa_group_h1',
      );
      expect(
        HalaqaGroupChatContract.isHalaqaGroupConversationId('halaqa_group_h1'),
        isTrue,
      );
    });
  });
}

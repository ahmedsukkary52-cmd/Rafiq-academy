import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';

class _FakeChatRepository implements ChatRepository {
  int getOrCreateCalls = 0;
  Either<Failure, ConversationEntity> getOrCreateResult = Left(
    ServerFailure('unset'),
  );

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  }) async {
    getOrCreateCalls++;
    return getOrCreateResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const teacher = ChatParticipantEntity(
    uid: 't1',
    name: 'معلم',
    role: AppRoles.teacher,
  );
  const student = ChatParticipantEntity(
    uid: 's1',
    name: 'طالب',
    role: AppRoles.student,
  );
  const parent = ChatParticipantEntity(
    uid: 'p1',
    name: 'ولي',
    role: AppRoles.parent,
  );
  const supervisor = ChatParticipantEntity(
    uid: 'sv1',
    name: 'مشرف',
    role: AppRoles.supervisor,
  );

  group('GetOrCreateConversationUseCase', () {
    test('rejects teacher↔parent without calling repository', () async {
      final repo = _FakeChatRepository();
      final useCase = GetOrCreateConversationUseCase(repo);

      final result = await useCase(
        const GetOrCreateConversationParams(
          currentUser: teacher,
          otherUser: parent,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('expected Left'),
      );
      expect(repo.getOrCreateCalls, 0);
    });

    test('allows teacher↔student and forwards to repository', () async {
      const conversation = ConversationEntity(
        id: 's1_t1',
        participants: [teacher, student],
        unreadCount: 0,
      );
      final repo = _FakeChatRepository()
        ..getOrCreateResult = const Right(conversation);
      final useCase = GetOrCreateConversationUseCase(repo);

      final result = await useCase(
        const GetOrCreateConversationParams(
          currentUser: teacher,
          otherUser: student,
        ),
      );

      expect(result, const Right(conversation));
      expect(repo.getOrCreateCalls, 1);
    });

    test('allows teacher↔supervisor', () async {
      const conversation = ConversationEntity(
        id: 'sv1_t1',
        participants: [teacher, supervisor],
        unreadCount: 0,
      );
      final repo = _FakeChatRepository()
        ..getOrCreateResult = const Right(conversation);
      final useCase = GetOrCreateConversationUseCase(repo);

      final result = await useCase(
        const GetOrCreateConversationParams(
          currentUser: teacher,
          otherUser: supervisor,
        ),
      );

      expect(result.isRight(), isTrue);
      expect(repo.getOrCreateCalls, 1);
    });

    test('surfaces repository failure for allowed pairs', () async {
      final repo = _FakeChatRepository()
        ..getOrCreateResult = const Left(ServerFailure('deny'));
      final useCase = GetOrCreateConversationUseCase(repo);

      final result = await useCase(
        const GetOrCreateConversationParams(
          currentUser: teacher,
          otherUser: student,
        ),
      );

      expect(result, const Left(ServerFailure('deny')));
      expect(repo.getOrCreateCalls, 1);
    });
  });
}

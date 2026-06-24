import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';

@LazySingleton(as: ChatRepository)
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDatasource remoteDatasource;
  final NetworkInfo networkInfo;

  const ChatRepositoryImpl({
    required this.remoteDatasource,
    required this.networkInfo,
  });

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations(
      String uid,
      ) {
    return remoteDatasource
        .watchConversations(uid)
        .map<Either<Failure, List<ConversationEntity>>>((list) => Right(list))
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
      String conversationId,
      ) {
    return remoteDatasource
        .watchMessages(conversationId)
        .map<Either<Failure, List<MessageEntity>>>((list) => Right(list))
        .handleError((e) => Left(ServerFailure(e.toString())));
  }

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final conversation = await remoteDatasource.getOrCreateConversation(
        currentUser: currentUser,
        otherUser: otherUser,
      );
      return Right(conversation);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        text: text,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String uid,
  }) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      await remoteDatasource.markConversationAsRead(
        conversationId: conversationId,
        uid: uid,
      );
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
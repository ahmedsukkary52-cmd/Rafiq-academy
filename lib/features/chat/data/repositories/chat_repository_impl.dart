import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
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

  static const _accessLost = 'لم يعد لديك وصول إلى هذه المحادثة';

  /// Firestore stream errors become Left events. Stream.handleError would
  /// swallow them without emitting and leave the UI stuck on loading.
  StreamTransformer<List<T>, Either<Failure, List<T>>> _toEither<T>() =>
      StreamTransformer.fromHandlers(
        handleData: (list, sink) => sink.add(Right(List<T>.from(list))),
        handleError: (error, stackTrace, sink) {
          final denied =
              error is FirebaseException && error.code == 'permission-denied';
          sink.add(
            Left(ServerFailure(denied ? _accessLost : error.toString())),
          );
        },
      );

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await run());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchConversations(
    String uid,
  ) => remoteDatasource.watchConversations(uid).transform(_toEither());

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchAllConversations({
    required String observerUid,
  }) => remoteDatasource
      .watchAllConversations(observerUid: observerUid)
      .transform(_toEither());

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId, {
    required int limit,
  }) => remoteDatasource
      .watchMessages(conversationId, limit: limit)
      .transform(_toEither());

  @override
  Future<Either<Failure, ConversationEntity>> getOrCreateConversation({
    required ChatParticipantEntity currentUser,
    required ChatParticipantEntity otherUser,
  }) => _guard(
    () => remoteDatasource.getOrCreateConversation(
      currentUser: currentUser,
      otherUser: otherUser,
    ),
  );

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
  }) => _guard(() async {
    await remoteDatasource.sendMessage(
      conversationId: conversationId,
      messageId: messageId,
      type: type,
      text: text,
      media: media,
    );
    return unit;
  });

  @override
  Future<Either<Failure, ChatUploadTask>> startAttachmentUpload({
    required String conversationId,
    required String messageId,
    required String uploaderId,
    required ChatAttachmentDraft draft,
  }) => _guard(
    () async => remoteDatasource.startAttachmentUpload(
      conversationId: conversationId,
      messageId: messageId,
      uploaderId: uploaderId,
      draft: draft,
    ),
  );

  @override
  Future<Either<Failure, Unit>> discardUpload(String storagePath) async {
    try {
      await remoteDatasource.deleteUpload(storagePath);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> downloadMedia(ChatMediaEntity media) =>
      _guard(() => remoteDatasource.downloadMedia(media));

  @override
  Future<Either<Failure, Unit>> markConversationAsRead({
    required String conversationId,
    required String uid,
  }) => _guard(() async {
    await remoteDatasource.markConversationAsRead(
      conversationId: conversationId,
      uid: uid,
    );
    return unit;
  });

  @override
  Future<Either<Failure, ChatParticipantEntity>> getParticipant(String uid) =>
      _guard(() => remoteDatasource.getParticipant(uid));

  @override
  Future<Either<Failure, Unit>> softDeleteMessage({
    required String conversationId,
    required String messageId,
  }) => _guard(() async {
    await remoteDatasource.softDeleteMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) => _guard(() async {
    await remoteDatasource.editMessage(
      conversationId: conversationId,
      messageId: messageId,
      text: text,
    );
    return unit;
  });
}

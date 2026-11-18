import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_info.dart';
import '../../../../shared/domain/contact_info_policy.dart';
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
    String uid, {
    int? limit,
  }) => remoteDatasource
      .watchConversations(uid, limit: limit)
      .transform(_toEither());

  @override
  Stream<Either<Failure, List<ConversationEntity>>> watchAllConversations({
    required String observerUid,
    int? limit,
  }) => remoteDatasource
      .watchAllConversations(observerUid: observerUid, limit: limit)
      .transform(_toEither());

  @override
  Future<Either<Failure, List<ConversationEntity>>> fetchConversationsAfter({
    String? participantUid,
    required String viewerUid,
    required String afterConversationId,
    required int limit,
  }) => _guard(
    () => remoteDatasource.fetchConversationsAfter(
      participantUid: participantUid,
      viewerUid: viewerUid,
      afterConversationId: afterConversationId,
      limit: limit,
    ),
  );

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId, {
    required int limit,
  }) => remoteDatasource
      .watchMessages(conversationId, limit: limit)
      .transform(_toEither());

  @override
  Future<Either<Failure, List<MessageEntity>>> fetchMessagesBefore({
    required String conversationId,
    required String beforeMessageId,
    required int limit,
  }) =>
      _guard(
        () => remoteDatasource.fetchMessagesBefore(
          conversationId: conversationId,
          beforeMessageId: beforeMessageId,
          limit: limit,
        ),
      );

  @override
  Future<Either<Failure, List<MessageEntity>>> fetchMessagesByIds({
    required String conversationId,
    required List<String> messageIds,
  }) =>
      _guard(
        () => remoteDatasource.fetchMessagesByIds(
          conversationId: conversationId,
          messageIds: messageIds,
        ),
      );
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
    String? replyToMessageId,
  }) async {
    final violation =
        contactInfoViolation(text) ?? contactInfoViolation(media?.fileName);
    if (violation != null) return Left(ValidationFailure(violation));
    return _guard(() async {
      await remoteDatasource.sendMessage(
        conversationId: conversationId,
        messageId: messageId,
        type: type,
        text: text,
        media: media,
        replyToMessageId: replyToMessageId,
      );
      return unit;
    });
  }

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
  }) async {
    final violation = contactInfoViolation(text);
    if (violation != null) return Left(ValidationFailure(violation));
    return _guard(() async {
      await remoteDatasource.editMessage(
        conversationId: conversationId,
        messageId: messageId,
        text: text,
      );
      return unit;
    });
  }
}

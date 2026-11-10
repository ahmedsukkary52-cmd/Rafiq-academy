import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/policies/chat_media_policy.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_event.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_room_state.dart';

class FakeUploadTask implements ChatUploadTask {
  final progressCtrl = StreamController<double>.broadcast();
  final done = Completer<void>();
  bool cancelled = false;

  @override
  final String storagePath;

  FakeUploadTask(this.storagePath);

  @override
  Stream<double> get progress => progressCtrl.stream;

  @override
  Future<void> get completion => done.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!done.isCompleted) {
      done.completeError(const ServerException('تم إلغاء الرفع'));
    }
  }
}

class FakeChatRepository implements ChatRepository {
  final messages =
      StreamController<Either<Failure, List<MessageEntity>>>.broadcast();
  final watchLimits = <int>[];
  final sends = <({String messageId, ChatMessageType type, String text, ChatSendMedia? media})>[];
  final replyIds = <String?>[];
  final uploads = <FakeUploadTask>[];
  final discarded = <String>[];
  final List<Either<Failure, Unit>> sendResults = [];
  Either<Failure, Unit> editResult = const Right(unit);
  Either<Failure, Unit> deleteResult = const Right(unit);
  int markReadCalls = 0;

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId, {
    required int limit,
  }) {
    watchLimits.add(limit);
    return messages.stream;
  }

  @override
  Future<Either<Failure, Unit>> sendMessage({
    required String conversationId,
    required String messageId,
    required ChatMessageType type,
    required String text,
    ChatSendMedia? media,
    String? replyToMessageId,
  }) async {
    sends.add((messageId: messageId, type: type, text: text, media: media));
    replyIds.add(replyToMessageId);
    return sendResults.isEmpty ? const Right(unit) : sendResults.removeAt(0);
  }

  @override
  Future<Either<Failure, ChatUploadTask>> startAttachmentUpload({
    required String conversationId,
    required String messageId,
    required String uploaderId,
    required ChatAttachmentDraft draft,
  }) async {
    final task = FakeUploadTask(
      ChatMediaPolicy.storagePath(
        conversationId: conversationId,
        messageId: messageId,
        draft: draft,
      ),
    );
    uploads.add(task);
    return Right(task);
  }

  @override
  Future<Either<Failure, Unit>> discardUpload(String storagePath) async {
    discarded.add(storagePath);
    return const Right(unit);
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
  Future<Either<Failure, Unit>> softDeleteMessage({
    required String conversationId,
    required String messageId,
  }) async => deleteResult;

  @override
  Future<Either<Failure, Unit>> editMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) async => editResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChatRoomBloc buildBloc(FakeChatRepository repo) => ChatRoomBloc(
  WatchMessagesUseCase(repo),
  SendMessageUseCase(repo),
  MarkConversationAsReadUseCase(repo),
  SoftDeleteChatMessageUseCase(repo),
  EditChatMessageUseCase(repo),
  StartChatUploadUseCase(repo),
  DiscardChatUploadUseCase(repo),
  'c1',
  't1',
);

MessageEntity msg(String id, {String sender = 's1', int minute = 0}) =>
    MessageEntity(
      id: id,
      conversationId: 'c1',
      senderId: sender,
      text: 'نص $id',
      sentAt: DateTime(2026, 10, 6, 12, minute),
    );

const imageDraft = ChatAttachmentDraft(
  type: ChatMessageType.image,
  localPath: '/tmp/a.jpg',
  fileName: 'صورة.jpg',
  contentType: 'image/jpeg',
  sizeBytes: 2048,
);

void main() {
  late FakeChatRepository repo;
  late ChatRoomBloc bloc;

  Future<ChatRoomState> until(bool Function(ChatRoomState s) test) async {
    if (test(bloc.state)) return bloc.state;
    return bloc.stream.firstWhere(test).timeout(const Duration(seconds: 2));
  }

  Future<void> loaded(List<MessageEntity> list) async {
    await Future<void>.delayed(Duration.zero);
    repo.messages.add(Right(list));
    await until(
      (s) => s.messagesStatus == SectionStatus.loaded && s.messages.length == list.length,
    );
  }

  setUp(() {
    repo = FakeChatRepository();
    bloc = buildBloc(repo);
  });

  tearDown(() async {
    await bloc.close();
    await repo.messages.close();
  });

  test('text send: outbox until the stream confirms; deduped by message id', () async {
    await loaded(const []);
    bloc.add(const SendMessageRequestedEvent('  السلام عليكم '));
    final sent = await until(
      (s) => s.outbox.isNotEmpty && s.outbox.single.status == ChatOutgoingStatus.sent,
    );
    final id = sent.outbox.single.messageId;
    expect(ChatMessageIds.isValid(id), isTrue);
    expect(repo.sends.single.text, 'السلام عليكم');
    expect(sent.pendingOutbox, hasLength(1));

    repo.messages.add(Right([msg(id, sender: 't1')]));
    final confirmed = await until((s) => s.messages.length == 1);
    expect(confirmed.outbox, isEmpty);
    expect(confirmed.pendingOutbox, isEmpty);
  });

  test('reply: quoted id is sent and kept on retry', () async {
    await loaded([msg('a')]);
    repo.sendResults.add(const Left(ServerFailure('unavailable')));
    bloc.add(const SendMessageRequestedEvent('نعم', replyToMessageId: 'a'));
    final failed = await until(
      (s) => s.outbox.isNotEmpty && s.outbox.single.status == ChatOutgoingStatus.failed,
    );
    bloc.add(RetryOutgoingRequestedEvent(failed.outbox.single.messageId));
    await until(
      (s) => s.outbox.isNotEmpty && s.outbox.single.status == ChatOutgoingStatus.sent,
    );
    expect(repo.replyIds, ['a', 'a']);
    expect(repo.sends[0].messageId, repo.sends[1].messageId);
  });

  test('failed send keeps the item; retry re-sends with the same id', () async {
    await loaded(const []);
    repo.sendResults.add(const Left(ServerFailure('تعذر إرسال الرسالة')));
    bloc.add(const SendMessageRequestedEvent('مرحبا'));
    final failed = await until(
      (s) => s.outbox.isNotEmpty && s.outbox.single.status == ChatOutgoingStatus.failed,
    );
    expect(failed.outbox.single.error, 'تعذر إرسال الرسالة');
    final id = failed.outbox.single.messageId;

    bloc.add(RetryOutgoingRequestedEvent(id));
    await until((s) => s.outbox.single.status == ChatOutgoingStatus.sent);
    expect(repo.sends.map((s) => s.messageId), [id, id]);
  });

  test('invalid text is rejected locally (empty / too long)', () async {
    await loaded(const []);
    bloc.add(SendMessageRequestedEvent('ا' * 4001));
    final s = await until((s) => s.actionError != null);
    expect(s.actionError, contains('4000'));
    expect(repo.sends, isEmpty);
    expect(s.outbox, isEmpty);
  });

  test('attachment: progress, then message created only after upload completes', () async {
    await loaded(const []);
    bloc.add(const SendAttachmentRequestedEvent(imageDraft));
    await until((s) => s.outbox.isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    final task = repo.uploads.single;

    task.progressCtrl.add(0.4);
    final progressed = await until((s) => s.outbox.single.progress == 0.4);
    expect(progressed.outbox.single.status, ChatOutgoingStatus.uploading);
    expect(repo.sends, isEmpty, reason: 'no message before the upload exists');

    task.done.complete();
    await until((s) => s.outbox.single.status == ChatOutgoingStatus.sent);
    final send = repo.sends.single;
    expect(send.type, ChatMessageType.image);
    expect(send.media!.storagePath, task.storagePath);
    expect(send.media!.storagePath, startsWith('chat_media/c1/${send.messageId}/'));
    expect(send.media!.fileName, 'صورة.jpg');
  });

  test('upload failure: no send; retry discards the partial object and re-uploads', () async {
    await loaded(const []);
    bloc.add(const SendAttachmentRequestedEvent(imageDraft));
    await until((s) => s.outbox.isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    repo.uploads.single.done.completeError(const ServerException('تعذر رفع الملف. تحقق من الاتصال.'));
    final failed = await until(
      (s) => s.outbox.single.status == ChatOutgoingStatus.failed,
    );
    expect(failed.outbox.single.error, 'تعذر رفع الملف. تحقق من الاتصال.');
    expect(repo.sends, isEmpty);

    bloc.add(RetryOutgoingRequestedEvent(failed.outbox.single.messageId));
    await until((s) => repo.uploads.length == 2 && s.outbox.single.status == ChatOutgoingStatus.uploading);
    expect(repo.discarded, [repo.uploads.first.storagePath]);
    repo.uploads.last.done.complete();
    await until((s) => s.outbox.single.status == ChatOutgoingStatus.sent);
    expect(repo.sends.single.messageId, failed.outbox.single.messageId);
  });

  test('retry after a failed send does not re-upload (idempotent re-send)', () async {
    await loaded(const []);
    repo.sendResults.add(const Left(ServerFailure('unavailable')));
    bloc.add(const SendAttachmentRequestedEvent(imageDraft));
    await until((s) => s.outbox.isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    repo.uploads.single.done.complete();
    final failed = await until((s) => s.outbox.single.status == ChatOutgoingStatus.failed);
    expect(failed.outbox.single.uploadedPath, isNotNull);

    bloc.add(RetryOutgoingRequestedEvent(failed.outbox.single.messageId));
    await until((s) => s.outbox.single.status == ChatOutgoingStatus.sent);
    expect(repo.uploads, hasLength(1));
    expect(repo.sends, hasLength(2));
  });

  test('cancel during upload: task cancelled, orphan discarded, nothing sent', () async {
    await loaded(const []);
    bloc.add(const SendAttachmentRequestedEvent(imageDraft));
    final s = await until((s) => s.outbox.isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    bloc.add(CancelOutgoingRequestedEvent(s.outbox.single.messageId));
    await until((s) => s.outbox.isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.uploads.single.cancelled, isTrue);
    expect(repo.discarded, [repo.uploads.single.storagePath]);
    expect(repo.sends, isEmpty);
  });

  test('unsupported attachment is refused before any upload', () async {
    await loaded(const []);
    bloc.add(const SendAttachmentRequestedEvent(ChatAttachmentDraft(
      type: ChatMessageType.image,
      localPath: '/tmp/a.gif',
      fileName: 'a.gif',
      contentType: '',
      sizeBytes: 10,
    )));
    final s = await until((s) => s.actionError != null);
    expect(s.actionError, contains('JPG'));
    expect(repo.uploads, isEmpty);
  });

  test('pagination grows the window only when a full page was returned', () async {
    await loaded(List.generate(10, (i) => msg('m$i', minute: i)));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.watchLimits, [ChatRoomState.pageSize]);

    repo.messages.add(Right(List.generate(30, (i) => msg('p$i', minute: i))));
    await until((s) => s.messages.length == 30);
    expect(bloc.state.hasMore, isTrue);
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.loadingOlder);
    for (var i = 0; i < 100 && repo.watchLimits.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(repo.watchLimits.last, 60);
    repo.messages.add(Right(List.generate(45, (i) => msg('q$i', minute: i))));
    final s = await until((s) => s.messages.length == 45 && !s.loadingOlder);
    expect(s.hasMore, isFalse);
  });

  test('unread reset once per new incoming message while the room is open', () async {
    await Future<void>.delayed(Duration.zero);
    expect(repo.markReadCalls, 1);
    await loaded([msg('a', minute: 1)]);
    await Future<void>.delayed(Duration.zero);
    expect(repo.markReadCalls, 1, reason: 'first snapshot is covered by open');

    repo.messages.add(Right([msg('a', minute: 1), msg('b', minute: 2)]));
    await until((s) => s.messages.length == 2);
    await Future<void>.delayed(Duration.zero);
    expect(repo.markReadCalls, 2);

    repo.messages.add(Right([msg('a', minute: 1), msg('b', minute: 2), msg('c', sender: 't1', minute: 3)]));
    await until((s) => s.messages.length == 3);
    await Future<void>.delayed(Duration.zero);
    expect(repo.markReadCalls, 2, reason: 'own message does not reset');
  });

  test('stream error keeps history and recovers on retry', () async {
    await loaded([msg('a')]);
    repo.messages.add(const Left(ServerFailure('لم يعد لديك وصول إلى هذه المحادثة')));
    final errored = await until((s) => s.messagesStatus == SectionStatus.error);
    expect(errored.messages, hasLength(1));
    expect(errored.messagesError, 'لم يعد لديك وصول إلى هذه المحادثة');

    bloc.add(const WatchMessagesStartedEvent());
    await until((s) => s.messagesStatus == SectionStatus.loading);
    repo.messages.add(Right([msg('a')]));
    await until((s) => s.messagesStatus == SectionStatus.loaded);
  });

  test('edit / delete failures surface as action errors', () async {
    await loaded([msg('a', sender: 't1')]);
    repo.editResult = const Left(ServerFailure('غير مسموح بتعديل هذه الرسالة'));
    bloc.add(const EditMessageRequestedEvent('a', 'جديد'));
    var s = await until((s) => s.actionError != null && !s.actionInProgress);
    expect(s.actionError, 'غير مسموح بتعديل هذه الرسالة');

    bloc.add(const ActionErrorDismissedEvent());
    await until((s) => s.actionError == null);
    repo.deleteResult = const Left(ServerFailure('غير مسموح بحذف هذه الرسالة'));
    bloc.add(const SoftDeleteMessageRequestedEvent('a'));
    s = await until((s) => s.actionError != null && !s.actionInProgress);
    expect(s.actionError, 'غير مسموح بحذف هذه الرسالة');
  });

  test('closing the room cancels in-flight uploads and removes orphans', () async {
    await loaded(const []);
    bloc.add(const SendAttachmentRequestedEvent(imageDraft));
    await until((s) => s.outbox.isNotEmpty);
    await Future<void>.delayed(Duration.zero);
    final task = repo.uploads.single;
    await bloc.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(task.cancelled, isTrue);
    expect(repo.discarded, [task.storagePath]);
    expect(repo.sends, isEmpty);
  });
}

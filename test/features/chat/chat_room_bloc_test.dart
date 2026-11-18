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

typedef OlderPageResult = Either<Failure, List<MessageEntity>>;

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
  final olderFetches = <({String beforeMessageId, int limit})>[];
  final List<Future<OlderPageResult> Function()> olderResultFactories = [];
  final sends = <({String messageId, ChatMessageType type, String text, ChatSendMedia? media})>[];
  final replyIds = <String?>[];
  final uploads = <FakeUploadTask>[];
  final discarded = <String>[];
  final List<Either<Failure, Unit>> sendResults = [];
  Either<Failure, Unit> editResult = const Right(unit);
  Either<Failure, Unit> deleteResult = const Right(unit);
  int markReadCalls = 0;
  final byIdFetches = <List<String>>[];
  final List<Future<Either<Failure, List<MessageEntity>>> Function()>
      byIdResultFactories = [];

  void enqueueOlder(OlderPageResult result) {
    olderResultFactories.add(() async => result);
  }

  void enqueueOlderDelayed(OlderPageResult result, Duration delay) {
    olderResultFactories.add(() => Future.delayed(delay, () => result));
  }

  void enqueueByIds(Either<Failure, List<MessageEntity>> result) {
    byIdResultFactories.add(() async => result);
  }

  void enqueueByIdsDelayed(
    Either<Failure, List<MessageEntity>> result,
    Duration delay,
  ) {
    byIdResultFactories.add(() => Future.delayed(delay, () => result));
  }

  @override
  Stream<Either<Failure, List<MessageEntity>>> watchMessages(
    String conversationId, {
    required int limit,
  }) {
    watchLimits.add(limit);
    return messages.stream;
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> fetchMessagesBefore({
    required String conversationId,
    required String beforeMessageId,
    required int limit,
  }) async {
    olderFetches.add((beforeMessageId: beforeMessageId, limit: limit));
    if (olderResultFactories.isEmpty) return const Right([]);
    return olderResultFactories.removeAt(0)();
  }

  @override
  Future<Either<Failure, List<MessageEntity>>> fetchMessagesByIds({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    byIdFetches.add(List<String>.from(messageIds));
    if (byIdResultFactories.isEmpty) {
      return Right([for (final id in messageIds) msg(id)]);
    }
    return byIdResultFactories.removeAt(0)();
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
  FetchOlderMessagesUseCase(repo),
  FetchMessagesByIdsUseCase(repo),
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

  test('short initial page marks older history exhausted', () async {
    await loaded(List.generate(10, (i) => msg('m$i', minute: i)));
    expect(bloc.state.hasMore, isFalse);
    expect(repo.watchLimits, [ChatRoomState.pageSize]);
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.olderFetches, isEmpty);
  });

  test('BASMA-103: load older uses cursor fetch; live watch limit stays fixed', () async {
    expect(ChatRoomState.pageSize, 30);
    final live = List.generate(30, (i) => msg('w$i', minute: i + 30));
    await loaded(live);
    expect(repo.watchLimits, [30]);
    expect(bloc.state.hasMore, isTrue);

    final older = List.generate(30, (i) => msg('o$i', minute: i));
    repo.enqueueOlder(Right(older));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    final s = await until(
      (st) => st.messages.length == 60 && !st.loadingOlder,
    );
    expect(repo.watchLimits, [30], reason: 'live listener must not grow');
    expect(bloc.state.limit, 30);
    expect(repo.olderFetches, [
      (beforeMessageId: 'w0', limit: 30),
    ]);
    expect(s.messages.first.id, 'o0');
    expect(s.messages.last.id, 'w29');
    expect(s.hasMore, isTrue);
  });

  test('BASMA-103 D2 contract: older page must not grow the live watch limit', () async {
    await loaded(List.generate(30, (i) => msg('w$i', minute: i + 30)));
    repo.enqueueOlder(Right(List.generate(15, (i) => msg('o$i', minute: i))));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    final s = await until((st) => st.messages.length == 45 && !st.loadingOlder);
    expect(repo.watchLimits, everyElement(ChatRoomState.pageSize));
    expect(repo.olderFetches, hasLength(1));
    expect(s.hasMore, isFalse);
    expect(s.limit, ChatRoomState.pageSize);
  });

  test('BASMA-103: dedupe when older page overlaps live window', () async {
    await loaded(List.generate(30, (i) => msg('w$i', minute: i + 20)));
    // Overlap on w20..w24 plus true older rows.
    repo.enqueueOlder(Right([
      ...List.generate(10, (i) => msg('o$i', minute: i)),
      ...List.generate(5, (i) => msg('w${20 + i}', minute: 20 + i)),
    ]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    final s = await until((st) => !st.loadingOlder && st.messages.length > 30);
    final ids = s.messages.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.where((id) => id == 'w20'), hasLength(1));
  });

  test('BASMA-103: live arrives during older fetch; both retained', () async {
    await loaded(List.generate(30, (i) => msg('w$i', minute: i + 30)));
    repo.enqueueOlderDelayed(
      Right(List.generate(10, (i) => msg('o$i', minute: i))),
      const Duration(milliseconds: 40),
    );
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.loadingOlder);
    final livePlus = [
      ...List.generate(29, (i) => msg('w${i + 1}', minute: i + 31)),
      msg('new', minute: 100),
    ];
    repo.messages.add(Right(livePlus));
    await until((s) => s.messages.any((m) => m.id == 'new'));
    final done = await until(
      (s) => !s.loadingOlder && s.messages.any((m) => m.id == 'o0'),
    );
    expect(done.messages.any((m) => m.id == 'new'), isTrue);
    expect(done.messages.any((m) => m.id == 'o0'), isTrue);
    expect(repo.watchLimits, everyElement(30));
  });

  test('BASMA-103: deterministic order when timestamps tie', () async {
    final t = DateTime(2026, 10, 6, 12, 0);
    await loaded([
      MessageEntity(
        id: 'b',
        conversationId: 'c1',
        senderId: 's1',
        text: 'b',
        sentAt: t,
      ),
      MessageEntity(
        id: 'a',
        conversationId: 'c1',
        senderId: 's1',
        text: 'a',
        sentAt: t,
      ),
    ]);
    expect(bloc.state.messages.map((m) => m.id), ['a', 'b']);
  });

  test('BASMA-103: older-page failure then retry', () async {
    await loaded(List.generate(30, (i) => msg('w$i', minute: i + 30)));
    repo.enqueueOlder(
      const Left(ServerFailure('تعذر تحميل الرسائل القديمة')),
    );
    bloc.add(const LoadOlderMessagesRequestedEvent());
    final failed = await until(
      (s) => !s.loadingOlder && s.messagesError != null,
    );
    expect(failed.messages.length, 30);
    expect(failed.hasMore, isTrue);

    repo.enqueueOlder(Right(List.generate(5, (i) => msg('o$i', minute: i))));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    final ok = await until((s) => s.messages.length == 35 && !s.loadingOlder);
    expect(ok.messagesError, isNull);
    expect(ok.hasMore, isFalse);
  });

  test('BASMA-103: stream failure keeps already-loaded messages', () async {
    await loaded([msg('keep')]);
    repo.messages.add(const Left(ServerFailure('تعذر تحميل الرسائل')));
    final errored = await until((s) => s.messagesStatus == SectionStatus.error);
    expect(errored.messages.map((m) => m.id), ['keep']);
    expect(errored.loadingOlder, isFalse);
  });

  test('BASMA-103: repeated load-older while loading does not stack fetches', () async {
    await loaded(List.generate(30, (i) => msg('r$i', minute: i + 30)));
    repo.enqueueOlderDelayed(
      Right(List.generate(5, (i) => msg('o$i', minute: i))),
      const Duration(milliseconds: 80),
    );
    bloc.add(const LoadOlderMessagesRequestedEvent());
    bloc.add(const LoadOlderMessagesRequestedEvent());
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.loadingOlder);
    await until((s) => !s.loadingOlder);
    expect(repo.olderFetches, hasLength(1));
    expect(repo.watchLimits, [30]);
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

  test('edit of loaded older message updates buffer; live limit stays fixed', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(
      Right([msg('old1', sender: 't1', minute: 1), msg('old2', minute: 2)]),
    );
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old1'));

    final refreshed = MessageEntity(
      id: 'old1',
      conversationId: 'c1',
      senderId: 't1',
      text: 'محدث من الخادم',
      sentAt: DateTime(2026, 10, 6, 12, 1),
      editedAt: DateTime(2026, 10, 6, 13),
    );
    repo.enqueueByIds(Right([refreshed, msg('old2', minute: 2)]));
    bloc.add(const EditMessageRequestedEvent('old1', 'محدث محلي'));
    await until(
      (s) =>
          !s.actionInProgress &&
          s.messages.any((m) => m.id == 'old1' && m.text.contains('محدث')),
    );
    await until(
      (s) => s.messages.any((m) => m.id == 'old1' && m.text == 'محدث من الخادم'),
    );
    expect(repo.byIdFetches, isNotEmpty);
    expect(
      repo.byIdFetches.last,
      ['old1'],
      reason: 'edit must revalidate only the affected id, not the whole buffer',
    );
    expect(repo.watchLimits, everyElement(ChatRoomState.pageSize));
    expect(bloc.state.limit, ChatRoomState.pageSize);
    expect(bloc.state.messages.where((m) => m.id == 'old1'), hasLength(1));
  });

  test('soft-delete of loaded older message marks deleted and refreshes', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(Right([msg('old1', sender: 't1', minute: 1)]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old1'));

    final deleted = MessageEntity(
      id: 'old1',
      conversationId: 'c1',
      senderId: 't1',
      text: '',
      sentAt: DateTime(2026, 10, 6, 12, 1),
      deleted: true,
      deletedAt: DateTime(2026, 10, 6, 13),
      deletedBy: 't1',
    );
    repo.enqueueByIds(Right([deleted]));
    bloc.add(const SoftDeleteMessageRequestedEvent('old1'));
    await until(
      (s) => s.messages.any((m) => m.id == 'old1' && m.deleted),
    );
    for (var i = 0; i < 20 && repo.byIdFetches.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(repo.byIdFetches.last, ['old1']);
    expect(repo.watchLimits, everyElement(ChatRoomState.pageSize));
  });

  test('edit of one older message does not fetch sibling buffered ids', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(
      Right([
        for (var i = 0; i < 25; i++)
          msg('old$i', sender: i == 0 ? 't1' : 's1', minute: i),
      ]),
    );
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old0'));
    expect(bloc.state.messages.where((m) => m.id.startsWith('old')), hasLength(25));

    repo.enqueueByIds(
      Right([
        MessageEntity(
          id: 'old0',
          conversationId: 'c1',
          senderId: 't1',
          text: 'واحد فقط',
          sentAt: DateTime(2026, 10, 6, 12, 0),
          editedAt: DateTime(2026, 10, 6, 13),
        ),
      ]),
    );
    bloc.add(const EditMessageRequestedEvent('old0', 'واحد فقط'));
    await until(
      (s) => s.messages.any((m) => m.id == 'old0' && m.text == 'واحد فقط'),
    );
    for (var i = 0; i < 20 && repo.byIdFetches.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(repo.byIdFetches, hasLength(1));
    expect(repo.byIdFetches.single, ['old0']);
    expect(
      repo.byIdFetches.single,
      isNot(contains('old24')),
      reason: 'must not re-get the entire older buffer',
    );
  });

  test('stale buffer refresh is ignored after a newer refresh', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(Right([msg('old1', sender: 't1', minute: 1)]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old1'));

    final stale = MessageEntity(
      id: 'old1',
      conversationId: 'c1',
      senderId: 't1',
      text: 'قديم',
      sentAt: DateTime(2026, 10, 6, 12, 1),
    );
    final fresh = MessageEntity(
      id: 'old1',
      conversationId: 'c1',
      senderId: 't1',
      text: 'أحدث',
      sentAt: DateTime(2026, 10, 6, 12, 1),
      editedAt: DateTime(2026, 10, 6, 14),
    );
    repo.enqueueByIdsDelayed(Right([stale]), const Duration(milliseconds: 80));
    repo.enqueueByIds(Right([fresh]));
    bloc.add(const RefreshBufferedOutsideLiveRequestedEvent(['old1']));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const RefreshBufferedOutsideLiveRequestedEvent(['old1']));
    await until((s) => s.messages.any((m) => m.id == 'old1' && m.text == 'أحدث'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      bloc.state.messages.singleWhere((m) => m.id == 'old1').text,
      'أحدث',
      reason: 'stale refresh must not overwrite newer buffer state',
    );
  });

  test('concurrent refresh of two different older messages both apply', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(
      Right([
        msg('oldA', sender: 't1', minute: 1),
        msg('oldB', sender: 't1', minute: 2),
      ]),
    );
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'oldA'));

    final resultA = MessageEntity(
      id: 'oldA',
      conversationId: 'c1',
      senderId: 't1',
      text: 'نتيجة أ',
      sentAt: DateTime(2026, 10, 6, 12, 1),
      editedAt: DateTime(2026, 10, 6, 13),
    );
    final resultB = MessageEntity(
      id: 'oldB',
      conversationId: 'c1',
      senderId: 't1',
      text: 'نتيجة ب',
      sentAt: DateTime(2026, 10, 6, 12, 2),
      editedAt: DateTime(2026, 10, 6, 13),
    );
    // A is slow; B completes first — must not cancel A.
    repo.enqueueByIdsDelayed(Right([resultA]), const Duration(milliseconds: 80));
    repo.enqueueByIds(Right([resultB]));
    bloc.add(const RefreshBufferedOutsideLiveRequestedEvent(['oldA']));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const RefreshBufferedOutsideLiveRequestedEvent(['oldB']));
    await until((s) => s.messages.any((m) => m.id == 'oldB' && m.text == 'نتيجة ب'));
    await until((s) => s.messages.any((m) => m.id == 'oldA' && m.text == 'نتيجة أ'));
    expect(bloc.state.messages.singleWhere((m) => m.id == 'oldA').text, 'نتيجة أ');
    expect(bloc.state.messages.singleWhere((m) => m.id == 'oldB').text, 'نتيجة ب');
    expect(bloc.state.limit, ChatRoomState.pageSize);
  });

  test('closing room ignores pending buffer refresh', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(Right([msg('old1', sender: 't1', minute: 1)]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old1'));
    repo.enqueueByIdsDelayed(
      Right([
        MessageEntity(
          id: 'old1',
          conversationId: 'c1',
          senderId: 't1',
          text: 'بعد الإغلاق',
          sentAt: DateTime(2026, 10, 6, 12, 1),
        ),
      ]),
      const Duration(milliseconds: 50),
    );
    bloc.add(const RefreshBufferedOutsideLiveRequestedEvent(['old1']));
    await bloc.close();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(bloc.isClosed, isTrue);
  });

  test('live snapshot wins over concurrent buffer refresh for same id', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    // Overlap id: present in older page and later enters live window.
    repo.enqueueOlder(Right([msg('edge', sender: 't1', minute: 29)]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'edge'));

    repo.enqueueByIdsDelayed(
      Right([
        MessageEntity(
          id: 'edge',
          conversationId: 'c1',
          senderId: 't1',
          text: 'من التحديث المتأخر',
          sentAt: DateTime(2026, 10, 6, 12, 29),
        ),
      ]),
      const Duration(milliseconds: 60),
    );
    bloc.add(const RefreshBufferedOutsideLiveRequestedEvent(['edge']));
    // Live window now includes edge with authoritative text.
    final liveWithEdge = [
      ...List.generate(29, (i) => msg('l${i + 1}', minute: i + 31)),
      MessageEntity(
        id: 'edge',
        conversationId: 'c1',
        senderId: 't1',
        text: 'من اللايف',
        sentAt: DateTime(2026, 10, 6, 12, 29),
      ),
    ];
    repo.messages.add(Right(liveWithEdge));
    await until((s) => s.messages.any((m) => m.id == 'edge' && m.text == 'من اللايف'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      bloc.state.messages.singleWhere((m) => m.id == 'edge').text,
      'من اللايف',
      reason: 'live window must not be overwritten by stale outside-live refresh',
    );
    expect(bloc.state.limit, ChatRoomState.pageSize);
  });

  test('failed buffer refresh keeps optimistic edit text', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    repo.enqueueOlder(Right([msg('old1', sender: 't1', minute: 1)]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old1'));
    repo.enqueueByIds(const Left(ServerFailure('تعذر التحديث')));
    bloc.add(const EditMessageRequestedEvent('old1', 'نص تفاؤلي'));
    await until(
      (s) =>
          !s.actionInProgress &&
          s.messages.any((m) => m.id == 'old1' && m.text == 'نص تفاؤلي'),
    );
    // Refresh failure does not emit; poll the repo call list.
    for (var i = 0; i < 20 && repo.byIdFetches.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(repo.byIdFetches, isNotEmpty);
    expect(
      bloc.state.messages.singleWhere((m) => m.id == 'old1').text,
      'نص تفاؤلي',
    );
  });

  test('soft-delete optimistic clears reactions', () async {
    final live = List.generate(30, (i) => msg('l$i', minute: i + 30));
    await loaded(live);
    final withReaction = MessageEntity(
      id: 'old1',
      conversationId: 'c1',
      senderId: 't1',
      text: 'نص',
      sentAt: DateTime(2026, 10, 6, 12, 1),
      reactions: const {'u2': ChatReaction.heart},
    );
    repo.enqueueOlder(Right([withReaction]));
    bloc.add(const LoadOlderMessagesRequestedEvent());
    await until((s) => s.messages.any((m) => m.id == 'old1'));
    repo.enqueueByIds(
      Right([
        MessageEntity(
          id: 'old1',
          conversationId: 'c1',
          senderId: 't1',
          text: '',
          sentAt: DateTime(2026, 10, 6, 12, 1),
          deleted: true,
        ),
      ]),
    );
    bloc.add(const SoftDeleteMessageRequestedEvent('old1'));
    await until((s) => s.messages.any((m) => m.id == 'old1' && m.deleted));
    expect(
      bloc.state.messages.singleWhere((m) => m.id == 'old1').reactions,
      isEmpty,
    );
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

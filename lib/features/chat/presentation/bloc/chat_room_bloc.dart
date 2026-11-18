import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'chat_room_event.dart';
import 'chat_room_state.dart';

/// @injectable (وليس @singleton) لأن كل محادثة لازم يكون ليها instance
/// منفصلة. لو كانت singleton، فتح محادثة جديدة كان هيسيب رسائل المحادثة
/// القديمة ظاهرة لحظياً قبل ما الـ stream الجديد يوصل، وده bug مربك
/// للمستخدم (يشوف رسائل شخص تاني للحظة في محادثة غلط).
///
/// [conversationId] و [currentUserId] معمول عليهم @factoryParam، يعني
/// لازم تتبعتوا وقت الإنشاء الفعلي مش وقت التسجيل:
/// ```dart
/// sl<ChatRoomBloc>(param1: conversationId, param2: currentUserId)
/// ```
/// (injectable بيسمح بحد أقصى 2 factoryParam لكل كلاس)
///
/// Live window stays fixed at [ChatRoomState.pageSize]. Older history uses
/// cursor pages via [FetchOlderMessagesUseCase] (BASMA-103).
///
/// Edits/deletes outside the live window are applied optimistically then
/// revalidated for **that message id only** via [FetchMessagesByIdsUseCase]
/// (no full older-buffer getAll). Peer mutations of older messages are not
/// pushed without a conversation-level change signal (no unapproved backend
/// contract).
///
/// The outbox is in-memory: closing the room cancels in-flight uploads and
/// removes their orphan objects.
@injectable
class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final WatchMessagesUseCase watchMessages;
  final FetchOlderMessagesUseCase fetchOlderMessages;
  final FetchMessagesByIdsUseCase fetchMessagesByIds;
  final SendMessageUseCase sendMessage;
  final MarkConversationAsReadUseCase markConversationAsRead;
  final SoftDeleteChatMessageUseCase softDeleteMessage;
  final EditChatMessageUseCase editMessage;
  final StartChatUploadUseCase startUpload;
  final DiscardChatUploadUseCase discardUpload;

  final String conversationId;
  final String currentUserId;

  final Map<String, ChatUploadTask> _uploads = {};
  String? _lastMarkedIncomingId;

  /// Merged room buffer: live snapshot + older pages (keyed by message id).
  final Map<String, MessageEntity> _byId = {};

  /// Ids currently present in the fixed live listener window.
  final Set<String> _liveIds = {};

  /// Bumped on each older-page request so stale responses are ignored.
  int _olderRequestId = 0;

  /// Per-message generation for outside-live revalidation. A newer refresh for
  /// the **same** id supersedes older ones; refreshes for different ids do not
  /// cancel each other. Cleared / invalidated on [close] via [_roomRefreshEpoch].
  final Map<String, int> _bufferRefreshGenById = {};

  /// Bumped on [close] so every in-flight buffer refresh is discarded.
  int _roomRefreshEpoch = 0;

  ChatRoomBloc(
    this.watchMessages,
    this.fetchOlderMessages,
    this.fetchMessagesByIds,
    this.sendMessage,
    this.markConversationAsRead,
    this.softDeleteMessage,
    this.editMessage,
    this.startUpload,
    this.discardUpload,
    @factoryParam this.conversationId,
    @factoryParam this.currentUserId,
  ) : super(ChatRoomState.initial()) {
    on<WatchMessagesStartedEvent>(
      _onWatchMessagesStarted,
      transformer: restartable(),
    );
    on<LoadOlderMessagesRequestedEvent>(
      _onLoadOlder,
      transformer: droppable(),
    );
    on<RefreshBufferedOutsideLiveRequestedEvent>(
      _onRefreshBufferedOutsideLive,
      // Concurrent refreshes allowed; [_bufferRefreshRequestId] drops stale.
    );
    on<SendMessageRequestedEvent>(_onSendText, transformer: sequential());
    on<SendAttachmentRequestedEvent>(_onSendAttachment);
    on<RetryOutgoingRequestedEvent>(_onRetry);
    on<CancelOutgoingRequestedEvent>(_onCancel);
    on<ChatUploadProgressedEvent>(_onUploadProgressed);
    on<EditMessageRequestedEvent>(_onEdit, transformer: droppable());
    on<SoftDeleteMessageRequestedEvent>(_onDelete, transformer: droppable());
    on<ActionErrorDismissedEvent>(
      (_, emit) => emit(state.copyWith(actionError: null)),
    );

    add(const WatchMessagesStartedEvent());

    // تصفير عداد غير المقروء فور فتح المحادثة. عملية ثانوية (مجرد
    // badge)، فمش بنعرض حالتها في الـ state ولا بنوقف المستخدم لو فشلت.
    unawaited(_markRead());
  }

  Future<void> _markRead() => markConversationAsRead(
    MarkAsReadParams(conversationId: conversationId, uid: currentUserId),
  );

  static int _compareMessages(MessageEntity a, MessageEntity b) {
    final byTime = a.sentAt.compareTo(b.sentAt);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  }

  List<MessageEntity> _sortedMessages() {
    final list = _byId.values.toList()..sort(_compareMessages);
    return list;
  }

  void _applyLiveWindow(List<MessageEntity> live) {
    final nextLiveIds = {for (final m in live) m.id};
    for (final m in live) {
      _byId[m.id] = m;
    }
    // Messages that fall out of the fixed live window stay in the buffer so
    // the UI does not lose history the user already saw.
    _liveIds
      ..clear()
      ..addAll(nextLiveIds);
  }

  // ── Stream ────────────────────────────────────────────────────────────────

  Future<void> _onWatchMessagesStarted(
    WatchMessagesStartedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state.messagesStatus != SectionStatus.loaded) {
      emit(state.copyWith(
        messagesStatus: SectionStatus.loading,
        messagesError: null,
      ));
    }

    const liveLimit = ChatRoomState.pageSize;

    await emit.forEach(
      watchMessages(
        WatchMessagesParams(
          conversationId: conversationId,
          limit: liveLimit,
        ),
      ),
      onData: (either) => either.fold(
        (failure) => state.copyWith(
          messagesStatus: SectionStatus.error,
          messagesError: failure.message,
          loadingOlder: false,
        ),
        (messages) {
          _markReadIfNewIncoming(messages);
          final wasLoaded = state.messagesStatus == SectionStatus.loaded;
          _applyLiveWindow(messages);
          final merged = _sortedMessages();
          final ids = {for (final m in messages) m.id};
          // First live page shorter than the window ⇒ no older history.
          final hasMore = wasLoaded
              ? state.hasMoreOlder
              : messages.length >= liveLimit;
          return state.copyWith(
            messagesStatus: SectionStatus.loaded,
            messages: merged,
            messagesError: null,
            limit: liveLimit,
            // Keep loadingOlder — a concurrent cursor fetch may still be in flight.
            hasMoreOlder: hasMore,
            outbox: state.outbox
                .where((o) => !ids.contains(o.messageId))
                .toList(),
          );
        },
      ),
    );
  }

  /// Unread stays consistent while the room is open: every new incoming
  /// message resets this user's counter once.
  void _markReadIfNewIncoming(List<MessageEntity> messages) {
    if (messages.isEmpty) return;
    final last = messages.last;
    if (last.senderId == currentUserId || last.id == _lastMarkedIncomingId) {
      return;
    }
    final firstSnapshot = _lastMarkedIncomingId == null &&
        state.messagesStatus != SectionStatus.loaded;
    _lastMarkedIncomingId = last.id;
    if (!firstSnapshot) unawaited(_markRead());
  }

  Future<void> _onLoadOlder(
    LoadOlderMessagesRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state.loadingOlder ||
        state.messagesStatus != SectionStatus.loaded ||
        !state.hasMoreOlder ||
        state.messages.isEmpty) {
      return;
    }

    final beforeId = state.messages.first.id;
    final requestId = ++_olderRequestId;
    emit(state.copyWith(loadingOlder: true, messagesError: null));

    final result = await fetchOlderMessages(
      FetchOlderMessagesParams(
        conversationId: conversationId,
        beforeMessageId: beforeId,
        limit: ChatRoomState.pageSize,
      ),
    );

    if (isClosed || requestId != _olderRequestId) return;

    result.fold(
      (failure) {
        emit(state.copyWith(
          loadingOlder: false,
          messagesError: failure.message,
        ));
      },
      (page) {
        for (final m in page) {
          // Live window wins for concurrent edits of the same id.
          if (!_liveIds.contains(m.id)) {
            _byId[m.id] = m;
          } else {
            _byId.putIfAbsent(m.id, () => m);
          }
        }
        final exhausted = page.length < ChatRoomState.pageSize;
        emit(state.copyWith(
          messages: _sortedMessages(),
          loadingOlder: false,
          hasMoreOlder: !exhausted,
          messagesError: null,
        ));
      },
    );
  }

  // ── Outbox helpers ────────────────────────────────────────────────────────

  ChatOutgoingMessage? _find(String id) {
    for (final o in state.outbox) {
      if (o.messageId == id) return o;
    }
    return null;
  }

  void _update(
    Emitter<ChatRoomState> emit,
    String id,
    ChatOutgoingMessage Function(ChatOutgoingMessage) change,
  ) {
    if (emit.isDone || _find(id) == null) return;
    emit(state.copyWith(
      outbox: [
        for (final o in state.outbox) o.messageId == id ? change(o) : o,
      ],
    ));
  }

  void _remove(Emitter<ChatRoomState> emit, String id) {
    if (emit.isDone) return;
    emit(state.copyWith(
      outbox: state.outbox.where((o) => o.messageId != id).toList(),
    ));
  }

  String _pathFor(ChatOutgoingMessage item) =>
      item.uploadedPath ??
      ChatMediaPolicy.storagePath(
        conversationId: conversationId,
        messageId: item.messageId,
        draft: item.attachment!,
      );

  Future<void> _discard(String path) async {
    await discardUpload(path);
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _onSendText(
    SendMessageRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    final text = event.text.trim();
    final invalid = validateMessageText(text);
    if (invalid != null) {
      emit(state.copyWith(actionError: invalid));
      return;
    }
    final id = ChatMessageIds.generate();
    emit(state.copyWith(
      actionError: null,
      outbox: [
        ...state.outbox,
        ChatOutgoingMessage(
          messageId: id,
          type: ChatMessageType.text,
          text: text,
          status: ChatOutgoingStatus.sending,
          createdAt: DateTime.now(),
          replyToMessageId: event.replyToMessageId,
        ),
      ],
    ));
    await _deliver(emit, id);
  }

  Future<void> _onSendAttachment(
    SendAttachmentRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    final invalid = ChatMediaPolicy.validate(event.draft);
    if (invalid != null) {
      emit(state.copyWith(actionError: invalid));
      return;
    }
    final id = ChatMessageIds.generate();
    emit(state.copyWith(
      actionError: null,
      outbox: [
        ...state.outbox,
        ChatOutgoingMessage(
          messageId: id,
          type: event.draft.type,
          text: '',
          attachment: event.draft,
          status: ChatOutgoingStatus.uploading,
          createdAt: DateTime.now(),
        ),
      ],
    ));
    await _uploadThenSend(emit, id);
  }

  Future<void> _uploadThenSend(Emitter<ChatRoomState> emit, String id) async {
    final item = _find(id);
    final draft = item?.attachment;
    if (item == null || draft == null) return;
    _update(emit, id, (o) => o.copyWith(
      status: ChatOutgoingStatus.uploading,
      progress: 0,
      error: null,
    ));

    final started = await startUpload(StartChatUploadParams(
      conversationId: conversationId,
      messageId: id,
      uploaderId: currentUserId,
      draft: draft,
    ));
    final task = started.fold<ChatUploadTask?>((failure) {
      _update(emit, id, (o) => o.copyWith(
        status: ChatOutgoingStatus.failed,
        error: failure.message,
      ));
      return null;
    }, (t) => t);
    if (task == null) return;

    _uploads[id] = task;
    final sub = task.progress.listen(
      (p) => add(ChatUploadProgressedEvent(id, p)),
      onError: (Object _) {},
    );
    try {
      await task.completion;
    } on Object catch (e) {
      _update(emit, id, (o) => o.copyWith(
        status: ChatOutgoingStatus.failed,
        error: e is ServerException ? e.message : 'تعذر رفع الملف',
      ));
      return;
    } finally {
      await sub.cancel();
      _uploads.remove(id);
    }

    if (_find(id) == null) {
      // Cancelled after the bytes landed: no message will reference it.
      unawaited(_discard(task.storagePath));
      return;
    }
    _update(emit, id, (o) => o.copyWith(
      uploadedPath: task.storagePath,
      progress: 1,
      status: ChatOutgoingStatus.sending,
    ));
    await _deliver(emit, id);
  }

  Future<void> _deliver(Emitter<ChatRoomState> emit, String id) async {
    final item = _find(id);
    if (item == null) return;
    final draft = item.attachment;
    final result = await sendMessage(SendMessageParams(
      conversationId: conversationId,
      messageId: id,
      type: item.type,
      text: item.text,
      media: draft == null
          ? null
          : ChatSendMedia(
              storagePath: item.uploadedPath!,
              fileName: ChatMediaPolicy.displayFileName(draft.fileName),
              durationMs: draft.durationMs,
            ),
      replyToMessageId: item.replyToMessageId,
    ));
    result.fold(
      (failure) => _update(emit, id, (o) => o.copyWith(
        status: ChatOutgoingStatus.failed,
        error: failure.message,
      )),
      (_) {
        if (state.messages.any((m) => m.id == id)) {
          _remove(emit, id);
        } else {
          _update(emit, id, (o) => o.copyWith(
            status: ChatOutgoingStatus.sent,
            error: null,
          ));
        }
      },
    );
  }

  void _onUploadProgressed(
    ChatUploadProgressedEvent event,
    Emitter<ChatRoomState> emit,
  ) {
    final item = _find(event.messageId);
    if (item == null || item.status != ChatOutgoingStatus.uploading) return;
    _update(emit, event.messageId, (o) => o.copyWith(progress: event.progress));
  }

  Future<void> _onRetry(
    RetryOutgoingRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    final item = _find(event.messageId);
    if (item == null || !item.canRetry) return;
    if (item.attachment != null && item.uploadedPath == null) {
      // A partial object from the failed attempt would block re-upload
      // (no overwrite); the uploader may delete it while unsent.
      await _discard(_pathFor(item));
      await _uploadThenSend(emit, item.messageId);
      return;
    }
    _update(emit, item.messageId, (o) => o.copyWith(
      status: ChatOutgoingStatus.sending,
      error: null,
    ));
    await _deliver(emit, item.messageId);
  }

  Future<void> _onCancel(
    CancelOutgoingRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    final item = _find(event.messageId);
    if (item == null || !item.canCancel) return;
    _remove(emit, item.messageId);
    final task = _uploads.remove(item.messageId);
    if (task != null) await task.cancel();
    if (item.attachment != null) await _discard(_pathFor(item));
  }

  // ── Edit / delete ─────────────────────────────────────────────────────────

  MessageEntity _withEditedText(MessageEntity m, String text) => MessageEntity(
        id: m.id,
        conversationId: m.conversationId,
        senderId: m.senderId,
        type: m.type,
        text: text,
        media: m.media,
        sentAt: m.sentAt,
        editedAt: DateTime.now(),
        deleted: m.deleted,
        deletedAt: m.deletedAt,
        deletedBy: m.deletedBy,
        replyTo: m.replyTo,
        reactions: m.reactions,
        hasLink: m.hasLink,
      );

  MessageEntity _withSoftDeleted(MessageEntity m) => MessageEntity(
        id: m.id,
        conversationId: m.conversationId,
        senderId: m.senderId,
        type: m.type,
        text: '',
        media: null,
        sentAt: m.sentAt,
        editedAt: m.editedAt,
        deleted: true,
        deletedAt: DateTime.now(),
        deletedBy: currentUserId,
        replyTo: m.replyTo,
        // Match MessageModel.fromFirestore soft-delete presentation.
        reactions: const {},
        hasLink: false,
      );

  Future<void> _onEdit(
    EditMessageRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    emit(state.copyWith(actionInProgress: true, actionError: null));
    final result = await editMessage(EditChatMessageParams(
      conversationId: conversationId,
      messageId: event.messageId,
      text: event.text,
    ));
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(state.copyWith(
          actionInProgress: false,
          actionError: failure.message,
        ));
      },
      (_) {
        final existing = _byId[event.messageId];
        if (existing != null) {
          _byId[event.messageId] = _withEditedText(existing, event.text);
        }
        emit(state.copyWith(
          actionInProgress: false,
          actionError: null,
          messages: _sortedMessages(),
        ));
        // Live window will also update via snapshots; older buffer needs a
        // single-id revalidation (not a full older-buffer getAll).
        if (!_liveIds.contains(event.messageId)) {
          add(RefreshBufferedOutsideLiveRequestedEvent([event.messageId]));
        }
      },
    );
  }

  Future<void> _onDelete(
    SoftDeleteMessageRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    emit(state.copyWith(actionInProgress: true, actionError: null));
    final result = await softDeleteMessage(SoftDeleteChatMessageParams(
      conversationId: conversationId,
      messageId: event.messageId,
    ));
    if (isClosed) return;
    result.fold(
      (failure) {
        emit(state.copyWith(
          actionInProgress: false,
          actionError: failure.message,
        ));
      },
      (_) {
        final existing = _byId[event.messageId];
        if (existing != null) {
          _byId[event.messageId] = _withSoftDeleted(existing);
        }
        emit(state.copyWith(
          actionInProgress: false,
          actionError: null,
          messages: _sortedMessages(),
        ));
        if (!_liveIds.contains(event.messageId)) {
          add(RefreshBufferedOutsideLiveRequestedEvent([event.messageId]));
        }
      },
    );
  }

  Future<void> _onRefreshBufferedOutsideLive(
    RefreshBufferedOutsideLiveRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) async {
    // Only the requested ids — never the entire older buffer.
    final ids = <String>[
      for (final id in event.messageIds)
        if (id.trim().isNotEmpty &&
            _byId.containsKey(id) &&
            !_liveIds.contains(id))
          id.trim(),
    ];
    if (ids.isEmpty) return;

    final epoch = _roomRefreshEpoch;
    // Independent generation per id: concurrent refreshes of different
    // messages do not cancel each other; only a newer refresh of the same id
    // supersedes an older one.
    final startedGen = <String, int>{};
    for (final id in ids) {
      final next = (_bufferRefreshGenById[id] ?? 0) + 1;
      _bufferRefreshGenById[id] = next;
      startedGen[id] = next;
    }

    final result = await fetchMessagesByIds(
      FetchMessagesByIdsParams(
        conversationId: conversationId,
        messageIds: ids,
      ),
    );

    if (isClosed || epoch != _roomRefreshEpoch) return;

    result.fold(
      (_) {
        // Keep optimistic buffer; surface no hard error for background refresh.
      },
      (fresh) {
        var applied = false;
        for (final m in fresh) {
          // Live window always wins for concurrent snapshot updates.
          if (_liveIds.contains(m.id)) continue;
          if (!_byId.containsKey(m.id)) continue;
          if (_bufferRefreshGenById[m.id] != startedGen[m.id]) continue;
          _byId[m.id] = m;
          applied = true;
        }
        if (!applied) return;
        emit(state.copyWith(
          messages: _sortedMessages(),
          // Keep fixed live limit — refresh must not grow the watch window.
          limit: ChatRoomState.pageSize,
        ));
      },
    );
  }

  @override
  Future<void> close() async {
    _olderRequestId++;
    _roomRefreshEpoch++;
    _bufferRefreshGenById.clear();
    _byId.clear();
    _liveIds.clear();
    final pending = Map.of(_uploads);
    _uploads.clear();
    for (final entry in pending.entries) {
      unawaited(() async {
        await entry.value.cancel();
        await discardUpload(entry.value.storagePath);
      }());
    }
    return super.close();
  }
}

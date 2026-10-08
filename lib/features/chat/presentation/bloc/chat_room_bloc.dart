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
/// The outbox is in-memory: closing the room cancels in-flight uploads and
/// removes their orphan objects.
@injectable
class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final WatchMessagesUseCase watchMessages;
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

  ChatRoomBloc(
    this.watchMessages,
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
    on<LoadOlderMessagesRequestedEvent>(_onLoadOlder);
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

    await emit.forEach(
      watchMessages(
        WatchMessagesParams(conversationId: conversationId, limit: state.limit),
      ),
      onData: (either) => either.fold(
        (failure) => state.copyWith(
          messagesStatus: SectionStatus.error,
          messagesError: failure.message,
          loadingOlder: false,
        ),
        (messages) {
          _markReadIfNewIncoming(messages);
          final ids = {for (final m in messages) m.id};
          return state.copyWith(
            messagesStatus: SectionStatus.loaded,
            messages: messages,
            messagesError: null,
            loadingOlder: false,
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

  void _onLoadOlder(
    LoadOlderMessagesRequestedEvent event,
    Emitter<ChatRoomState> emit,
  ) {
    if (state.loadingOlder ||
        state.messagesStatus != SectionStatus.loaded ||
        !state.hasMore) {
      return;
    }
    emit(state.copyWith(
      limit: state.limit + ChatRoomState.pageSize,
      loadingOlder: true,
    ));
    add(const WatchMessagesStartedEvent());
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
    emit(state.copyWith(
      actionInProgress: false,
      actionError: result.fold((f) => f.message, (_) => null),
    ));
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
    emit(state.copyWith(
      actionInProgress: false,
      actionError: result.fold((f) => f.message, (_) => null),
    ));
  }

  @override
  Future<void> close() async {
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

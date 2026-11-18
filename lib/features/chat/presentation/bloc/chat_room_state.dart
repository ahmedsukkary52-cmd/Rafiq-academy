import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

enum ChatOutgoingStatus { uploading, sending, sent, failed }

/// A message the user sent that the server has not confirmed in the stream
/// yet. [messageId] is fixed at creation so retries are idempotent.
class ChatOutgoingMessage extends Equatable {
  final String messageId;
  final ChatMessageType type;
  final String text;
  final ChatAttachmentDraft? attachment;

  /// Set once the Storage upload completed; retries then only re-send.
  final String? uploadedPath;
  final double progress;
  final ChatOutgoingStatus status;
  final String? error;
  final DateTime createdAt;
  final String? replyToMessageId;

  const ChatOutgoingMessage({
    required this.messageId,
    required this.type,
    required this.text,
    this.attachment,
    this.uploadedPath,
    this.progress = 0,
    required this.status,
    this.error,
    required this.createdAt,
    this.replyToMessageId,
  });

  bool get canRetry => status == ChatOutgoingStatus.failed;
  bool get canCancel =>
      status == ChatOutgoingStatus.uploading ||
      status == ChatOutgoingStatus.failed;

  ChatOutgoingMessage copyWith({
    Object? uploadedPath = _unset,
    double? progress,
    ChatOutgoingStatus? status,
    Object? error = _unset,
  }) {
    return ChatOutgoingMessage(
      messageId: messageId,
      type: type,
      text: text,
      attachment: attachment,
      uploadedPath: identical(uploadedPath, _unset)
          ? this.uploadedPath
          : uploadedPath as String?,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: identical(error, _unset) ? this.error : error as String?,
      createdAt: createdAt,
      replyToMessageId: replyToMessageId,
    );
  }

  @override
  List<Object?> get props => [
    messageId,
    type,
    text,
    attachment,
    uploadedPath,
    progress,
    status,
    error,
    createdAt,
    replyToMessageId,
  ];
}

class ChatRoomState extends Equatable {
  static const int pageSize = 30;

  final SectionStatus messagesStatus;
  final List<MessageEntity> messages;
  final String? messagesError;

  /// Fixed live listener window (never grows on "load older").
  final int limit;
  final bool loadingOlder;

  /// False once an older page returns fewer than [pageSize] rows, or the
  /// initial live window was already shorter than [limit].
  final bool hasMoreOlder;

  final List<ChatOutgoingMessage> outbox;

  /// Edit / delete / validation feedback (one-shot banner).
  final String? actionError;
  final bool actionInProgress;

  const ChatRoomState({
    this.messagesStatus = SectionStatus.initial,
    this.messages = const [],
    this.messagesError,
    this.limit = pageSize,
    this.loadingOlder = false,
    this.hasMoreOlder = true,
    this.outbox = const [],
    this.actionError,
    this.actionInProgress = false,
  });

  factory ChatRoomState.initial() => const ChatRoomState();

  /// UI alias — load-older affordance uses this.
  bool get hasMore => hasMoreOlder;

  /// Outbox entries not yet visible in the server stream (dedupe by id).
  List<ChatOutgoingMessage> get pendingOutbox {
    if (outbox.isEmpty) return const [];
    final ids = {for (final m in messages) m.id};
    return outbox.where((o) => !ids.contains(o.messageId)).toList();
  }

  ChatRoomState copyWith({
    SectionStatus? messagesStatus,
    List<MessageEntity>? messages,
    Object? messagesError = _unset,
    int? limit,
    bool? loadingOlder,
    bool? hasMoreOlder,
    List<ChatOutgoingMessage>? outbox,
    Object? actionError = _unset,
    bool? actionInProgress,
  }) {
    return ChatRoomState(
      messagesStatus: messagesStatus ?? this.messagesStatus,
      messages: messages ?? this.messages,
      messagesError: identical(messagesError, _unset)
          ? this.messagesError
          : messagesError as String?,
      limit: limit ?? this.limit,
      loadingOlder: loadingOlder ?? this.loadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      outbox: outbox ?? this.outbox,
      actionError: identical(actionError, _unset)
          ? this.actionError
          : actionError as String?,
      actionInProgress: actionInProgress ?? this.actionInProgress,
    );
  }

  @override
  List<Object?> get props => [
    messagesStatus,
    messages,
    messagesError,
    limit,
    loadingOlder,
    hasMoreOlder,
    outbox,
    actionError,
    actionInProgress,
  ];
}

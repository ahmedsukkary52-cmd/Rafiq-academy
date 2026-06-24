import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/chat_entities.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class ChatRoomState extends Equatable {
  final SectionStatus messagesStatus;
  final List<MessageEntity> messages;
  final String? messagesError;

  final SubmissionStatus sendStatus;
  final String? sendError;

  const ChatRoomState({
    this.messagesStatus = SectionStatus.initial,
    this.messages = const [],
    this.messagesError,
    this.sendStatus = SubmissionStatus.idle,
    this.sendError,
  });

  factory ChatRoomState.initial() => const ChatRoomState();

  ChatRoomState copyWith({
    SectionStatus? messagesStatus,
    List<MessageEntity>? messages,
    Object? messagesError = _unset,
    SubmissionStatus? sendStatus,
    Object? sendError = _unset,
  }) {
    return ChatRoomState(
      messagesStatus: messagesStatus ?? this.messagesStatus,
      messages: messages ?? this.messages,
      messagesError: identical(messagesError, _unset)
          ? this.messagesError
          : messagesError as String?,
      sendStatus: sendStatus ?? this.sendStatus,
      sendError:
      identical(sendError, _unset) ? this.sendError : sendError as String?,
    );
  }

  @override
  List<Object?> get props =>
      [messagesStatus, messages, messagesError, sendStatus, sendError];
}
import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
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
@injectable
class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final WatchMessagesUseCase watchMessages;
  final SendMessageUseCase sendMessage;
  final MarkConversationAsReadUseCase markConversationAsRead;

  final String conversationId;
  final String currentUserId;

  ChatRoomBloc(
      this.watchMessages,
      this.sendMessage,
      this.markConversationAsRead,
      @factoryParam this.conversationId,
      @factoryParam this.currentUserId,
      ) : super(ChatRoomState.initial()) {
    on<WatchMessagesStartedEvent>(
      _onWatchMessagesStarted,
      transformer: restartable(),
    );
    on<SendMessageRequestedEvent>(_onSendMessage);

    add(const WatchMessagesStartedEvent());

    // تصفير عداد غير المقروء فور فتح المحادثة. عملية ثانوية (مجرد
    // badge)، فمش بنعرض حالتها في الـ state ولا بنوقف المستخدم لو فشلت.
    // unawaited() هنا قرار متعمد، مش نسيان await.
    unawaited(markConversationAsRead(
      MarkAsReadParams(conversationId: conversationId, uid: currentUserId),
    ));
  }

  Future<void> _onWatchMessagesStarted(
      WatchMessagesStartedEvent event,
      Emitter<ChatRoomState> emit,
      ) async {
    emit(state.copyWith(
      messagesStatus: SectionStatus.loading,
      messagesError: null,
    ));

    await emit.forEach(
      watchMessages(ConversationIdParams(conversationId)),
      onData: (either) => either.fold(
            (failure) => state.copyWith(
          messagesStatus: SectionStatus.error,
          messagesError: failure.message,
        ),
            (messages) => state.copyWith(
          messagesStatus: SectionStatus.loaded,
          messages: messages,
        ),
      ),
    );
  }

  Future<void> _onSendMessage(
      SendMessageRequestedEvent event,
      Emitter<ChatRoomState> emit,
      ) async {
    emit(state.copyWith(sendStatus: SubmissionStatus.submitting, sendError: null));

    final result = await sendMessage(SendMessageParams(
      conversationId: conversationId,
      senderId: currentUserId,
      text: event.text,
    ));

    result.fold(
          (failure) => emit(state.copyWith(
        sendStatus: SubmissionStatus.error,
        sendError: failure.message,
      )),
      // مفيش داعي نضيف الرسالة يدوياً للـ state هنا: الـ Stream
      // (emit.forEach في _onWatchMessagesStarted) هيستقبلها تلقائياً
      // أول ما تتكتب في Firestore، فمنعملش الرسالة "تظهر مرتين".
          (_) => emit(state.copyWith(sendStatus: SubmissionStatus.success)),
    );
  }
}
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/chat_usecases.dart';
import 'chat_conversations_event.dart';
import 'chat_conversations_state.dart';

/// @singleton: قائمة المحادثات ("صندوق الوارد") واحدة لكل المستخدم طول
/// ما هو فاتح التطبيق، عكس ChatRoomBloc اللي بيتعمل له instance جديدة
/// لكل محادثة بيفتحها (راجع التعليق في chat_room_bloc.dart).
@singleton
class ChatConversationsBloc
    extends Bloc<ChatConversationsEvent, ChatConversationsState> {
  final WatchConversationsUseCase watchConversations;
  final GetOrCreateConversationUseCase getOrCreateConversation;

  ChatConversationsBloc({
    required this.watchConversations,
    required this.getOrCreateConversation,
  }) : super(ChatConversationsState.initial()) {
    on<StartWatchingConversationsEvent>(
      _onStartWatching,
      transformer: restartable(),
    );
    on<StartConversationEvent>(_onStartConversation);
    on<ResetStartConversationEvent>(_onResetStartConversation);
  }

  Future<void> _onStartWatching(
      StartWatchingConversationsEvent event,
      Emitter<ChatConversationsState> emit,
      ) async {
    emit(state.copyWith(
      conversationsStatus: SectionStatus.loading,
      conversationsError: null,
    ));

    await emit.forEach(
      watchConversations(ChatUidParams(event.uid)),
      onData: (either) => either.fold(
            (failure) => state.copyWith(
          conversationsStatus: SectionStatus.error,
          conversationsError: failure.message,
        ),
            (conversations) => state.copyWith(
          conversationsStatus: SectionStatus.loaded,
          conversations: conversations,
        ),
      ),
    );
  }

  Future<void> _onStartConversation(
      StartConversationEvent event,
      Emitter<ChatConversationsState> emit,
      ) async {
    emit(state.copyWith(
      startConversationStatus: SubmissionStatus.submitting,
      startConversationError: null,
    ));

    final result = await getOrCreateConversation(GetOrCreateConversationParams(
      currentUser: event.currentUser,
      otherUser: event.otherUser,
    ));

    result.fold(
          (failure) => emit(state.copyWith(
        startConversationStatus: SubmissionStatus.error,
        startConversationError: failure.message,
      )),
          (conversation) => emit(state.copyWith(
        startConversationStatus: SubmissionStatus.success,
        startedConversation: conversation,
      )),
    );
  }

  void _onResetStartConversation(
      ResetStartConversationEvent event,
      Emitter<ChatConversationsState> emit,
      ) {
    emit(state.copyWith(
      startConversationStatus: SubmissionStatus.idle,
      startedConversation: null,
      startConversationError: null,
    ));
  }
}
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
  final WatchAllConversationsUseCase watchAllConversations;
  final GetOrCreateConversationUseCase getOrCreateConversation;

  /// Cleared on logout so stale conversation snapshots are ignored (H1).
  String? _currentUid;
  int _sessionGeneration = 0;

  ChatConversationsBloc({
    required this.watchConversations,
    required this.watchAllConversations,
    required this.getOrCreateConversation,
  }) : super(ChatConversationsState.initial()) {
    on<StartWatchingConversationsEvent>(
      _onStartWatching,
      transformer: restartable(),
    );
    on<StartWatchingAllConversationsEvent>(
      _onStartWatchingAll,
      transformer: restartable(),
    );
    on<StartConversationEvent>(_onStartConversation);
    on<ResetStartConversationEvent>(_onResetStartConversation);
    on<ClearChatConversationsSessionEvent>(_onClearSession);
  }

  void _onClearSession(
    ClearChatConversationsSessionEvent event,
    Emitter<ChatConversationsState> emit,
  ) {
    _currentUid = null;
    _sessionGeneration++;
    emit(ChatConversationsState.initial());
  }

  Future<void> _onStartWatching(
    StartWatchingConversationsEvent event,
    Emitter<ChatConversationsState> emit,
  ) async {
    final identityChanged = _currentUid != null && _currentUid != event.uid;
    _currentUid = event.uid;
    final generation = _sessionGeneration;

    emit(
      identityChanged
          ? ChatConversationsState.initial().copyWith(
              conversationsStatus: SectionStatus.loading,
            )
          : state.copyWith(
              conversationsStatus: SectionStatus.loading,
              conversationsError: null,
            ),
    );

    await emit.forEach(
      watchConversations(ChatUidParams(event.uid)),
      onData: (either) {
        if (_currentUid != event.uid || generation != _sessionGeneration) {
          return state;
        }
        return either.fold(
          (failure) => state.copyWith(
            conversationsStatus: SectionStatus.error,
            conversationsError: failure.message,
          ),
          (conversations) => state.copyWith(
            conversationsStatus: SectionStatus.loaded,
            conversations: conversations,
          ),
        );
      },
    );
  }

  Future<void> _onStartWatchingAll(
    StartWatchingAllConversationsEvent event,
    Emitter<ChatConversationsState> emit,
  ) async {
    final identityChanged =
        _currentUid != null && _currentUid != event.observerUid;
    _currentUid = event.observerUid;
    final generation = _sessionGeneration;

    emit(
      identityChanged
          ? ChatConversationsState.initial().copyWith(
              conversationsStatus: SectionStatus.loading,
            )
          : state.copyWith(
              conversationsStatus: SectionStatus.loading,
              conversationsError: null,
            ),
    );

    await emit.forEach(
      watchAllConversations(ChatUidParams(event.observerUid)),
      onData: (either) {
        if (_currentUid != event.observerUid ||
            generation != _sessionGeneration) {
          return state;
        }
        return either.fold(
          (failure) => state.copyWith(
            conversationsStatus: SectionStatus.error,
            conversationsError: failure.message,
          ),
          (conversations) => state.copyWith(
            conversationsStatus: SectionStatus.loaded,
            conversations: conversations,
          ),
        );
      },
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
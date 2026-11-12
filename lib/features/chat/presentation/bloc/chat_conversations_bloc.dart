import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/chat_entities.dart';
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
    on<LoadMoreConversationsEvent>(_onLoadMore, transformer: droppable());
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
    _resetPaging(null, null);
    emit(ChatConversationsState.initial());
  }

  // ── Paging (live newest window + cursor pages of older threads) ──────────

  /// Null = unbounded stream (no paging).
  int? _pageSize;

  /// Participant filter for older pages; null = academy-wide oversight.
  String? _pageParticipant;
  List<ConversationEntity> _live = const [];
  List<ConversationEntity> _older = const [];
  bool _olderExhausted = false;

  void _resetPaging(int? pageSize, String? participant) {
    _pageSize = pageSize;
    _pageParticipant = participant;
    _live = const [];
    _older = const [];
    _olderExhausted = false;
  }

  static int _byRecency(ConversationEntity a, ConversationEntity b) {
    final aAt = a.lastMessageAt;
    final bAt = b.lastMessageAt;
    if (aAt == null && bAt == null) return 0;
    if (aAt == null) return 1;
    if (bAt == null) return -1;
    return bAt.compareTo(aAt);
  }

  /// A thread pushed out of the live window by newer activity is kept in the
  /// older list so it never vanishes between pages.
  List<ConversationEntity> _mergeLive(List<ConversationEntity> live) {
    if (_pageSize == null) return live;
    final liveIds = {for (final c in live) c.id};
    final olderById = {
      for (final c in _older)
        if (!liveIds.contains(c.id)) c.id: c,
    };
    for (final c in _live) {
      if (!liveIds.contains(c.id)) olderById.putIfAbsent(c.id, () => c);
    }
    _live = live;
    _older = olderById.values.toList()..sort(_byRecency);
    return [..._live, ..._older];
  }

  bool get _hasMore =>
      _pageSize != null && !_olderExhausted && _live.length >= _pageSize!;

  Future<void> _watch(
    Emitter<ChatConversationsState> emit, {
    required String uid,
    required Stream<Either<Failure, List<ConversationEntity>>> Function()
    source,
  }) async {
    final identityChanged = _currentUid != null && _currentUid != uid;
    _currentUid = uid;
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
      source(),
      onData: (either) {
        if (_currentUid != uid || generation != _sessionGeneration) {
          return state;
        }
        return either.fold(
          (failure) => state.copyWith(
            conversationsStatus: SectionStatus.error,
            conversationsError: failure.message,
          ),
          (conversations) => state.copyWith(
            conversationsStatus: SectionStatus.loaded,
            conversations: _mergeLive(conversations),
            hasMoreConversations: _hasMore,
          ),
        );
      },
    );
  }

  Future<void> _onStartWatching(
    StartWatchingConversationsEvent event,
    Emitter<ChatConversationsState> emit,
  ) {
    _resetPaging(event.pageSize, event.uid);
    return _watch(
      emit,
      uid: event.uid,
      source: () => watchConversations(
        ChatUidParams(event.uid, limit: event.pageSize),
      ),
    );
  }

  Future<void> _onStartWatchingAll(
    StartWatchingAllConversationsEvent event,
    Emitter<ChatConversationsState> emit,
  ) {
    _resetPaging(event.pageSize, null);
    return _watch(
      emit,
      uid: event.observerUid,
      source: () => watchAllConversations(
        ChatUidParams(event.observerUid, limit: event.pageSize),
      ),
    );
  }

  Future<void> _onLoadMore(
    LoadMoreConversationsEvent event,
    Emitter<ChatConversationsState> emit,
  ) async {
    final uid = _currentUid;
    final pageSize = _pageSize;
    if (uid == null ||
        pageSize == null ||
        !state.hasMoreConversations ||
        state.loadingMoreConversations ||
        state.conversations.isEmpty) {
      return;
    }
    final generation = _sessionGeneration;
    emit(state.copyWith(loadingMoreConversations: true));
    final result = await watchConversations.repository.fetchConversationsAfter(
      participantUid: _pageParticipant,
      viewerUid: uid,
      afterConversationId: state.conversations.last.id,
      limit: pageSize,
    );
    if (generation != _sessionGeneration || _currentUid != uid) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          loadingMoreConversations: false,
          conversationsError: failure.message,
        ),
      ),
      (page) {
        final known = {for (final c in state.conversations) c.id};
        _older = [
          ..._older,
          ...page.where((c) => !known.contains(c.id)),
        ]..sort(_byRecency);
        if (page.length < pageSize) _olderExhausted = true;
        emit(
          state.copyWith(
            conversations: [..._live, ..._older],
            loadingMoreConversations: false,
            hasMoreConversations: _hasMore,
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
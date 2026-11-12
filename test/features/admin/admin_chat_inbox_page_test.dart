import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_chat_inbox_page.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';

typedef _Feed = Either<Failure, List<ConversationEntity>>;

const _admin = ChatParticipantEntity(uid: 'a1', name: 'المدير', role: AppRoles.admin);
const _teacher = ChatParticipantEntity(uid: 't1', name: 'أحمد', role: AppRoles.teacher);
const _parent = ChatParticipantEntity(uid: 'p1', name: 'سارة', role: AppRoles.parent);

class _AuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 'a1',
      name: 'المدير',
      role: AppRoles.admin,
      isActive: true,
      createdAt: DateTime(2026),
    ),
  );

  @override
  Stream<AuthState> get stream => _controller.stream;

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() => _controller.close();
}

class _Repo extends Fake implements ChatRepository {
  final live = StreamController<_Feed>();
  final limits = <int?>[];
  final cursors = <String>[];

  @override
  Stream<_Feed> watchAllConversations({required String observerUid, int? limit}) {
    limits.add(limit);
    return live.stream;
  }

  @override
  Future<_Feed> fetchConversationsAfter({
    String? participantUid,
    required String viewerUid,
    required String afterConversationId,
    required int limit,
  }) async {
    cursors.add(afterConversationId);
    return const Right([
      ConversationEntity(
        id: 'old_1',
        participants: [_teacher, _parent],
        unreadCount: 0,
        lastMessage: 'رسالة قديمة',
      ),
    ]);
  }
}

List<ConversationEntity> _window() => [
  ConversationEntity(
    id: 'group_x',
    participants: const [_admin, _teacher, _parent],
    unreadCount: 2,
    kind: ConversationKinds.customGroup,
    title: 'فريق المتابعة',
    lastMessage: 'تم الاجتماع',
    lastMessageSenderId: 't1',
    lastMessageAt: DateTime.now(),
  ),
  for (var i = 0; i < adminInboxPageSize - 1; i++)
    ConversationEntity(
      id: 'a1_t$i',
      participants: [
        _admin,
        ChatParticipantEntity(uid: 't$i', name: 'معلم $i', role: AppRoles.teacher),
      ],
      unreadCount: 0,
      lastMessage: 'مرحبا',
      lastMessageAt: DateTime.now().subtract(Duration(minutes: i + 1)),
    ),
];

void main() {
  tearDown(() async {
    await sl.reset();
  });

  testWidgets('pages by cursor, titles groups, filters groups, honest empty search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _Repo();
    sl.registerSingleton<ChatConversationsBloc>(
      ChatConversationsBloc(
        watchConversations: WatchConversationsUseCase(repo),
        watchAllConversations: WatchAllConversationsUseCase(repo),
        getOrCreateConversation: GetOrCreateConversationUseCase(repo),
      ),
    );
    final auth = _AuthBloc();
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: const AdminChatInboxPage(),
        ),
      ),
    );
    await tester.pump();
    expect(repo.limits, [adminInboxPageSize]);
    repo.live.add(Right(_window()));
    await tester.pump();
    await tester.pump();

    expect(find.text('فريق المتابعة'), findsOneWidget);
    expect(find.text('أحمد: تم الاجتماع'), findsOneWidget);
    expect(find.byKey(const Key('inbox-new')), findsOneWidget);

    await tester.tap(find.text('المجموعات'));
    await tester.pump();
    expect(find.byKey(const Key('inbox-group_x')), findsOneWidget);
    expect(find.byKey(const Key('inbox-a1_t0')), findsNothing);

    await tester.tap(find.text('الكل'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('inbox-old_1')),
      600,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(repo.cursors, ['a1_t${adminInboxPageSize - 2}']);
    expect(find.byKey(const Key('inbox-old_1')), findsOneWidget);
    expect(find.byKey(const Key('inbox-load-more')), findsNothing);

    await tester.enterText(find.byType(TextField), 'لا يطابق');
    await tester.pump();
    expect(find.text('لا نتائج مطابقة ضمن المحادثات المعروضة'), findsOneWidget);
    await repo.live.close();
  });
}

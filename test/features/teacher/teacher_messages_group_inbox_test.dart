import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_event.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/teacher/presentation/pages/teacher_messages_tab.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

typedef _Feed = Either<Failure, List<ConversationEntity>>;

const _teacher = ChatParticipantEntity(
  uid: 't1',
  name: 'المعلم',
  role: AppRoles.teacher,
);
const _parent = ChatParticipantEntity(
  uid: 'p1',
  name: 'ولي الأمر',
  role: AppRoles.parent,
);
const _student = ChatParticipantEntity(
  uid: 's1',
  name: 'طالب',
  role: AppRoles.student,
);

final _group = ConversationEntity(
  id: 'g_halaqa_1',
  participants: const [_teacher, _student, _parent],
  unreadCount: 1,
  kind: ConversationKinds.halaqaGroup,
  title: 'حلقة الفجر',
  lastMessage: 'تذكير بالجلسة',
);

final _direct = ConversationEntity(
  id: 'p1_t1',
  participants: const [_teacher, _parent],
  unreadCount: 0,
  lastMessage: 'مرحبا',
);

class _AuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 't1',
      name: 'المعلم',
      role: AppRoles.teacher,
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

class _Watch extends Fake implements WatchConversationsUseCase {
  @override
  Stream<_Feed> call(ChatUidParams p) => Stream.value(Right([_group, _direct]));
}

class _UnusedStart extends Fake implements GetOrCreateConversationUseCase {}

class _UnusedWatchAll extends Fake implements WatchAllConversationsUseCase {}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpInbox(WidgetTester tester) async {
    sl.registerSingleton<ChatConversationsBloc>(
      ChatConversationsBloc(
        watchConversations: _Watch(),
        watchAllConversations: _UnusedWatchAll(),
        getOrCreateConversation: _UnusedStart(),
      ),
    );
    final auth = _AuthBloc();
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        supportedLocales: AppLocaleConfig.supportedLocales,
        localizationsDelegates: AppLocaleConfig.localizationsDelegates,
        theme: AppTheme.theme,
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: const TeacherMessagesTab(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('shows halaqa group by title under all filter', (tester) async {
    await pumpInbox(tester);

    expect(find.text('حلقة الفجر'), findsOneWidget);
    expect(find.text('مجموعة الحلقة'), findsOneWidget);
    expect(find.text('ولي الأمر — ولي أمر'), findsOneWidget);
  });

  testWidgets('parents filter hides group chats', (tester) async {
    await pumpInbox(tester);

    await tester.tap(find.text('أولياء الأمور'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('حلقة الفجر'), findsNothing);
    expect(find.text('ولي الأمر — ولي أمر'), findsOneWidget);
  });
}

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

typedef _Feed = Either<Failure, List<ConversationEntity>>;

const _teacher = ChatParticipantEntity(
  uid: 't1',
  name: 'المعلم',
  role: AppRoles.teacher,
);
const _student = ChatParticipantEntity(
  uid: 's1',
  name: 'طالب أول',
  role: AppRoles.student,
);

class _AuthBloc extends Fake implements AuthBloc {
  final _controller = StreamController<AuthState>.broadcast();

  @override
  AuthState get state => AuthAuthenticated(
    UserEntity(
      uid: 't1',
      name: 'المعلم',
      role: AppRoles.teacher,
      phone: '',
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
  Stream<_Feed> call(ChatUidParams p) => Stream.value(
    const Right([
      ConversationEntity(
        id: 's1_t1',
        participants: [_teacher, _student],
        unreadCount: 0,
      ),
    ]),
  );
}

class _UnusedStart extends Fake implements GetOrCreateConversationUseCase {}

void main() {
  tearDown(() async {
    await sl.reset();
  });

  testWidgets('parents filter does not claim parent contact is unavailable', (
    tester,
  ) async {
    sl.registerSingleton<ChatConversationsBloc>(
      ChatConversationsBloc(
        watchConversations: _Watch(),
        getOrCreateConversation: _UnusedStart(),
      ),
    );
    final auth = _AuthBloc();
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: auth,
          child: const TeacherMessagesTab(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('طالب أول — طالب'), findsOneWidget);

    await tester.tap(find.text('أولياء الأمور'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('لا محادثات مع أولياء الأمور'), findsOneWidget);
    expect(
      find.text('تواصل مع ولي الأمر من الملف الشخصي للطالب'),
      findsOneWidget,
    );
    expect(find.textContaining('غير متاح'), findsNothing);
  });
}

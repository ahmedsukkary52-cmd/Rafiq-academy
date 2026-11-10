import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/repositories/chat_repository.dart';
import 'package:rafiq_academy/features/chat/domain/student_chat_teacher.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_event.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_state.dart';
import 'package:rafiq_academy/features/chat/presentation/pages/student_chat_page.dart';

class _AuthBlocStub extends Cubit<AuthState> implements AuthBloc {
  _AuthBlocStub(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConversationsBlocStub extends Cubit<ChatConversationsState>
    implements ChatConversationsBloc {
  _ConversationsBlocStub() : super(const ChatConversationsState());

  final events = <ChatConversationsEvent>[];

  @override
  void add(ChatConversationsEvent event) => events.add(event);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ChatRepository extends Fake implements ChatRepository {
  Either<Failure, ChatParticipantEntity> participant = const Right(_teacher);
  final requested = <String>[];

  @override
  Future<Either<Failure, ChatParticipantEntity>> getParticipant(
    String uid,
  ) async {
    requested.add(uid);
    return participant;
  }
}

class _Resolver implements StudentChatTeacherResolver {
  StudentChatTeacher next = const StudentChatTeacher(
    teacherUid: 't1',
    hasHalaqa: true,
  );
  int calls = 0;

  @override
  Future<StudentChatTeacher> resolveTeacher() async {
    calls++;
    return next;
  }
}

const _teacher = ChatParticipantEntity(
  uid: 't1',
  name: 'المعلم',
  role: AppRoles.teacher,
  profileImageUrl: 'https://img/t1',
);

final _student = UserEntity(
  uid: 's1',
  name: 'أحمد',
  role: AppRoles.student,
  isActive: true,
  createdAt: DateTime(2026),
  profileImageUrl: 'https://img/s1',
);

late _ConversationsBlocStub _conversations;
late _ChatRepository _repo;
late _Resolver _resolver;

Future<void> _pump(WidgetTester tester, {AuthState? auth}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.studentChat,
    routes: [
      GoRoute(
        path: AppRoutes.studentChat,
        builder: (_, __) => StudentChatPage(teacherResolver: _resolver),
      ),
      GoRoute(
        path: AppRoutes.studentChatRoom,
        builder: (_, state) {
          final extra = state.extra as Map<String, String?>?;
          return Text(
            'room ${state.pathParameters['conversationId']} '
            '${extra?['name']} ${extra?['image']}',
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: _AuthBlocStub(auth ?? AuthAuthenticated(_student)),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    await sl.reset();
    _conversations = _ConversationsBlocStub();
    _repo = _ChatRepository();
    _resolver = _Resolver();
    sl.registerSingleton<ChatConversationsBloc>(_conversations);
    sl.registerLazySingleton(() => GetChatParticipantUseCase(_repo));
  });

  tearDown(() async {
    await _conversations.close();
    await sl.reset();
  });

  testWidgets('signed-out users see the login message', (tester) async {
    await _pump(tester, auth: const AuthUnauthenticated());
    expect(find.text('يجب تسجيل الدخول أولاً'), findsOneWidget);
    expect(_resolver.calls, 0);
  });

  testWidgets('no halaqa shows the assignment message', (tester) async {
    _resolver.next = const StudentChatTeacher(hasHalaqa: false);
    await _pump(tester);
    expect(
      find.text('لم يتم تعيينك لحلقة بعد — تواصل مع الإدارة'),
      findsOneWidget,
    );
    expect(_repo.requested, isEmpty);
    expect(_conversations.events, isEmpty);
  });

  testWidgets('a halaqa without a teacher shows the lookup message', (
    tester,
  ) async {
    _resolver.next = const StudentChatTeacher(teacherUid: '', hasHalaqa: true);
    await _pump(tester);
    expect(find.text('تعذّر تحديد معلم الحلقة'), findsOneWidget);
    expect(_repo.requested, isEmpty);
  });

  testWidgets('a resolved teacher starts the student conversation', (
    tester,
  ) async {
    await _pump(tester);
    expect(_resolver.calls, 1);
    expect(_repo.requested, ['t1']);
    expect(_conversations.events, [
      const StartWatchingConversationsEvent('s1'),
      const ResetStartConversationEvent(),
      const StartConversationEvent(
        currentUser: ChatParticipantEntity(
          uid: 's1',
          name: 'أحمد',
          role: AppRoles.student,
          profileImageUrl: 'https://img/s1',
        ),
        otherUser: _teacher,
      ),
    ]);
  });

  testWidgets('participant failure is shown and retry resolves again', (
    tester,
  ) async {
    _repo.participant = const Left(ServerFailure('تعذر تحميل المعلم'));
    await _pump(tester);
    expect(find.text('تعذر تحميل المعلم'), findsOneWidget);
    expect(_conversations.events, isEmpty);

    _repo.participant = const Right(_teacher);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump();

    expect(_resolver.calls, 2);
    expect(_repo.requested, ['t1', 't1']);
    expect(_conversations.events, hasLength(3));
  });

  testWidgets('start-conversation error is shown', (tester) async {
    await _pump(tester);
    _conversations.emit(
      const ChatConversationsState(
        startConversationStatus: SubmissionStatus.error,
        startConversationError: 'فشل فتح المحادثة مع المعلم',
      ),
    );
    await tester.pump();
    expect(find.text('فشل فتح المحادثة مع المعلم'), findsOneWidget);
  });

  testWidgets('a started conversation opens its room', (tester) async {
    await _pump(tester);
    _conversations.events.clear();
    _conversations.emit(
      const ChatConversationsState(
        startConversationStatus: SubmissionStatus.success,
        startedConversation: ConversationEntity(
          id: 's1_t1',
          participants: [
            ChatParticipantEntity(
              uid: 's1',
              name: 'أحمد',
              role: AppRoles.student,
            ),
            _teacher,
          ],
          unreadCount: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('room s1_t1 المعلم https://img/t1'), findsOneWidget);
    expect(_conversations.events, [const ResetStartConversationEvent()]);
  });
}

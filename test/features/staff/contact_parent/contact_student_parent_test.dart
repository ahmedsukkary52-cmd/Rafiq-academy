import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/core/router/app_routes.dart';
import 'package:rafiq_academy/features/auth/domain/entities/user_entity.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rafiq_academy/features/auth/presentation/bloc/auth_state.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_event.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_state.dart';
import 'package:rafiq_academy/features/staff/contact_parent/contact_student_parent.dart';
import 'package:rafiq_academy/shared/domain/student_parent_links.dart';

const _contactFile =
    'lib/features/staff/contact_parent/contact_student_parent.dart';
const _roles = ['student', 'teacher', 'supervisor', 'admin', 'parent'];

UserEntity _user(String role) => UserEntity(
  uid: 'u-$role',
  name: 'موظف',
  role: role,
  isActive: true,
  createdAt: DateTime(2026),
);

class _ParentLinks extends Fake implements StudentParentLinkReader {
  _ParentLinks(this.parentIds);
  final List<String> parentIds;
  final calls = <List<String>>[];

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    calls.add(studentIds);
    return Right({'s1': parentIds});
  }
}

class _Participant extends Fake implements GetChatParticipantUseCase {
  @override
  Future<Either<Failure, ChatParticipantEntity>> call(
    ChatUidParams params,
  ) async => Right(
    ChatParticipantEntity(
      uid: params.uid,
      name: 'ولي الأمر',
      role: AppRoles.parent,
    ),
  );
}

/// Answers the start event like the server would: a conversation, or a
/// relationship denial. The stream buffers until the flow listens.
class _ChatBloc extends Fake implements ChatConversationsBloc {
  _ChatBloc({this.deny = false});
  final bool deny;
  final _states = StreamController<ChatConversationsState>();
  final started = <StartConversationEvent>[];

  @override
  Stream<ChatConversationsState> get stream => _states.stream;

  @override
  void add(ChatConversationsEvent event) {
    if (event is! StartConversationEvent) return;
    started.add(event);
    _states.add(
      deny
          ? const ChatConversationsState(
              startConversationStatus: SubmissionStatus.error,
              startConversationError: 'غير مسموح بالتواصل بين هذين الحسابين',
            )
          : const ChatConversationsState(
              startConversationStatus: SubmissionStatus.success,
              startedConversation: ConversationEntity(
                id: 'c1',
                participants: [],
                unreadCount: 0,
              ),
            ),
    );
  }
}

class _AuthBloc extends Fake implements AuthBloc {
  _AuthBloc(this.state);

  @override
  final AuthState state;

  @override
  Stream<AuthState> get stream => const Stream.empty();
}

class _Harness {
  _Harness(this.router, this.chat, this.links);
  final GoRouter router;
  final _ChatBloc chat;
  final _ParentLinks links;

  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

/// A host screen on [role]'s own route with a "contact" button, under a real
/// GoRouter guarded by [AuthRedirect] and marker screens for every chat
/// destination.
Future<_Harness> _pump(
  WidgetTester tester, {
  required String role,
  bool deny = false,
  List<String> parentIds = const ['p1'],
}) async {
  final auth = AuthAuthenticated(_user(role));
  final chat = _ChatBloc(deny: deny);
  final links = _ParentLinks(parentIds);
  final deps = StaffParentContactDeps(
    parentLinks: links,
    getParticipant: _Participant(),
    chatBloc: chat,
    chatRoom: (conversation, parent) =>
        Scaffold(body: Text('ROOM ${conversation.id} ${parent.uid}')),
  );
  Widget marker(String text) => Scaffold(body: Text(text));
  final host = '/$role/host';
  final router = GoRouter(
    initialLocation: host,
    redirect: (_, state) =>
        AuthRedirect.resolve(state: auth, path: state.matchedLocation),
    routes: [
      for (final r in _roles)
        GoRoute(path: '/$r', builder: (_, __) => marker('HOME /$r')),
      GoRoute(
        path: host,
        builder: (context, _) => Scaffold(
          body: ElevatedButton(
            onPressed: () => contactStudentParent(
              context: context,
              studentId: 's1',
              deps: deps,
            ),
            child: const Text('contact'),
          ),
        ),
      ),
      GoRoute(
        path: '/teacher/chat/:id',
        builder: (_, s) => marker('TEACHER CHAT ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/admin/chat/:id',
        builder: (_, s) => marker('ADMIN CHAT ${s.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<AuthBloc>.value(
      value: _AuthBloc(auth),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(router, chat, links);
}

Future<void> _tapContact(WidgetTester tester) async {
  await tester.tap(find.text('contact'));
  await tester.pumpAndSettle();
}

/// Transitive lib/ imports of [entry] (relative and package URIs).
Set<String> _closure(String entry) {
  final seen = <String>{entry};
  final queue = [entry];
  while (queue.isNotEmpty) {
    final file = File(queue.removeLast());
    if (!file.existsSync()) continue;
    for (final m in RegExp(
      r"^(?:import|export) '([^']+)'",
      multiLine: true,
    ).allMatches(file.readAsStringSync())) {
      final uri = m.group(1)!;
      String? target;
      if (uri.startsWith('package:rafiq_academy/')) {
        target = 'lib/${uri.substring('package:rafiq_academy/'.length)}';
      } else if (!uri.contains(':')) {
        target = Uri.file(file.path).resolve(uri).toFilePath();
        target = target.replaceAll(r'\', '/');
        final at = target.indexOf('lib/');
        target = target.substring(at);
      }
      if (target != null && seen.add(target)) queue.add(target);
    }
  }
  return seen;
}

void main() {
  group('role routing (pure)', () {
    test('only staff roles are offered parent contact', () {
      for (final role in [
        AppRoles.teacher,
        AppRoles.supervisor,
        AppRoles.admin,
      ]) {
        expect(staffCanContactStudentParent(role), isTrue, reason: role);
      }
      for (final role in [AppRoles.parent, AppRoles.student, '']) {
        expect(staffCanContactStudentParent(role), isFalse, reason: role);
      }
    });

    test('teacher and admin routes pass their own guard; supervisor none', () {
      expect(staffParentChatRoute(AppRoles.teacher, 'c1'), '/teacher/chat/c1');
      expect(staffParentChatRoute(AppRoles.admin, 'c1'), '/admin/chat/c1');
      expect(staffParentChatRoute(AppRoles.supervisor, 'c1'), isNull);
      for (final role in [AppRoles.teacher, AppRoles.admin]) {
        expect(
          AuthRedirect.resolve(
            state: AuthAuthenticated(_user(role)),
            path: staffParentChatRoute(role, 'c1')!,
          ),
          isNull,
          reason: role,
        );
      }
    });

    test('supervisor still cannot open teacher or admin chat routes', () {
      final auth = AuthAuthenticated(_user(AppRoles.supervisor));
      for (final path in ['/teacher/chat/c1', '/admin/chat/c1']) {
        expect(
          AuthRedirect.resolve(state: auth, path: path),
          AppRoutes.supervisor,
          reason: path,
        );
      }
    });
  });

  group('contact flow per role (real router)', () {
    testWidgets('teacher opens the teacher chat route (unchanged)', (
      tester,
    ) async {
      final h = await _pump(tester, role: AppRoles.teacher);
      await _tapContact(tester);

      expect(find.text('TEACHER CHAT c1'), findsOneWidget);
      expect(h.location, '/teacher/chat/c1');
      expect(h.chat.started.single.currentUser.role, AppRoles.teacher);
      expect(h.chat.started.single.otherUser.uid, 'p1');
    });

    testWidgets('admin opens the admin chat route', (tester) async {
      final h = await _pump(tester, role: AppRoles.admin);
      await _tapContact(tester);

      expect(find.text('ADMIN CHAT c1'), findsOneWidget);
      expect(find.text('HOME /admin'), findsNothing);
      expect(h.location, '/admin/chat/c1');
    });

    testWidgets('eligible supervisor opens the room in-feature', (
      tester,
    ) async {
      final h = await _pump(tester, role: AppRoles.supervisor);
      await _tapContact(tester);

      expect(find.text('ROOM c1 p1'), findsOneWidget);
      expect(find.text('TEACHER CHAT c1'), findsNothing);
      expect(find.text('HOME /supervisor'), findsNothing);
      expect(h.location, '/supervisor/host');
      expect(h.chat.started.single.currentUser.role, AppRoles.supervisor);
    });

    testWidgets('ineligible supervisor: server denial opens nothing', (
      tester,
    ) async {
      final h = await _pump(tester, role: AppRoles.supervisor, deny: true);
      await _tapContact(tester);

      expect(h.chat.started, hasLength(1));
      expect(find.textContaining('ROOM'), findsNothing);
      expect(
        find.text('تعذر فتح محادثة ولي الأمر حالياً. حاول مرة أخرى.'),
        findsOneWidget,
      );
      expect(h.location, '/supervisor/host');
    });

    testWidgets('non-staff role is refused before any read', (tester) async {
      final h = await _pump(tester, role: AppRoles.parent);
      await _tapContact(tester);

      expect(find.text('غير مسموح بفتح هذه المحادثة'), findsOneWidget);
      expect(h.links.calls, isEmpty);
      expect(h.chat.started, isEmpty);
    });

    testWidgets('no linked parent starts no conversation', (tester) async {
      final h = await _pump(tester, role: AppRoles.supervisor, parentIds: []);
      await _tapContact(tester);

      expect(find.text('لا يوجد ولي أمر مرتبط بهذا الطالب'), findsOneWidget);
      expect(h.chat.started, isEmpty);
    });
  });

  group('ownership (source)', () {
    test('one implementation, owned by staff', () {
      final declaring = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) => f.readAsStringSync().contains(
              'Future<void> contactStudentParent(',
            ),
          )
          .map((f) => f.path.replaceAll(r'\', '/'))
          .toList();
      expect(declaring, [_contactFile]);
      expect(
        File(
          'lib/features/teacher/presentation/teacher_contact_parent.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('transitive closure reaches no role module, DI root or router', () {
      final closure = _closure(_contactFile);
      final hits = closure.where((f) {
        final parts = f.split('/');
        return (parts.length > 2 &&
                parts[1] == 'features' &&
                _roles.contains(parts[2])) ||
            f.startsWith('lib/core/di/') ||
            f.startsWith('lib/core/router/');
      }).toList();
      expect(closure.length, greaterThan(5));
      expect(hits, isEmpty);
    });
  });
}

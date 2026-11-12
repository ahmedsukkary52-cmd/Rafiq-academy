import 'dart:async';
import 'dart:io';

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
import 'package:rafiq_academy/features/awards/domain/usecases/awards_usecases.dart';
import 'package:rafiq_academy/features/awards/presentation/bloc/awards_bloc.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_bloc.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_event.dart';
import 'package:rafiq_academy/features/chat/presentation/bloc/chat_conversations_state.dart';
import 'package:rafiq_academy/features/staff/student_profile/presentation/pages/student_profile_page.dart';
import 'package:rafiq_academy/features/staff/student_profile/presentation/student_profile_viewer.dart';
import 'package:rafiq_academy/shared/domain/halaqa_name_reader.dart';
import 'package:rafiq_academy/shared/domain/halaqa_roster.dart';
import 'package:rafiq_academy/shared/domain/halaqa_students_summary_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_record_entity.dart';
import 'package:rafiq_academy/shared/domain/recitation_records_reader.dart';
import 'package:rafiq_academy/shared/domain/student_parent_links.dart';
import 'package:rafiq_academy/shared/domain/student_profile_details.dart';
import 'package:rafiq_academy/shared/domain/student_profile_summary.dart';

const _pagePath =
    'lib/features/staff/student_profile/presentation/pages/student_profile_page.dart';
const _evaluationsPath = '/teacher/halaqa/h1/evaluations?studentId=s1';

UserEntity _user(String role) => UserEntity(
  uid: 'u-$role',
  name: 'موظف',
  role: role,
  isActive: true,
  createdAt: DateTime(2026),
);

String? _redirect(String role, String path) =>
    AuthRedirect.resolve(state: AuthAuthenticated(_user(role)), path: path);

StudentProfileDetails _details({String halaqaName = 'حلقة النور'}) =>
    StudentProfileDetails(
      summary: StudentProfileSummary(
        name: 'أحمد',
        halaqaName: halaqaName,
        level: 1,
        overallProgressPercent: 40,
        totalVersesMemorized: 0,
      ),
      halaqaId: 'h1',
      currentPlanName: 'جزء عم',
      streakDays: 0,
    );

/// Every read the page makes, in call order.
final _reads = <String>[];

class _Profile implements StudentProfileDetailsReader {
  _Profile([this.results]);

  /// Answers in order; the last one repeats. Defaults to a loaded profile.
  final List<Either<Failure, StudentProfileDetails>>? results;
  var _calls = 0;

  @override
  Future<Either<Failure, StudentProfileDetails>> getStudentProfileDetails(
    String studentId,
  ) async {
    _reads.add('profile $studentId');
    final answers = results;
    if (answers == null) return Right(_details());
    return answers[(_calls++).clamp(0, answers.length - 1)];
  }
}

class _HalaqaName implements HalaqaNameReader {
  @override
  Future<Either<Failure, String>> getHalaqaName(String halaqaId) async {
    _reads.add('halaqa $halaqaId');
    return const Right('حلقة الفجر');
  }
}

class _Roster extends Fake implements GetHalaqaStudentsUseCase {
  @override
  Future<Either<Failure, List<HalaqaStudentSummaryEntity>>> call(
    HalaqaStudentsParams params,
  ) async {
    _reads.add('roster ${params.halaqaId}');
    return const Right([]);
  }
}

class _Recitations implements RecitationRecordsReader {
  @override
  Future<Either<Failure, List<RecitationRecordEntity>>> getRecitationRecords(
    String studentId,
  ) async {
    _reads.add('recitations $studentId');
    return const Right([]);
  }
}

class _ParentLinks extends Fake implements StudentParentLinkReader {
  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async => const Right({
    's1': ['p1'],
  });
}

class _Participant extends Fake implements GetChatParticipantUseCase {
  @override
  Future<Either<Failure, ChatParticipantEntity>> call(
    ChatUidParams params,
  ) async => const Right(
    ChatParticipantEntity(uid: 'p1', name: 'ولي الأمر', role: AppRoles.parent),
  );
}

class _UnusedStats extends Fake implements GetAwardsStatsUseCase {}

class _UnusedGranted extends Fake implements GetGrantedAwardsUseCase {}

class _UnusedGrant extends Fake implements GrantAwardUseCase {}

class _UnusedCertificate extends Fake
    implements GenerateCertificatePdfUseCase {}

/// Answers the start event with a created conversation; the stream buffers it
/// until `contactStudentParent` listens.
class _ChatBloc extends Fake implements ChatConversationsBloc {
  final _states = StreamController<ChatConversationsState>();
  final started = <StartConversationEvent>[];

  @override
  Stream<ChatConversationsState> get stream => _states.stream;

  @override
  void add(ChatConversationsEvent event) {
    if (event is StartConversationEvent) {
      started.add(event);
      _states.add(
        const ChatConversationsState(
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
}

class _AuthBloc extends Fake implements AuthBloc {
  _AuthBloc(this.state);

  @override
  final AuthState state;

  @override
  Stream<AuthState> get stream => const Stream.empty();
}

Future<_ChatBloc> _registerFakes({_Profile? profile}) async {
  await sl.reset();
  _reads.clear();
  final chat = _ChatBloc();
  sl
    ..registerFactory<AwardsBloc>(
      () => AwardsBloc(
        getAwardsStats: _UnusedStats(),
        getGrantedAwards: _UnusedGranted(),
        grantAward: _UnusedGrant(),
        generateCertificatePdf: _UnusedCertificate(),
      ),
    )
    ..registerSingleton<StudentProfileDetailsReader>(profile ?? _Profile())
    ..registerSingleton<HalaqaNameReader>(_HalaqaName())
    ..registerSingleton<GetHalaqaStudentsUseCase>(_Roster())
    ..registerSingleton<RecitationRecordsReader>(_Recitations())
    ..registerSingleton<StudentParentLinkReader>(_ParentLinks())
    ..registerSingleton<GetChatParticipantUseCase>(_Participant())
    ..registerSingleton<ChatConversationsBloc>(chat);
  return chat;
}

/// The page under a real GoRouter guarded by [AuthRedirect] for [role], with
/// marker screens for every destination the page could reach.
Future<GoRouter> _pumpProfile(
  WidgetTester tester, {
  required String role,
  required String profilePath,
  required StudentProfileViewer viewer,
}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = AuthAuthenticated(_user(role));
  Widget marker(String text) => Scaffold(body: Text(text));
  final router = GoRouter(
    initialLocation: profilePath,
    redirect: (_, state) =>
        AuthRedirect.resolve(state: auth, path: state.matchedLocation),
    routes: [
      for (final home in [
        AppRoutes.teacher,
        AppRoutes.supervisor,
        AppRoutes.admin,
      ])
        GoRoute(path: home, builder: (_, __) => marker('HOME $home')),
      GoRoute(
        path: profilePath,
        builder: (_, __) =>
            StudentProfilePage(studentId: 's1', halaqaId: 'h1', viewer: viewer),
      ),
      GoRoute(
        path: '/teacher/chat/:id',
        builder: (_, s) => marker('TEACHER CHAT ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/admin/chat/:id',
        builder: (_, s) => marker('ADMIN CHAT ${s.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/teacher/halaqa/:h/evaluations',
        builder: (_, s) => marker(
          'EVALUATIONS ${s.pathParameters['h']} '
          '${s.uri.queryParameters['studentId']}',
        ),
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
  return router;
}

/// Location of the top (pushed) route.
String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('StudentProfileViewer capabilities follow AppRouteAccess', () {
    test('evaluations: teacher and supervisor yes, admin no', () {
      expect(StudentProfileViewer.teacher.canOpenEvaluations, isTrue);
      expect(StudentProfileViewer.supervisor.canOpenEvaluations, isTrue);
      expect(StudentProfileViewer.admin.canOpenEvaluations, isFalse);
    });

    test('each viewer maps to its own role', () {
      expect(StudentProfileViewer.teacher.role, AppRoles.teacher);
      expect(StudentProfileViewer.supervisor.role, AppRoles.supervisor);
      expect(StudentProfileViewer.admin.role, AppRoles.admin);
    });

    test('evaluations capability equals AppRouteAccess for every viewer', () {
      for (final viewer in StudentProfileViewer.values) {
        expect(
          viewer.canOpenEvaluations,
          AppRouteAccess.isAllowed(path: _evaluationsPath, role: viewer.role),
          reason: '$viewer',
        );
      }
    });
  });

  group('router guard is unchanged (direct access)', () {
    test('admin is bounced from teacher chat and teacher evaluations', () {
      expect(_redirect(AppRoles.admin, '/teacher/chat/c1'), AppRoutes.admin);
      expect(_redirect(AppRoles.admin, _evaluationsPath), AppRoutes.admin);
      expect(_redirect(AppRoles.admin, '/admin/chat/c1'), isNull);
      expect(_redirect(AppRoles.admin, '/admin/student/s1'), isNull);
    });

    test('supervisor keeps teacher evaluations, not teacher/admin chat', () {
      expect(_redirect(AppRoles.supervisor, _evaluationsPath), isNull);
      expect(
        _redirect(AppRoles.supervisor, '/teacher/chat/c1'),
        AppRoutes.supervisor,
      );
      expect(
        _redirect(AppRoles.supervisor, '/admin/chat/c1'),
        AppRoutes.supervisor,
      );
      expect(
        _redirect(AppRoles.supervisor, '/teacher/student/s1'),
        AppRoutes.supervisor,
      );
    });

    test('teacher keeps its chat, evaluations and profile routes', () {
      for (final path in [
        '/teacher/chat/c1',
        _evaluationsPath,
        '/teacher/student/s1',
      ]) {
        expect(_redirect(AppRoles.teacher, path), isNull, reason: path);
      }
      expect(_redirect(AppRoles.teacher, '/admin/chat/c1'), AppRoutes.teacher);
    });
  });

  group('staff student profile actions per role (real router)', () {
    tearDown(() => sl.reset());

    testWidgets('teacher: contact parent opens the teacher chat route', (
      tester,
    ) async {
      final chat = await _registerFakes();
      final router = await _pumpProfile(
        tester,
        role: AppRoles.teacher,
        profilePath: '/teacher/student/s1',
        viewer: StudentProfileViewer.teacher,
      );

      expect(find.text('التفاصيل'), findsOneWidget);
      await tester.tap(find.text('تواصل مع الأهل'));
      await tester.pumpAndSettle();

      expect(find.text('TEACHER CHAT c1'), findsOneWidget);
      expect(_location(router), '/teacher/chat/c1');
      expect(chat.started.single.currentUser.role, AppRoles.teacher);
      expect(chat.started.single.otherUser.uid, 'p1');
    });

    testWidgets('teacher: details opens evaluations for the student', (
      tester,
    ) async {
      await _registerFakes();
      final router = await _pumpProfile(
        tester,
        role: AppRoles.teacher,
        profilePath: '/teacher/student/s1',
        viewer: StudentProfileViewer.teacher,
      );

      await tester.tap(find.text('التفاصيل'));
      await tester.pumpAndSettle();

      expect(find.text('EVALUATIONS h1 s1'), findsOneWidget);
      expect(_location(router), '/teacher/halaqa/h1/evaluations');
    });

    testWidgets('admin: contact parent lands on the admin chat route', (
      tester,
    ) async {
      final chat = await _registerFakes();
      final router = await _pumpProfile(
        tester,
        role: AppRoles.admin,
        profilePath: '/admin/student/s1',
        viewer: StudentProfileViewer.admin,
      );

      await tester.tap(find.text('تواصل مع الأهل'));
      await tester.pumpAndSettle();

      expect(find.text('ADMIN CHAT c1'), findsOneWidget);
      expect(find.text('HOME ${AppRoutes.admin}'), findsNothing);
      expect(_location(router), '/admin/chat/c1');
      expect(chat.started.single.currentUser.role, AppRoles.admin);
    });

    testWidgets('admin: evaluations action is hidden', (tester) async {
      await _registerFakes();
      await _pumpProfile(
        tester,
        role: AppRoles.admin,
        profilePath: '/admin/student/s1',
        viewer: StudentProfileViewer.admin,
      );

      expect(find.text('تقدم الحفظ'), findsOneWidget);
      expect(find.text('التفاصيل'), findsNothing);
      expect(find.text('تواصل مع الأهل'), findsOneWidget);
    });

    testWidgets('supervisor: details opens the allowed evaluations route', (
      tester,
    ) async {
      await _registerFakes();
      final router = await _pumpProfile(
        tester,
        role: AppRoles.supervisor,
        profilePath: '/supervisor/student/s1',
        viewer: StudentProfileViewer.supervisor,
      );

      expect(find.text('تواصل مع الأهل'), findsOneWidget);
      await tester.tap(find.text('التفاصيل'));
      await tester.pumpAndSettle();

      expect(find.text('EVALUATIONS h1 s1'), findsOneWidget);
      expect(find.text('HOME ${AppRoutes.supervisor}'), findsNothing);
      expect(_location(router), '/teacher/halaqa/h1/evaluations');
    });
  });

  group('staff student profile reads through shared readers', () {
    tearDown(() => sl.reset());

    testWidgets('loaded: same reads in the same order, same values', (
      tester,
    ) async {
      await _registerFakes();
      await _pumpProfile(
        tester,
        role: AppRoles.teacher,
        profilePath: '/teacher/student/s1',
        viewer: StudentProfileViewer.teacher,
      );

      expect(_reads, ['profile s1', 'roster h1', 'recitations s1']);
      expect(AppCapabilities.streakAndLevelAvailable, isFalse);
      expect(find.text('حلقة النور'), findsOneWidget);
      expect(find.textContaining('المستوى'), findsNothing);
      expect(find.text('جزء عم'), findsOneWidget);
      expect(find.text('ولي الأمر'), findsWidgets);
    });

    testWidgets(
      'empty denormalized halaqa name falls back to the halaqa read',
      (tester) async {
        await _registerFakes(
          profile: _Profile([Right(_details(halaqaName: ' '))]),
        );
        await _pumpProfile(
          tester,
          role: AppRoles.supervisor,
          profilePath: '/supervisor/student/s1',
          viewer: StudentProfileViewer.supervisor,
        );

        expect(_reads, [
          'profile s1',
          'roster h1',
          'halaqa h1',
          'recitations s1',
        ]);
        expect(find.text('حلقة الفجر'), findsOneWidget);
        expect(find.textContaining('المستوى'), findsNothing);
      },
    );

    testWidgets('profile failure shows its message; retry reloads', (
      tester,
    ) async {
      await _registerFakes(
        profile: _Profile([
          const Left(ServerFailure('لم يتم العثور على بيانات الطالب')),
          Right(_details()),
        ]),
      );
      await _pumpProfile(
        tester,
        role: AppRoles.admin,
        profilePath: '/admin/student/s1',
        viewer: StudentProfileViewer.admin,
      );

      expect(_reads, ['profile s1']);
      expect(find.text('لم يتم العثور على بيانات الطالب'), findsOneWidget);
      expect(find.text('ملف الطالب'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(_reads, [
        'profile s1',
        'profile s1',
        'roster h1',
        'recitations s1',
      ]);
      expect(find.text('حلقة النور'), findsOneWidget);
      expect(find.textContaining('المستوى'), findsNothing);
    });
  });

  group('page ownership and wiring (source)', () {
    test('the page resolves only the shared readers for student data', () {
      final page = File(_pagePath).readAsStringSync();
      expect(page, contains('sl<StudentProfileDetailsReader>()'));
      expect(page, contains('sl<HalaqaNameReader>()'));
      expect(page, contains('sl<RecitationRecordsReader>()'));
      for (final old in [
        'StudentProfileEntity',
        'GetStudentProfileUseCase',
        'GetStudentHalaqaUseCase',
        'GetRecitationRecordsUseCase',
      ]) {
        expect(page, isNot(contains(old)), reason: old);
      }
    });

    test('exactly one StudentProfilePage, under the staff module', () {
      final declaring = <String>[];
      final importsOldPath = <String>[];
      for (final dir in ['lib', 'test']) {
        for (final file
            in Directory(dir)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))) {
          final source = file.readAsStringSync();
          final path = file.path.replaceAll(r'\', '/');
          if (path.endsWith('staff_student_profile_navigation_test.dart')) {
            continue;
          }
          if (source.contains('class StudentProfilePage ')) {
            declaring.add(path);
          }
          if (source.contains(
            'student/presentation/pages/student_profile_page',
          )) {
            importsOldPath.add(path);
          }
        }
      }
      expect(declaring, [_pagePath]);
      expect(importsOldPath, isEmpty);
      expect(
        File(
          'lib/features/student/presentation/pages/student_profile_page.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('every entry point passes its own viewer', () {
      final router = File(
        'lib/core/router/router_app.dart',
      ).readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      expect(router, contains('viewer:StudentProfileViewer.teacher,'));
      expect(router, contains('viewer:StudentProfileViewer.admin,'));
      expect(
        File(
          'lib/features/supervisor/presentation/supervisor_destinations.dart',
        ).readAsStringSync(),
        contains('viewer: StudentProfileViewer.supervisor,'),
      );
    });

    test('supervisor opens the parent chat in-feature, like follow-up', () {
      final page = File(_pagePath).readAsStringSync();
      expect(page, contains('deps: StaffParentContactDeps('));
      expect(
        page,
        contains('chatRoom: (conversation, parent) => ChatRoomPage('),
      );
      expect(
        File(
          'lib/features/supervisor/presentation/pages/supervisor_follow_up_page.dart',
        ).readAsStringSync(),
        contains('builder: (_) => ChatRoomPage('),
      );
    });

    test('teacher class details uses the staff contact flow', () {
      final classDetail = File(
        'lib/features/teacher/presentation/pages/teacher_class_detail_page.dart',
      ).readAsStringSync();
      expect(
        classDetail,
        contains(
          "import '../../../staff/contact_parent/contact_student_parent.dart';",
        ),
      );
      expect(classDetail, contains('deps: StaffParentContactDeps('));
      expect(
        File(
          'lib/features/teacher/presentation/teacher_contact_parent.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('the staff module imports no parent, admin, supervisor, teacher or '
        'student code', () {
      for (final file
          in Directory('lib/features/staff')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final imports = RegExp(
          r"^import '([^']+)'",
          multiLine: true,
        ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!);
        for (final role in [
          '/parent/',
          '/admin/',
          '/supervisor/',
          '/teacher/',
          '/student/',
        ]) {
          expect(
            imports.where((u) => u.contains(role)),
            isEmpty,
            reason: '${file.path} $role',
          );
        }
      }
    });
  });
}

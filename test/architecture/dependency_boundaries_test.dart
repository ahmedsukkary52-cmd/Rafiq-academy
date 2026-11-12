import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_import_graph.dart';
import 'support/git_blob_hash.dart';

const _package = 'rafiq_academy';

// ---------------------------------------------------------------------------
// Allowlists. Keys are exact `source -> target` edges (lib/-relative). Adding,
// removing or retargeting an edge fails the guard; update these deliberately.
// ---------------------------------------------------------------------------

const _supervisorHalaqaPage =
    'features/supervisor/presentation/pages/supervisor_halaqa_detail_page.dart';
const _teacherResolver =
    'features/teacher/domain/services/teacher_admin_announcement_resolver.dart';
const _adminOpsBroadcast = 'features/admin/domain/admin_ops_broadcast.dart';
const _adminOpsUseCases =
    'features/admin/domain/usecases/admin_operations_usecases.dart';
const _adminOpsEntities =
    'features/admin/domain/entities/admin_operations_entities.dart';

const _crossRoleAllowlist = {
  '$_supervisorHalaqaPage -> $_adminOpsUseCases':
      'Supervisor meeting-link edit calls the admin-owned '
      'SetHalaqaMeetingLinkUseCase (canonical halaqaMeetingLinks writer).',
  '$_supervisorHalaqaPage -> $_adminOpsEntities':
      'meetingLinkChangeMessage(MeetingLinkChange) for the success message '
      'of the same use case.',
  '$_teacherResolver -> $_adminOpsBroadcast':
      'A-H15 protected exception: reads AdminOpsBroadcast.channel only. '
      'Quarantined; no owner assigned.',
};

const _teacherBloc = 'features/teacher/presentation/bloc/teacher_bloc.dart';
const _teacherSkeletons =
    'features/teacher/presentation/widgets/teacher_loading_skeletons.dart';
const _studentBloc = 'features/student/presentation/bloc/student_bloc.dart';
const _studentSkeletons =
    'features/student/presentation/widgets/student_loading_skeletons.dart';
const _awardsPage = 'features/awards/presentation/pages/awards_page.dart';
const _awardGrantScope = 'features/awards/domain/award_grant_scope.dart';
const _teacherAwardGrantScope =
    'features/teacher/presentation/teacher_award_grant_scope.dart';
const _studentChatPage =
    'features/chat/presentation/pages/student_chat_page.dart';
const _studentChatTeacher = 'features/chat/domain/student_chat_teacher.dart';
const _studentChatTeacherResolver =
    'features/student/presentation/student_chat_teacher_resolver.dart';
const _studentHomeworkPage =
    'features/homework/presentation/pages/student_homework_page.dart';
const _studentSchedulePage =
    'features/schedule/presentation/pages/student_schedule_page.dart';
const _halaqaMeetingJoin =
    'features/student/presentation/widgets/halaqa_meeting_join.dart';
const _currentStudentProfile = 'shared/domain/current_student_profile.dart';
const _studentBlocCurrentProfile =
    'features/student/presentation/student_bloc_current_profile.dart';
const _mushafReaderHost =
    'features/mushaf/presentation/pages/mushaf_reader_host.dart';
const _mushafMode = 'features/mushaf/presentation/mushaf_mode.dart';
const _studentMushafPage =
    'features/student/presentation/pages/student_mushaf_page.dart';
const _studentHomePage =
    'features/student/presentation/pages/student_home_page.dart';

/// Non-role, non-core files (features, shared, staff, main.dart) that import
/// a role module.
const _featureToRoleAllowlist = {
  'features/progress_report/presentation/bloc/progress_report_bloc.dart -> '
          'features/student/domain/usecases/get_student_profile_usecase.dart':
      'Progress report reads overallProgressPercent from the student '
      'profile. Deferred: the generated DI config (OA-56, not regenerated) '
      'passes GetStudentProfileUseCase to this constructor.',
  '$_studentSchedulePage -> $_halaqaMeetingJoin':
      'Student schedule renders the meeting join widget.',
  'main.dart -> features/admin/presentation/bloc/admin_bloc.dart':
      'App root provides role blocs (composition root).',
  'main.dart -> features/parent/presentation/bloc/parent_bloc.dart':
      'App root provides role blocs (composition root).',
  'main.dart -> $_studentBloc':
      'App root provides role blocs (composition root).',
  'main.dart -> features/supervisor/presentation/bloc/supervisor_bloc.dart':
      'App root provides role blocs (composition root).',
  'main.dart -> $_teacherBloc':
      'App root provides role blocs (composition root).',
  'main.dart -> $_teacherAwardGrantScope':
      'App root adapts TeacherBloc into the role-neutral AwardGrantScopeSource '
      'that award sheets receive (composition root).',
};

const _clampedAllowlist = {
  'features/analytics/domain/analytics_recitation_honesty.dart -> '
      'core/constants/app_constants.dart',
  'features/parent/domain/absence_request_projection.dart -> '
      'shared/domain/absence_request_projection.dart',
  'shared/domain/academy_membership_invariant.dart -> '
      'core/constants/app_constants.dart',
  'shared/domain/payment_access_entity.dart -> '
      'shared/domain/payment_access_contract.dart',
  'shared/widgets/student_header_widget.dart -> shared/theme/app_theme.dart',
  'shared/widgets/student_last_evaluation_widget.dart -> '
      'shared/theme/app_theme.dart',
  'shared/widgets/student_last_evaluation_widget.dart -> '
      'shared/widgets/shared_widgets.dart',
  'shared/widgets/student_progress_widget.dart -> shared/theme/app_theme.dart',
  'shared/widgets/student_quick_action_widget.dart -> '
      'shared/theme/app_theme.dart',
  'shared/widgets/student_session_card_widget.dart -> '
      'shared/theme/app_theme.dart',
};

const _diConfig = 'core/di/injection_container.config.dart';
const _diContainer = 'core/di/injection_container.dart';
const _diModule = 'core/di/di_module.dart';
const _router = 'core/router/router_app.dart';
const _appRoutes = 'core/router/app_routes.dart';
const _clearSession = 'core/session/clear_session_projections.dart';
const _escalationPaths = 'core/router/supervisor_escalation_paths.dart';

const _diModuleTargets = {
  'features/parent/domain/repositories/parent_repositories.dart',
  'features/student/data/repositories/student_halaqa_name_reader_impl.dart',
  'features/student/data/repositories/student_profile_details_reader_impl.dart',
  'features/student/data/repositories/student_profile_summary_reader_impl.dart',
  'features/student/domain/repositories/student_repository.dart',
  'features/supervisor/domain/repositories/parent_repository.dart',
  'features/teacher/domain/repositories/teacher_repository.dart',
};

const _staffProfilePage =
    'features/staff/student_profile/presentation/pages/student_profile_page.dart';
const _staffProfileViewer =
    'features/staff/student_profile/presentation/student_profile_viewer.dart';

/// Committed blobs at 796e3de (the quarantined A-H15 state). Pinned as
/// "unchanged since quarantine", not as reviewed-correct content.
const _ah15Blobs = {
  'lib/features/admin/domain/admin_ops_broadcast.dart':
      '5edf22c2da6ebe11cf6c65fa48ce62fa4699a21a',
  'lib/features/teacher/domain/services/'
          'teacher_admin_announcement_resolver.dart':
      '1c30a6fa1a969b8d6f653358c1b91c8042efa781',
  'test/features/admin/admin_ops_broadcast_test.dart':
      '4836ce1110b4cb624206feb3f249958de3ed3039',
  'test/features/teacher/teacher_admin_announcement_resolver_test.dart':
      '95bbda68b29caadba7e4a437d864d21316f61409',
};

// ---------------------------------------------------------------------------
// Rules, as functions over a graph so fixtures exercise the same code.
// ---------------------------------------------------------------------------

bool _isCoreDi(String f) => f.startsWith('core/di/');

bool _isCoreRouter(String f) => f.startsWith('core/router/');

bool _isSkeletonFile(String f) => f.split('/').last.contains('skeleton');

/// Imports of a role module's skeleton files from any other module.
List<ImportEdge> foreignRoleSkeletonImports(DartImportGraph g) => [
  for (final e in g.allEdges)
    if (isRoleFile(e.target) &&
        _isSkeletonFile(e.target) &&
        moduleOf(e.source) != moduleOf(e.target))
      e,
];

/// Importers of `router_app.dart` that reference none of its own public
/// declarations (they need only the constants in `app_routes.dart`).
List<String> constantsOnlyRouterImporters(
  DartImportGraph g,
  String Function(String file) read,
) {
  final routerNames = declaredNames(read(_router));
  return [
    for (final e in g.importersOf(_router))
      if (referencedNames(read(e.source), routerNames).isEmpty) e.toString(),
  ]..sort();
}

/// Message for differences between [actual] edges and an exact [allowed] set;
/// null when they match.
String? exactEdgeDiff(Iterable<ImportEdge> actual, Iterable<String> allowed) {
  final byKey = <String, ImportEdge>{for (final e in actual) e.key: e};
  final allowedSet = allowed.toSet();
  final unapproved = [
    for (final entry in byKey.entries)
      if (!allowedSet.contains(entry.key)) entry.value.toString(),
  ]..sort();
  final missing = [
    for (final key in allowedSet)
      if (!byKey.containsKey(key)) key,
  ]..sort();
  if (unapproved.isEmpty && missing.isEmpty) return null;
  return [
    if (unapproved.isNotEmpty) ...[
      'Unapproved imports (source:line -> target):',
      for (final u in unapproved) '  $u',
    ],
    if (missing.isNotEmpty) ...[
      'Approved edges no longer present (remove them from the allowlist):',
      for (final m in missing) '  $m',
    ],
  ].join('\n');
}

Iterable<ImportEdge> crossRoleEdges(DartImportGraph g) => g.allEdges.where(
  (e) =>
      isRoleFile(e.source) &&
      isRoleFile(e.target) &&
      moduleOf(e.source) != moduleOf(e.target),
);

Iterable<ImportEdge> nonRoleToRoleEdges(DartImportGraph g) => g.allEdges.where(
  (e) =>
      !isRoleFile(e.source) &&
      moduleOf(e.source) != 'core' &&
      isRoleFile(e.target),
);

/// Import chains from [starts] to files matching [blocked]; blocked files are
/// reported, not followed.
List<String> forbiddenReach(
  DartImportGraph g,
  Iterable<String> starts,
  bool Function(String file) blocked,
) {
  final closure = g.closure(starts, expand: (f) => !blocked(f));
  return [
    for (final f in closure.files)
      if (blocked(f)) closure.chainTo(f),
  ]..sort();
}

/// Edges by which the closure of [starts] enters a role module. Files for
/// which [stop] is true are reached but not followed.
List<ImportEdge> roleEntryEdges(
  DartImportGraph g,
  Iterable<String> starts, {
  bool Function(String file)? stop,
}) {
  bool follow(String f) => !isRoleFile(f) && !(stop?.call(f) ?? false);
  final closure = g.closure(starts, expand: follow);
  return [
    for (final f in closure.files)
      if (follow(f))
        for (final e in g.importsOf(f))
          if (isRoleFile(e.target)) e,
  ];
}

/// Top-level names declared in formatted [source]: types, plus functions,
/// getters and variables starting at column 0 (comments and strings ignored).
Set<String> declaredNames(String source) {
  final code = codeWithoutCommentsAndStrings(source);
  final types = RegExp(
    r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
    r'(?:class|enum|mixin|typedef|extension(?:\s+type)?)\s+([A-Za-z][\w$]*)',
    multiLine: true,
  );
  final members = RegExp(
    r'^(?!(?:import|export|part|library|class|enum|mixin|typedef|extension|'
    r'abstract|sealed|base|interface)\b)'
    r'(?:[\w$][\w$<>?,. ]*?\s+)?(?:get\s+)?([A-Za-z_][\w$]*)\s*(?:<[^>\n]*>)?\s*[(=;]',
    multiLine: true,
  );
  return {
    for (final m in types.allMatches(code)) m[1]!,
    for (final m in members.allMatches(code))
      if (!m[1]!.startsWith('_')) m[1]!,
  };
}

/// Which of [names] appear as identifiers in the code of [source].
Set<String> referencedNames(String source, Iterable<String> names) {
  final code = codeWithoutCommentsAndStrings(source);
  return {
    for (final n in names)
      if (RegExp('(?<![\\w\$])${RegExp.escape(n)}(?![\\w\$])').hasMatch(code))
        n,
  };
}

String _lib(String path) => File('lib/$path').readAsStringSync();

void main() {
  late DartImportGraph graph;

  setUpAll(() {
    graph = DartImportGraph.load('lib', packageName: _package);
  });

  group('import graph integrity', () {
    test('every project-local import resolves to an existing file', () {
      expect(
        graph.unresolved.map((e) => e.toString()).toList(),
        isEmpty,
        reason: 'Unresolved project-local imports (source:line -> missing).',
      );
      expect(graph.invalid, isEmpty, reason: 'Unresolvable import URIs.');
      expect(graph.files, contains('main.dart'));
    });

    test('imports climbing above lib/ are exactly the known 10', () {
      final diff = exactEdgeDiff(
        graph.allEdges.where((e) => e.clamped),
        _clampedAllowlist,
      );
      expect(
        diff,
        isNull,
        reason:
            'Relative imports with more `..` than the file depth resolve '
            'only because Dart clamps at the package root.\n$diff',
      );
    });
  });

  group('A: cross-role imports', () {
    test('are exactly the 3 approved edges', () {
      final diff = exactEdgeDiff(
        crossRoleEdges(graph),
        _crossRoleAllowlist.keys,
      );
      expect(diff, isNull, reason: diff);
    });

    test('supervisor page uses only the meeting-link admin symbols', () {
      final adminNames = {
        ...declaredNames(_lib(_adminOpsUseCases)),
        ...declaredNames(_lib(_adminOpsEntities)),
      };
      expect(adminNames, contains('MeetingLinkChange'));
      expect(
        referencedNames(_lib(_supervisorHalaqaPage), adminNames),
        {
          'SetHalaqaMeetingLinkUseCase',
          'SetHalaqaMeetingLinkParams',
          'meetingLinkChangeMessage',
        },
        reason:
            '$_supervisorHalaqaPage references admin symbols beyond the '
            'approved meeting-link use case.',
      );
    });

    test('A-H15: teacher resolver reads only AdminOpsBroadcast.channel', () {
      final code = codeWithoutCommentsAndStrings(_lib(_teacherResolver));
      final members = RegExp(
        r'AdminOpsBroadcast\s*\.\s*(\w+)',
      ).allMatches(code).map((m) => m[1]).toList();
      final bare = RegExp(
        r'(?<![\w$])AdminOpsBroadcast(?![\w$])',
      ).allMatches(code).length;
      expect(members, ['channel'], reason: _teacherResolver);
      expect(bare, members.length, reason: _teacherResolver);
    });

    test('A-H15: admin_ops_broadcast importers and imports are exact', () {
      final diffIn = exactEdgeDiff(graph.importersOf(_adminOpsBroadcast), {
        'features/admin/data/datasources/admin_remote_datasource_impl.dart -> '
            '$_adminOpsBroadcast',
        '$_teacherResolver -> $_adminOpsBroadcast',
      });
      expect(
        diffIn,
        isNull,
        reason: 'Importers of $_adminOpsBroadcast\n$diffIn',
      );
      final diffOut = exactEdgeDiff(graph.importsOf(_adminOpsBroadcast), {
        '$_adminOpsBroadcast -> core/constants/app_constants.dart',
      });
      expect(
        diffOut,
        isNull,
        reason: 'Imports of $_adminOpsBroadcast\n$diffOut',
      );
    });
  });

  group('B: feature -> role imports', () {
    test('are exactly the 2 approved edges plus 6 in main.dart', () {
      expect(_featureToRoleAllowlist, hasLength(8));
      final diff = exactEdgeDiff(
        nonRoleToRoleEdges(graph),
        _featureToRoleAllowlist.keys,
      );
      expect(diff, isNull, reason: diff);
    });
  });

  group('C: core -> role imports', () {
    Map<String, List<ImportEdge>> coreRoleImports() {
      final out = <String, List<ImportEdge>>{};
      for (final e in graph.allEdges) {
        if (moduleOf(e.source) != 'core') continue;
        if (!isRoleFile(e.target) && moduleOf(e.target) != 'staff') continue;
        out.putIfAbsent(e.source, () => []).add(e);
      }
      return out;
    }

    test('only the 4 known core files import role or staff modules', () {
      expect(coreRoleImports().keys.toSet(), {
        _diConfig,
        _diModule,
        _router,
        _clearSession,
      });
    });

    test('generated DI config is reached only via injection_container', () {
      expect(
        exactEdgeDiff(graph.importersOf(_diConfig), {
          '$_diContainer -> $_diConfig',
        }),
        isNull,
      );
      expect(
        exactEdgeDiff(graph.importsOf(_diContainer), {
          '$_diContainer -> $_diConfig',
        }),
        isNull,
      );
      final ui = coreRoleImports()[_diConfig]!.where(
        (e) =>
            e.target.contains('/presentation/pages/') ||
            e.target.contains('/presentation/widgets/') ||
            moduleOf(e.target) == 'staff',
      );
      final diff = exactEdgeDiff(ui, {
        // OA-56: stray @injectable on the page; removal needs a DI regen.
        '$_diConfig -> '
            'features/student/presentation/pages/student_audio_library_page.dart',
      });
      expect(
        diff,
        isNull,
        reason: 'DI config must not import UI files.\n$diff',
      );
    });

    test('di_module imports exactly 7 role repositories/readers', () {
      final targets = coreRoleImports()[_diModule]!
          .map((e) => e.target)
          .toSet();
      expect(targets, _diModuleTargets);
      for (final t in targets) {
        expect(t, matches(RegExp(r'/(domain|data)/repositories/')), reason: t);
      }
    });

    test('router_app imports only role/staff presentation files', () {
      final edges = coreRoleImports()[_router]!;
      final nonPresentation = edges
          .where((e) => !e.target.contains('/presentation/'))
          .map((e) => e.toString());
      expect(nonPresentation, isEmpty);
      expect(
        edges
            .where((e) => moduleOf(e.target) == 'staff')
            .map((e) => e.target)
            .toSet(),
        {_staffProfilePage, _staffProfileViewer},
      );
    });

    test(
      'clear_session_projections imports exactly the 5 role blocs+events',
      () {
        expect(coreRoleImports()[_clearSession]!.map((e) => e.target).toSet(), {
          for (final role in roleModules)
            for (final part in ['bloc', 'event'])
              'features/$role/presentation/bloc/${role}_$part.dart',
        });
      },
    );

    test('supervisor_escalation_paths has no project imports', () {
      expect(graph.importsOf(_escalationPaths), isEmpty);
    });
  });

  group('D: staff module', () {
    Iterable<String> staffFiles() =>
        graph.files.where((f) => moduleOf(f) == 'staff');

    test('no staff file imports a role module directly', () {
      final direct = [
        for (final f in staffFiles())
          for (final e in graph.importsOf(f))
            if (isRoleFile(e.target)) e.toString(),
      ];
      expect(direct, isEmpty);
    });

    test('staff reaches no role module (composition root excluded)', () {
      final entries = roleEntryEdges(
        graph,
        staffFiles(),
        stop: (f) => f == _diContainer,
      );
      final diff = exactEdgeDiff(entries, const <String>[]);
      expect(diff, isNull, reason: diff);
      final closure = graph.closure(
        staffFiles(),
        expand: (f) => !isRoleFile(f) && f != _diContainer,
      );
      expect(
        closure.contains(_router),
        isFalse,
        reason: closure.chainTo(_router),
      );
    });

    test(
      'only the staff profile page couples to the composition root (sl)',
      () {
        final direct = [
          for (final f in staffFiles())
            for (final e in graph.importsOf(f))
              if (_isCoreDi(e.target)) e.key,
        ];
        expect(direct, ['$_staffProfilePage -> $_diContainer']);
        final reachesConfig = {
          for (final f in staffFiles())
            if (graph.closure([f]).contains(_diConfig)) f,
        };
        expect(reachesConfig, {_staffProfilePage});
      },
    );

    test('every other staff file has a role-, DI- and router-free closure', () {
      final offenders = forbiddenReach(
        graph,
        staffFiles().where((f) => f != _staffProfilePage),
        (f) => isRoleFile(f) || _isCoreDi(f) || f == _router,
      );
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('E: shared module', () {
    test('reaches no role module or core/di, directly or transitively', () {
      final shared = graph.files.where((f) => moduleOf(f) == 'shared');
      expect(shared, isNotEmpty);
      final offenders = forbiddenReach(
        graph,
        shared,
        (f) => isRoleFile(f) || _isCoreDi(f),
      );
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('reaches no core/router file, directly or transitively', () {
      final offenders = forbiddenReach(
        graph,
        graph.files.where((f) => moduleOf(f) == 'shared'),
        _isCoreRouter,
      );
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('G: route constants vs router implementation', () {
    test('app_routes holds the constants; router_app only AppRouter', () {
      expect(declaredNames(_lib(_appRoutes)), {
        'AppRoutes',
        'AppRouteAccess',
        'AuthRedirect',
      });
      expect(declaredNames(_lib(_router)), {'AppRouter'});
      expect(
        parseDirectives(_lib(_router)).where((d) => d.kind == 'export'),
        isEmpty,
        reason: '$_router must not re-export the constants.',
      );
    });

    test('app_routes is import-light and role-neutral', () {
      final diff = exactEdgeDiff(graph.importsOf(_appRoutes), {
        '$_appRoutes -> features/auth/presentation/bloc/auth_state.dart',
        '$_appRoutes -> core/constants/app_constants.dart',
        '$_appRoutes -> $_escalationPaths',
      });
      expect(diff, isNull, reason: diff);
      final offenders = forbiddenReach(
        graph,
        [_appRoutes],
        (f) =>
            isRoleFile(f) ||
            moduleOf(f) == 'staff' ||
            _isCoreDi(f) ||
            f == _router ||
            f.contains('/presentation/pages/') ||
            f.contains('/presentation/widgets/'),
      );
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('only main.dart imports router_app in lib/', () {
      final diff = exactEdgeDiff(graph.importersOf(_router), {
        'main.dart -> $_router',
      });
      expect(diff, isNull, reason: diff);
      final constantsOnly = constantsOnlyRouterImporters(graph, _lib);
      expect(
        constantsOnly,
        isEmpty,
        reason:
            'Import core/router/app_routes.dart for route constants:\n'
            '${constantsOnly.join('\n')}',
      );
    });

    test('tests import router_app only when they use AppRouter', () {
      final routerNames = declaredNames(_lib(_router));
      final offenders = <String>[];
      final importers = <String>[];
      for (final f in Directory('test').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final source = f.readAsStringSync();
        final imports = parseDirectives(source).where(
          (d) =>
              d.kind == 'import' &&
              (d.uri == 'package:$_package/$_router' ||
                  (!d.uri.contains(':') && d.uri.endsWith('/router_app.dart'))),
        );
        if (imports.isEmpty) continue;
        final path = normalizePath(f.path);
        importers.add(path);
        if (referencedNames(source, routerNames).isEmpty) offenders.add(path);
      }
      expect(importers, isNotEmpty);
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('H: loading-skeleton ownership', () {
    test('no module imports another module\'s role-owned skeletons', () {
      final foreign = foreignRoleSkeletonImports(graph).map((e) => '$e');
      expect(
        foreign,
        isEmpty,
        reason:
            'Move reusable skeletons to shared/widgets or the consuming '
            'feature:\n${foreign.join('\n')}',
      );
    });

    test('skeleton files outside role modules are role-, DI- and '
        'router-free', () {
      final neutral = graph.files.where(
        (f) => _isSkeletonFile(f) && !isRoleFile(f),
      );
      expect(
        neutral,
        containsAll([
          'shared/widgets/app_skeleton.dart',
          'shared/widgets/student_page_skeletons.dart',
          'features/awards/presentation/widgets/awards_loading_skeletons.dart',
          'features/notifications/presentation/widgets/'
              'notifications_list_skeleton.dart',
          'features/post/presentation/widgets/posts_list_skeleton.dart',
        ]),
      );
      final offenders = forbiddenReach(
        graph,
        neutral,
        (f) => isRoleFile(f) || _isCoreDi(f) || _isCoreRouter(f),
      );
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('each skeleton is declared once, in its owning module', () {
      final declaredIn = <String, List<String>>{};
      for (final f in graph.files) {
        for (final name in declaredNames(_lib(f))) {
          if (name.toLowerCase().contains('skeleton')) {
            declaredIn.putIfAbsent(name, () => []).add(f);
          }
        }
      }
      final duplicates = {
        for (final entry in declaredIn.entries)
          if (entry.value.length > 1) entry.key: entry.value,
      };
      expect(duplicates, isEmpty, reason: '$duplicates');
      const owners = {
        'TeacherAwardsDashboardSkeleton':
            'features/awards/presentation/widgets/awards_loading_skeletons.dart',
        'TeacherAwardsHistorySkeleton':
            'features/awards/presentation/widgets/awards_loading_skeletons.dart',
        'TeacherNotificationsListSkeleton':
            'features/notifications/presentation/widgets/'
            'notifications_list_skeleton.dart',
        'TeacherPostsListSkeleton':
            'features/post/presentation/widgets/posts_list_skeleton.dart',
        'StudentListPageSkeleton': 'shared/widgets/student_page_skeletons.dart',
        'StudentHomeBodySkeleton': 'shared/widgets/student_page_skeletons.dart',
        'AppSkeletonCard': 'shared/widgets/app_skeleton.dart',
      };
      owners.forEach((name, file) {
        expect(declaredIn[name], [file], reason: name);
      });
    });
  });

  group('I: award grant scope', () {
    test('the awards module reaches no role module (composition root '
        'excluded)', () {
      final entries = roleEntryEdges(
        graph,
        graph.files.where((f) => moduleOf(f) == 'awards'),
        stop: (f) => f == _diContainer,
      );
      final diff = exactEdgeDiff(entries, const <String>[]);
      expect(diff, isNull, reason: diff);
    });

    test('CreateAwardSheet takes halaqat from AwardGrantScopeSource, not '
        'TeacherBloc', () {
      final source = _lib(_awardsPage);
      expect(declaredNames(source), contains('CreateAwardSheet'));
      expect(referencedNames(source, ['TeacherBloc', 'TeacherState']), isEmpty);
      expect(referencedNames(source, ['AwardGrantScopeSource']), {
        'AwardGrantScopeSource',
      });
    });

    test('award_grant_scope is pure awards domain', () {
      expect(
        exactEdgeDiff(graph.importsOf(_awardGrantScope), {
          '$_awardGrantScope -> '
              'features/awards/domain/award_recipient_selection.dart',
        }),
        isNull,
      );
      expect(
        parseDirectives(
          _lib(_awardGrantScope),
        ).where((d) => d.uri.startsWith('package:')).map((d) => d.uri),
        isEmpty,
      );
    });

    test('only main.dart wires the teacher adapter', () {
      final diff = exactEdgeDiff(graph.importersOf(_teacherAwardGrantScope), {
        'main.dart -> $_teacherAwardGrantScope',
      });
      expect(diff, isNull, reason: diff);
    });
  });

  group('J: student chat teacher', () {
    test('the chat module reaches no role module (composition root '
        'excluded)', () {
      final entries = roleEntryEdges(
        graph,
        graph.files.where((f) => moduleOf(f) == 'chat'),
        stop: (f) => f == _diContainer,
      );
      final diff = exactEdgeDiff(entries, const <String>[]);
      expect(diff, isNull, reason: diff);
    });

    test(
      'StudentChatPage takes its teacher from StudentChatTeacherResolver',
      () {
        final source = _lib(_studentChatPage);
        expect(
          referencedNames(source, [
            'StudentBloc',
            'StudentState',
            'GetStudentHalaqaUseCase',
          ]),
          isEmpty,
        );
        expect(referencedNames(source, ['StudentChatTeacherResolver']), {
          'StudentChatTeacherResolver',
        });
      },
    );

    test('the chat teacher contract has no imports', () {
      expect(parseDirectives(_lib(_studentChatTeacher)), isEmpty);
    });

    test('only router_app wires the student resolver', () {
      final diff = exactEdgeDiff(
        graph.importersOf(_studentChatTeacherResolver),
        {'$_router -> $_studentChatTeacherResolver'},
      );
      expect(diff, isNull, reason: diff);
    });
  });

  group('K: current student profile (homework, schedule)', () {
    test('homework does not enter the student module', () {
      final entries = roleEntryEdges(
        graph,
        graph.files.where((f) => moduleOf(f) == 'homework'),
        stop: (f) => f == _diContainer,
      );
      final diff = exactEdgeDiff(entries, const <String>{});
      expect(diff, isNull, reason: diff);
    });

    test('schedule enters the student module only through the meeting '
        'join', () {
      final entries = roleEntryEdges(
        graph,
        graph.files.where((f) => moduleOf(f) == 'schedule'),
        stop: (f) => f == _diContainer,
      );
      final diff = exactEdgeDiff(entries, {
        '$_studentSchedulePage -> $_halaqaMeetingJoin',
      });
      expect(diff, isNull, reason: diff);
    });

    test('schedule reads the profile through CurrentStudentProfile', () {
      final source = _lib(_studentSchedulePage);
      expect(
        referencedNames(source, ['StudentBloc', 'StudentState']),
        isEmpty,
      );
      expect(referencedNames(source, ['CurrentStudentProfile']), {
        'CurrentStudentProfile',
      });
    });

    test('homework reads no student profile', () {
      expect(
        referencedNames(_lib(_studentHomeworkPage), [
          'StudentBloc',
          'StudentState',
          'CurrentStudentProfile',
        ]),
        isEmpty,
      );
    });

    test('the current student profile contract has no imports', () {
      expect(parseDirectives(_lib(_currentStudentProfile)), isEmpty);
    });

    test('only router_app wires the StudentBloc adapter', () {
      final diff = exactEdgeDiff(
        graph.importersOf(_studentBlocCurrentProfile),
        {'$_router -> $_studentBlocCurrentProfile'},
      );
      expect(diff, isNull, reason: diff);
    });
  });

  group('L: mushaf reader host', () {
    test('the mushaf module reaches no role module (composition root '
        'excluded)', () {
      final entries = roleEntryEdges(
        graph,
        graph.files.where((f) => moduleOf(f) == 'mushaf'),
        stop: (f) => f == _diContainer,
      );
      final diff = exactEdgeDiff(entries, const <String>[]);
      expect(diff, isNull, reason: diff);
    });

    test('MushafReaderHost takes its reader from MushafReaderBuilder', () {
      final source = _lib(_mushafReaderHost);
      expect(declaredNames(source), contains('MushafReaderHost'));
      expect(
        referencedNames(source, ['StudentMushafPage', 'AyahModel']),
        isEmpty,
      );
      expect(referencedNames(source, ['MushafReaderBuilder', 'MushafMode']), {
        'MushafReaderBuilder',
        'MushafMode',
      });
    });

    test('MushafMode is declared only in the mushaf feature', () {
      expect(parseDirectives(_lib(_mushafMode)), isEmpty);
      final declaring = graph.files
          .where((f) => declaredNames(_lib(f)).contains('MushafMode'))
          .toList();
      expect(declaring, [_mushafMode]);
    });

    test('only the student entry points import the student mushaf page', () {
      final diff = exactEdgeDiff(graph.importersOf(_studentMushafPage), {
        '$_router -> $_studentMushafPage',
        '$_studentHomePage -> $_studentMushafPage',
      });
      expect(diff, isNull, reason: diff);
    });
  });

  group('F: A-H15 protected state', () {
    test('protected files are byte-identical to the quarantined commit', () {
      _ah15Blobs.forEach((path, blob) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        expect(
          gitBlobId(file.readAsBytesSync()),
          blob,
          reason:
              '$path changed since quarantine (796e3de). A-H15 files must '
              'not be edited without an owner decision.',
        );
      });
    });
  });

  group('guard machinery', () {
    test('sha1 and git blob ids match known vectors', () {
      expect(
        sha1Hex(ascii.encode('abc')),
        'a9993e364706816aba3e25717850c26c9cd0d89d',
      );
      expect(sha1Hex(const []), 'da39a3ee5e6b4b0d3255bfef95601890afd80709');
      expect(
        sha1Hex(List.filled(1000, 0x61)),
        '291e9a6c66994949b57ba5e650361e98fc36b1ba',
      );
      expect(
        gitBlobId(ascii.encode('hello\n')),
        'ce013625030ba8dba906f756967f9e9ca394464a',
      );
      expect(
        gitBlobId(ascii.encode('hello\r\n')),
        'ce013625030ba8dba906f756967f9e9ca394464a',
      );
    });

    test('directives: comments, strings and code are ignored', () {
      const source = '''
#!/usr/bin/env dart
// import 'line_comment.dart';
/* import 'block.dart'; /* nested 'x.dart' */ */
@Deprecated('library "fake.dart"')
library sample;

import "double.dart";
import r'raw.dart';
import 'multi.dart'
    show A,
        B;
import 'conditional_a.dart'
    if (dart.library.io) 'conditional_b.dart'
    if (dart.library.html) 'conditional_c.dart' as c;
export 'exported.dart' hide Z;
part 'part.dart';

const s = "import 'in_string.dart';";
// import 'after.dart';
void f() {}
import 'after_code.dart';
''';
      final directives = parseDirectives(source);
      expect(directives.map((d) => '${d.kind}:${d.uri}').toList(), [
        'import:double.dart',
        'import:raw.dart',
        'import:multi.dart',
        'import:conditional_a.dart',
        'import:conditional_b.dart',
        'import:conditional_c.dart',
        'export:exported.dart',
        'part:part.dart',
      ]);
      expect(directives.first.line, 7);
      expect(
        parseDirectives(
          "part of 'lib.dart';\nimport 'x.dart';",
        ).map((d) => d.uri),
        ['x.dart'],
      );
      expect(
        () => parseDirectives("import 'open.dart;\n"),
        throwsFormatException,
      );
    });

    test('code search ignores comments and strings', () {
      const source = '''
/// Uses [Hidden] in docs.
final a = 'Hidden'; // Hidden
final b = Visible();
''';
      expect(referencedNames(source, ['Hidden', 'Visible']), {'Visible'});
      const interpolated = r'''
final a = '${flag ? 'Hidden' : "Text"} and ${Outer.member} {Braces}';
final b = "$Simple Hidden";
final c = r'${RawHidden}';
final d = """multi ${'nested ${Deep.x}'} line""";
''';
      expect(
        referencedNames(interpolated, [
          'Hidden',
          'Text',
          'Outer',
          'Braces',
          'Simple',
          'RawHidden',
          'Deep',
          'flag',
        ]),
        {'Outer', 'Simple', 'Deep', 'flag'},
      );
      const declarations = '''
import 'x.dart';

/// class Doc {}
@immutable
sealed class Sealed {
  void member() {}
}
enum Kind { a, b }
typedef Cb = void Function();
const limit = 3;
final Map<String, int> table = {};
String describe(Kind k) => '\$k';
Future<List<int>> load<T>() async => [];
int get total => 1;
void _private() {}
''';
      expect(declaredNames(declarations), {
        'Sealed',
        'Kind',
        'Cb',
        'limit',
        'table',
        'describe',
        'load',
        'total',
      });
    });

    test('resolution: package, relative, clamped, external, invalid', () {
      ({String target, bool clamped})? r(String from, String uri) =>
          resolveProjectUri(from: from, uri: uri, packageName: _package);
      expect(r('a/b/c.dart', 'package:rafiq_academy/x/y.dart'), (
        target: 'x/y.dart',
        clamped: false,
      ));
      expect(r('a/b/c.dart', '../d.dart'), (
        target: 'a/d.dart',
        clamped: false,
      ));
      expect(r('a/b/c.dart', './e/../f.dart'), (
        target: 'a/b/f.dart',
        clamped: false,
      ));
      expect(r('a/b/c.dart', '../../../../g.dart'), (
        target: 'g.dart',
        clamped: true,
      ));
      expect(r(r'a\b\c.dart', '../d.dart'), (
        target: 'a/d.dart',
        clamped: false,
      ));
      expect(r('a/b.dart', 'dart:io'), isNull);
      expect(r('a/b.dart', 'package:flutter/material.dart'), isNull);
      expect(() => r('a/b.dart', 'http://x/y.dart'), throwsFormatException);
      expect(normalizePath(r'C:\x\\y/./z.dart'), 'C:/x/y/z.dart');
    });

    test('in-memory graph: Windows keys, direct and transitive detection', () {
      final g = DartImportGraph.fromSources({
        r'shared\a.dart': "import 'b.dart';",
        'shared/b.dart': "import '../features/misc/c.dart';",
        r'features\misc\c.dart':
            "import 'package:rafiq_academy/features/teacher/t.dart';",
        'features/teacher/t.dart': '',
        'features/student/s.dart':
            "import '../teacher/t.dart';\nimport '../../core/di/x.dart';",
      }, packageName: _package);
      expect(g.unresolved.map((e) => e.key), [
        'features/student/s.dart -> core/di/x.dart',
      ]);
      expect(forbiddenReach(g, ['shared/a.dart'], isRoleFile), [
        'shared/a.dart -> shared/b.dart -> features/misc/c.dart -> '
            'features/teacher/t.dart',
      ]);
      expect(roleEntryEdges(g, ['shared/a.dart']).map((e) => e.key), [
        'features/misc/c.dart -> features/teacher/t.dart',
      ]);
      expect(
        exactEdgeDiff(crossRoleEdges(g), const []),
        contains('features/student/s.dart:1 -> features/teacher/t.dart'),
      );
      expect(
        exactEdgeDiff(crossRoleEdges(g), [
          'features/student/s.dart -> features/teacher/t.dart',
          'features/parent/p.dart -> features/admin/x.dart',
        ]),
        contains('no longer present'),
      );
    });

    group('injected violations on a copy of the real lib/ graph', () {
      late Map<String, String> sources;

      setUpAll(() {
        final root = normalizePath(Directory('lib').absolute.path);
        sources = {
          for (final f in Directory('lib').listSync(recursive: true))
            if (f is File && f.path.endsWith('.dart'))
              normalizePath(f.absolute.path).substring(root.length + 1): f
                  .readAsStringSync(),
        };
      });

      DartImportGraph mutated(Map<String, String> changes) =>
          DartImportGraph.fromSources({
            ...sources,
            ...changes,
          }, packageName: _package);

      test('baseline copy is clean', () {
        final g = mutated(const {});
        expect(
          exactEdgeDiff(crossRoleEdges(g), _crossRoleAllowlist.keys),
          isNull,
        );
        expect(
          exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
          isNull,
        );
      });

      test('new cross-role and A-H15 importer are rejected', () {
        final g = mutated({
          'features/parent/zz_probe.dart':
              "import '../admin/domain/admin_ops_broadcast.dart';",
        });
        expect(
          exactEdgeDiff(crossRoleEdges(g), _crossRoleAllowlist.keys),
          contains('features/parent/zz_probe.dart:1 -> $_adminOpsBroadcast'),
        );
        expect(
          g.importersOf(_adminOpsBroadcast).map((e) => e.source),
          contains('features/parent/zz_probe.dart'),
        );
      });

      test('removed approved edge is reported', () {
        final g = mutated({
          'main.dart': sources['main.dart']!.replaceFirst(
            RegExp(r"import '[^']*teacher_award_grant_scope\.dart';"),
            '',
          ),
        });
        expect(
          exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
          allOf(
            contains('no longer present'),
            contains('main.dart -> $_teacherAwardGrantScope'),
          ),
        );
      });

      test('awards_page importing TeacherBloc again is rejected', () {
        final g = mutated({
          _awardsPage:
              "import '../../../teacher/presentation/bloc/teacher_bloc.dart';\n"
              '${sources[_awardsPage]!}',
        });
        expect(
          exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
          contains('$_awardsPage:1 -> $_teacherBloc'),
        );
        final staffEntries = roleEntryEdges(
          g,
          g.files.where((f) => moduleOf(f) == 'staff'),
          stop: (f) => f == _diContainer,
        );
        expect(staffEntries.map((e) => e.key), [
          '$_awardsPage -> $_teacherBloc',
        ]);
      });

      test('student chat importing StudentBloc again is rejected', () {
        final g = mutated({
          _studentChatPage:
              "import '../../../student/presentation/bloc/student_bloc.dart';\n"
              '${sources[_studentChatPage]!}',
        });
        expect(
          exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
          contains('$_studentChatPage:1 -> $_studentBloc'),
        );
        expect(
          roleEntryEdges(
            g,
            g.files.where((f) => moduleOf(f) == 'chat'),
            stop: (f) => f == _diContainer,
          ).map((e) => e.key),
          ['$_studentChatPage -> $_studentBloc'],
        );
      });

      test(
        'chat reaching a student file through a local helper is rejected',
        () {
          final g = mutated({
            'features/chat/zz_probe.dart': "import '../zz_helper/h.dart';",
            'features/zz_helper/h.dart':
                "import 'package:rafiq_academy/$_studentChatTeacherResolver';",
          });
          expect(
            roleEntryEdges(
              g,
              g.files.where((f) => moduleOf(f) == 'chat'),
              stop: (f) => f == _diContainer,
            ).map((e) => e.key),
            ['features/zz_helper/h.dart -> $_studentChatTeacherResolver'],
          );
          expect(
            exactEdgeDiff(g.importersOf(_studentChatTeacherResolver), {
              '$_router -> $_studentChatTeacherResolver',
            }),
            contains(
              'features/zz_helper/h.dart:1 -> '
              '$_studentChatTeacherResolver',
            ),
          );
        },
      );

      test('homework or schedule importing StudentBloc again is rejected', () {
        for (final (page, module) in [
          (_studentHomeworkPage, 'homework'),
          (_studentSchedulePage, 'schedule'),
        ]) {
          final g = mutated({
            page:
                "import '../../../student/presentation/bloc/student_bloc.dart';\n"
                '${sources[page]!}',
          });
          expect(
            exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
            contains('$page:1 -> $_studentBloc'),
            reason: page,
          );
          expect(
            roleEntryEdges(
              g,
              g.files.where((f) => moduleOf(f) == module),
              stop: (f) => f == _diContainer,
            ).map((e) => e.key),
            contains('$page -> $_studentBloc'),
            reason: page,
          );
        }
      });

      test('schedule reaching the StudentBloc adapter through a local helper '
          'is rejected', () {
        final g = mutated({
          'features/schedule/zz_probe.dart': "import '../zz_helper/h.dart';",
          'features/zz_helper/h.dart':
              "import 'package:rafiq_academy/$_studentBlocCurrentProfile';",
        });
        expect(
          roleEntryEdges(
            g,
            g.files.where((f) => moduleOf(f) == 'schedule'),
            stop: (f) => f == _diContainer,
          ).map((e) => e.key),
          containsAll([
            '$_studentSchedulePage -> $_halaqaMeetingJoin',
            'features/zz_helper/h.dart -> $_studentBlocCurrentProfile',
          ]),
        );
        expect(
          exactEdgeDiff(g.importersOf(_studentBlocCurrentProfile), {
            '$_router -> $_studentBlocCurrentProfile',
          }),
          contains(
            'features/zz_helper/h.dart:1 -> $_studentBlocCurrentProfile',
          ),
        );
      });

      test('mushaf host importing the student mushaf page again is '
          'rejected', () {
        final g = mutated({
          _mushafReaderHost:
              "import '../../../student/presentation/pages/"
              "student_mushaf_page.dart';\n"
              '${sources[_mushafReaderHost]!}',
        });
        expect(
          exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
          contains('$_mushafReaderHost:1 -> $_studentMushafPage'),
        );
        expect(
          roleEntryEdges(
            g,
            g.files.where((f) => moduleOf(f) == 'mushaf'),
            stop: (f) => f == _diContainer,
          ).map((e) => e.key),
          ['$_mushafReaderHost -> $_studentMushafPage'],
        );
        expect(
          exactEdgeDiff(g.importersOf(_studentMushafPage), {
            '$_router -> $_studentMushafPage',
            '$_studentHomePage -> $_studentMushafPage',
          }),
          contains('$_mushafReaderHost:1 -> $_studentMushafPage'),
        );
      });

      test(
        'mushaf reaching a student file through a local helper is rejected',
        () {
          final g = mutated({
            'features/mushaf/zz_probe.dart': "import '../zz_helper/h.dart';",
            'features/zz_helper/h.dart':
                "import 'package:rafiq_academy/$_studentMushafPage';",
          });
          expect(
            roleEntryEdges(
              g,
              g.files.where((f) => moduleOf(f) == 'mushaf'),
              stop: (f) => f == _diContainer,
            ).map((e) => e.key),
            ['features/zz_helper/h.dart -> $_studentMushafPage'],
          );
        },
      );

      test('staff importing the teacher adapter is rejected', () {
        final g = mutated({
          _staffProfilePage:
              "import '../../../../teacher/presentation/"
              "teacher_award_grant_scope.dart';\n"
              '${sources[_staffProfilePage]!}',
        });
        expect(
          roleEntryEdges(
            g,
            g.files.where((f) => moduleOf(f) == 'staff'),
            stop: (f) => f == _diContainer,
          ).map((e) => e.key),
          ['$_staffProfilePage -> $_teacherAwardGrantScope'],
        );
        expect(
          exactEdgeDiff(g.importersOf(_teacherAwardGrantScope), {
            'main.dart -> $_teacherAwardGrantScope',
          }),
          contains('$_staffProfilePage:1 -> $_teacherAwardGrantScope'),
        );
      });

      test('staff reaching a role through a local helper is rejected', () {
        final g = mutated({
          'features/staff/zz_probe.dart': "import '../zz_helper/h.dart';",
          'features/zz_helper/h.dart':
              "import 'package:rafiq_academy/$_studentBloc';",
        });
        final entries = roleEntryEdges(
          g,
          g.files.where((f) => moduleOf(f) == 'staff'),
          stop: (f) => f == _diContainer,
        );
        expect(
          exactEdgeDiff(entries, const <String>[]),
          contains('features/zz_helper/h.dart:1 -> $_studentBloc'),
        );
      });

      test('shared reaching core/di through core is rejected', () {
        final g = mutated({
          'shared/zz_probe.dart': "import '../core/zz_probe.dart';",
          'core/zz_probe.dart': "import 'di/injection_container.dart';",
        });
        expect(
          forbiddenReach(
            g,
            g.files.where((f) => moduleOf(f) == 'shared'),
            (f) => isRoleFile(f) || _isCoreDi(f),
          ),
          ['shared/zz_probe.dart -> core/zz_probe.dart -> $_diContainer'],
        );
      });

      test('constants-only router_app importer is rejected', () {
        const probe = 'features/zz_probe/p.dart';
        final changes = {
          probe:
              "import '../../core/router/router_app.dart';\n"
              'final p = AppRoutes.login;',
        };
        final g = mutated(changes);
        expect(
          exactEdgeDiff(g.importersOf(_router), {'main.dart -> $_router'}),
          contains('$probe:1 -> $_router'),
        );
        expect(
          constantsOnlyRouterImporters(g, (f) => changes[f] ?? sources[f]!),
          [
            '$probe:1 -> $_router (import \'../../core/router/router_app.dart\')',
          ],
        );
      });

      test('router_app importer using AppRouter is accepted', () {
        const probe = 'features/zz_probe/p.dart';
        final changes = {
          probe:
              "import '../../core/router/router_app.dart';\n"
              'AppRouter? r;',
        };
        final g = mutated(changes);
        expect(
          constantsOnlyRouterImporters(g, (f) => changes[f] ?? sources[f]!),
          isEmpty,
        );
      });

      test('app_routes importing router_app is rejected', () {
        final g = mutated({
          _appRoutes: "import 'router_app.dart';\n${sources[_appRoutes]!}",
        });
        expect(
          exactEdgeDiff(g.importsOf(_appRoutes), {
            '$_appRoutes -> features/auth/presentation/bloc/auth_state.dart',
            '$_appRoutes -> core/constants/app_constants.dart',
            '$_appRoutes -> $_escalationPaths',
          }),
          contains('$_appRoutes:1 -> $_router'),
        );
        expect(forbiddenReach(g, [_appRoutes], (f) => f == _router), [
          '$_appRoutes -> $_router',
        ]);
      });

      test('shared reaching core/router is rejected', () {
        final g = mutated({
          'shared/zz_probe.dart': "import 'zz_helper.dart';",
          'shared/zz_helper.dart': "import '../core/router/app_routes.dart';",
        });
        expect(
          forbiddenReach(
            g,
            g.files.where((f) => moduleOf(f) == 'shared'),
            _isCoreRouter,
          ),
          ['shared/zz_helper.dart -> $_appRoutes'],
        );
      });

      test('feature importing a role-owned skeleton is rejected', () {
        const probe = 'features/zz_probe/p.dart';
        final g = mutated({
          probe:
              "import '../student/presentation/widgets/"
              "student_loading_skeletons.dart';",
        });
        expect(foreignRoleSkeletonImports(g).map((e) => e.key), [
          '$probe -> $_studentSkeletons',
        ]);
        expect(
          exactEdgeDiff(nonRoleToRoleEdges(g), _featureToRoleAllowlist.keys),
          contains('$probe:1 -> $_studentSkeletons'),
        );
      });

      test('neutral skeleton reaching a role is rejected', () {
        const shared = 'shared/widgets/student_page_skeletons.dart';
        final g = mutated({
          shared:
              "import '../../features/teacher/presentation/widgets/"
              "teacher_loading_skeletons.dart';\n${sources[shared]!}",
        });
        expect(forbiddenReach(g, [shared], isRoleFile), [
          '$shared -> $_teacherSkeletons',
        ]);
      });

      test('missing project-local target is reported', () {
        final g = mutated({
          'shared/zz_probe.dart': "import 'zz_missing.dart';",
        });
        expect(g.unresolved.map((e) => e.key), [
          'shared/zz_probe.dart -> shared/zz_missing.dart',
        ]);
      });
    });

    group('temp-dir fixture', () {
      late Directory temp;

      setUp(() {
        temp = Directory.systemTemp.createTempSync('rafiq_dependency_guard_');
      });

      tearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      void write(String path, String content) {
        File('${temp.path}/lib/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(content);
      }

      test('detects direct, transitive, unresolved; cycles terminate', () {
        write('shared/a.dart', "import 'b.dart';\n");
        write('shared/b.dart', "import 'a.dart';\nimport 'c.dart';\n");
        write(
          'shared/c.dart',
          "import 'package:rafiq_academy/features/staff/s.dart';\n",
        );
        write('features/staff/s.dart', "import '../admin/x.dart';\n");
        write('features/admin/x.dart', "import '../../shared/a.dart';\n");
        write('shared/direct.dart', "import '../features/parent/p.dart';\n");
        write('features/parent/p.dart', "import 'missing.dart';\n");
        write('shared/di.dart', "import '../core/di/c.dart';\n");
        write('core/di/c.dart', '');

        final g = DartImportGraph.load(
          '${temp.path}${Platform.pathSeparator}lib',
          packageName: _package,
        );
        expect(g.files, contains('features/staff/s.dart'));
        expect(g.unresolved.map((e) => e.key), [
          'features/parent/p.dart -> features/parent/missing.dart',
        ]);
        final reach = forbiddenReach(
          g,
          g.files.where((f) => moduleOf(f) == 'shared'),
          (f) => isRoleFile(f) || f.startsWith('core/di/'),
        );
        expect(reach, [
          'shared/c.dart -> features/staff/s.dart -> features/admin/x.dart',
          'shared/di.dart -> core/di/c.dart',
          'shared/direct.dart -> features/parent/p.dart',
        ]);
        final all = g.closure(g.files);
        expect(all.files, g.files);
      });
    });
  });
}

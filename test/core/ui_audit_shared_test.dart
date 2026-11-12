import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rafiq_academy/core/router/route_not_found_page.dart';

void main() {
  testWidgets('an unknown link shows a friendly page that leads home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/student/does-not-exist?token=abc',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('home')),
      ],
      errorBuilder: (_, __) => const RouteNotFoundPage(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('هذه الصفحة غير موجودة أو لم تعد متاحة.'), findsOneWidget);
    expect(find.textContaining('does-not-exist'), findsNothing);
    expect(find.textContaining('token'), findsNothing);
    expect(find.textContaining('GoException'), findsNothing);

    await tester.tap(find.text('العودة إلى الرئيسية'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  test('the app router no longer echoes the raw router error', () {
    final source = File('lib/core/router/router_app.dart').readAsStringSync();
    expect(source, contains('const RouteNotFoundPage()'));
    expect(source, isNot(contains(r'${state.error}')));
  });

  test('D15: account settings offer no language or dark-mode control', () {
    const settingsSurfaces = [
      'lib/features/student/presentation/pages/settings_page.dart',
      'lib/features/teacher/presentation/pages/teacher_profile_tab.dart',
      'lib/features/supervisor/presentation/pages/supervisor_account_tab.dart',
      'lib/features/parent/presentation/pages/parent_profile_tab.dart',
    ];
    for (final path in settingsSurfaces) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("'اللغة'")), reason: path);
      expect(source, isNot(contains('الوضع الليلي')), reason: path);
      expect(source, isNot(contains('setDarkMode')), reason: path);
    }
  });

  test('pages reading unwired progress fields gate them on the capability', () {
    // Orphan page (no route or caller) and a page that relabels the field as
    // a reviewed-record count.
    const exempt = {
      'student_mushaf_dashboard.dart',
      'parent_reports_page.dart',
    };
    final readsProgress = RegExp(r'overallProgressPercent|totalVersesMemorized');
    final offenders = <String>[];
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final normalized = f.path.replaceAll(r'\', '/');
      if (!normalized.contains('/presentation/pages/')) continue;
      if (exempt.contains(normalized.split('/').last)) continue;
      final text = f.readAsStringSync();
      if (readsProgress.hasMatch(text) &&
          !text.contains('AppCapabilities.memorizationProgressAvailable')) {
        offenders.add(f.path);
      }
      if (text.contains("'المستوى \${") &&
          !text.contains('AppCapabilities.streakAndLevelAvailable')) {
        offenders.add('${f.path} (level)');
      }
    }
    expect(offenders, isEmpty);
  });

  test('pages never fall back to showing a raw account id as a name', () {
    final rawIdFallback = RegExp(
      r'\?\?\s*(\w+\.)?(studentId|parentId|teacherId|supervisorId)\s*[,;)}]',
    );
    // Passing an id through as data (`studentId: a ?? b.studentId`) is fine.
    final idArgument = RegExp(
      r'^\s*(studentId|parentId|teacherId|supervisorId)\s*:',
    );
    final offenders = <String>[];
    for (final f in Directory('lib/features').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final normalized = f.path.replaceAll(r'\', '/');
      if (!normalized.contains('/presentation/pages/')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (rawIdFallback.hasMatch(lines[i]) && !idArgument.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no tappable control in lib/ is wired to an empty handler', () {
    final emptyHandler = RegExp(
      r'(onTap|onPressed|onLongPress):\s*\(\)\s*(\{\s*\}|=>\s*null)',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (emptyHandler.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/shared/widgets/student_header_widget.dart';
import 'package:rafiq_academy/shared/widgets/student_progress_widget.dart';
import 'package:rafiq_academy/shared/widgets/student_quick_action_widget.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('progress, streak/level and review schedules stay off until a writer '
      'exists (D11 / OA-19 / OA-75, E-12, OA-20)', () {
    expect(AppCapabilities.memorizationProgressAvailable, isFalse);
    expect(AppCapabilities.streakAndLevelAvailable, isFalse);
    expect(AppCapabilities.reviewSchedulesAvailable, isFalse);
  });

  testWidgets('unmeasured progress says so and shows no fabricated zeros', (
    tester,
  ) async {
    await _pump(
      tester,
      const StudentProgressWidget(
        progressPercent: 0,
        totalVerses: 0,
        completedSurahs: 0,
        totalStars: 7,
        progressAvailable: false,
      ),
    );

    expect(find.byKey(const Key('student-progress-unavailable')), findsOne);
    expect(find.textContaining('آية محفوظة'), findsNothing);
    expect(find.textContaining('مكتمل'), findsNothing);
    expect(find.text('سور مكتملة'), findsNothing);
    expect(find.text('دقة'), findsNothing);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('measured progress never labels memorization % as accuracy', (
    tester,
  ) async {
    await _pump(
      tester,
      const StudentProgressWidget(
        progressPercent: 40,
        totalVerses: 120,
        completedSurahs: 3,
        totalStars: 7,
      ),
    );

    expect(find.text('120 آية محفوظة'), findsOneWidget);
    expect(find.text('دقة'), findsNothing);
    expect(find.byKey(const Key('student-progress-unavailable')), findsNothing);
  });

  testWidgets('header hides the streak pill when streak is not computed', (
    tester,
  ) async {
    await _pump(
      tester,
      StudentHeaderWidget(
        name: 'أحمد',
        avatarEmoji: '🦊',
        coins: 5,
        totalStars: 2,
        streakDays: 0,
        onNotificationsTap: () {},
        onAvatarTap: () {},
        showStreak: false,
      ),
    );

    expect(find.text('يوم متواصل'), findsNothing);
    expect(find.text('نجمة'), findsOneWidget);
  });

  testWidgets('quick actions drop tiles whose feature has no data', (
    tester,
  ) async {
    await _pump(
      tester,
      StudentQuickActionsWidget(
        onMushafTap: () {},
        onReviewTap: null,
        onTeacherTap: () {},
        onMapTap: null,
      ),
    );

    expect(find.text('مصحفي'), findsOneWidget);
    expect(find.text('المعلم'), findsOneWidget);
    expect(find.text('المراجعة'), findsNothing);
    expect(find.text('خريطتي'), findsNothing);
  });

  test('no UI string labels memorization progress as «دقة الحفظ» (D11)', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains("'دقة الحفظ'")) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });
}

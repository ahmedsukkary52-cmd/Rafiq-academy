import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/student_header_widget.dart';
import 'package:rafiq_academy/shared/widgets/student_progress_widget.dart';
import 'package:rafiq_academy/shared/widgets/student_quick_action_widget.dart';

void main() {
  testWidgets('header renders Hijri date and hides streak when gated', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        theme: AppTheme.theme,
        home: Scaffold(
          body: StudentHeaderWidget(
            name: 'أحمد',
            avatarEmoji: '🦊',
            coins: 12,
            totalStars: 4,
            streakDays: 9,
            showStreak: false,
            onAvatarTap: () {},
            onStarsTap: () {},
            onSearchTap: () {},
            onNotificationsTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('student-header-hijri')), findsOneWidget);
    expect(find.textContaining('أحمد'), findsOneWidget);
    expect(find.textContaining('نجمة'), findsOneWidget);
    // Eastern digits: western "9" must stay absent when streak gated off.
    expect(find.textContaining('يوم متواصل'), findsNothing);
    expect(find.textContaining('9'), findsNothing);
  });

  testWidgets('header shows streak pill when showStreak is true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        theme: AppTheme.theme,
        home: Scaffold(
          body: StudentHeaderWidget(
            name: 'سارة',
            avatarEmoji: '🦊',
            coins: 0,
            totalStars: 1,
            streakDays: 3,
            showStreak: true,
            onAvatarTap: () {},
            onStreakTap: () {},
            onNotificationsTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('يوم متواصل'), findsOneWidget);
  });

  testWidgets('progress card shows unavailable instead of fabricated percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        theme: AppTheme.theme,
        home: Scaffold(
          body: StudentProgressWidget(
            progressPercent: 55,
            totalVerses: 10,
            completedSurahs: 2,
            totalStars: 2,
            progressAvailable: false,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('student-progress-unavailable')), findsOneWidget);
    expect(find.textContaining('55%'), findsNothing);
  });

  testWidgets('quick actions hide review/map when callbacks are null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: StudentQuickActionsWidget(
            onMushafTap: () {},
            onReviewTap: null,
            onTeacherTap: () {},
            onMapTap: null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
  });

  testWidgets('quick actions show review/map when callbacks provided', (
    tester,
  ) async {
    var mapTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(
          body: StudentQuickActionsWidget(
            onMushafTap: () {},
            onReviewTap: () {},
            onTeacherTap: () {},
            onMapTap: () => mapTaps++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.map_outlined));
    expect(mapTaps, 1);
  });
  testWidgets('header survives narrow width and large text without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          locale: AppLocaleConfig.locale,
          theme: AppTheme.theme,
          home: Scaffold(
            body: StudentHeaderWidget(
              name: 'محمد عبدالله الطويل للاختبار',
              avatarEmoji: '🦊',
              coins: 120,
              totalStars: 8,
              streakDays: 2,
              showStreak: true,
              onAvatarTap: () {},
              onNotificationsTap: () {},
              onSearchTap: () {},
              onStreakTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('student-header-hijri')), findsOneWidget);
    expect(find.textContaining('يوم متواصل'), findsOneWidget);
  });

}
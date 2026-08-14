import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/teacher_home_figma_cards.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

void main() {
  group('resolveTeacherHomeAnalyticsHalaqaId', () {
    test('prefers featured session halaqa', () {
      expect(
        resolveTeacherHomeAnalyticsHalaqaId(
          featuredSessionHalaqaId: 'feat',
          teacherHalaqaIds: const ['a', 'b'],
        ),
        'feat',
      );
    });

    test('falls back to first teacher halaqa', () {
      expect(
        resolveTeacherHomeAnalyticsHalaqaId(
          featuredSessionHalaqaId: null,
          teacherHalaqaIds: const ['a', 'b'],
        ),
        'a',
      );
      expect(
        resolveTeacherHomeAnalyticsHalaqaId(
          featuredSessionHalaqaId: '  ',
          teacherHalaqaIds: const ['', 'b'],
        ),
        'b',
      );
    });

    test('returns null when nothing available', () {
      expect(
        resolveTeacherHomeAnalyticsHalaqaId(
          featuredSessionHalaqaId: null,
          teacherHalaqaIds: const [],
        ),
        isNull,
      );
    });
  });

  group('TeacherHomeAnalyticsSummaryCard', () {
    testWidgets('shows skeleton while loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: const Scaffold(
            body: TeacherHomeAnalyticsSummaryCard(loading: true),
          ),
        ),
      );
      expect(find.text('التحليلات'), findsNothing);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('shows real metrics when loaded', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: TeacherHomeAnalyticsSummaryCard(
              attendancePercent: 91,
              performancePercent: 87,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('التحليلات'), findsOneWidget);
      expect(find.text('نسبة الحضور'), findsOneWidget);
      expect(find.text('متوسط الأداء'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('shows honest error with retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.theme,
          home: Scaffold(
            body: TeacherHomeAnalyticsSummaryCard(
              errorMessage: 'تعذر التحميل',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );
      expect(find.text('تعذر التحميل'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, isTrue);
    });
  });
}

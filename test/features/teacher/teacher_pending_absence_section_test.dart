import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/teacher_loading_skeletons.dart';
import 'package:rafiq_academy/features/teacher/presentation/widgets/teacher_pending_absence_section.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'loading skeleton is shrink-wrapped and does not demand unbounded height',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleConfig.locale,
          supportedLocales: AppLocaleConfig.supportedLocales,
          localizationsDelegates: AppLocaleConfig.localizationsDelegates,
          theme: AppTheme.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherPendingAbsenceSection(
                status: SectionStatus.loading,
                requests: const [],
                error: null,
                canReview: true,
                reviewing: false,
                studentName: (_) => 'طالب',
                onRetry: () {},
                onReview: (_, __) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(TeacherRosterRowsSkeleton), findsOneWidget);
      expect(find.text('طلبات الاستئذان'), findsOneWidget);
    },
  );

  testWidgets('empty loaded state explains no requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        supportedLocales: AppLocaleConfig.supportedLocales,
        localizationsDelegates: AppLocaleConfig.localizationsDelegates,
        theme: AppTheme.theme,
        home: Scaffold(
          body: TeacherPendingAbsenceSection(
            status: SectionStatus.loaded,
            requests: const [],
            error: null,
            canReview: true,
            reviewing: false,
            studentName: (_) => 'طالب',
            onRetry: () {},
            onReview: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('لا توجد طلبات استئذان'), findsOneWidget);
  });
}

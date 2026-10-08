import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/app_back_button.dart';
import 'package:rafiq_academy/shared/widgets/app_empty_state.dart';
import 'package:rafiq_academy/shared/widgets/app_quick_action_grid.dart';
import 'package:rafiq_academy/shared/widgets/app_search_field.dart';
import 'package:rafiq_academy/shared/widgets/app_skeleton.dart';
import 'package:rafiq_academy/shared/widgets/app_stat_tile.dart';
import 'package:rafiq_academy/shared/widgets/app_status_chip.dart';
import 'package:rafiq_academy/shared/widgets/app_subpage_scaffold.dart';
import 'package:rafiq_academy/shared/widgets/shared_widgets.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('UI-2 AppStatTile', () {
    testWidgets('renders value, label, icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppStatTile(
            value: '١٢',
            label: 'طلاب',
            icon: Icons.person_outline,
          ),
        ),
      );

      expect(find.text('١٢'), findsOneWidget);
      expect(find.text('طلاب'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppStatTile(
            value: '1',
            label: 'حصص',
            icon: Icons.calendar_today_outlined,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(AppStatTile));
      await tester.pump();
      expect(tapped, isTrue);
    });
    testWidgets('renders compact and onPrimary variants', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              Expanded(
                child: AppStatTile(
                  value: '٩٠٪',
                  label: 'حضور',
                  variant: AppStatTileVariant.compact,
                ),
              ),
              Expanded(
                child: AppStatTile(
                  value: '١٤',
                  label: 'طالب',
                  variant: AppStatTileVariant.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('٩٠٪'), findsOneWidget);
      expect(find.text('حضور'), findsOneWidget);
      expect(find.text('١٤'), findsOneWidget);
      expect(find.text('طالب'), findsOneWidget);
    });
  });

  group('UI-2 AppStatsGrid', () {
    testWidgets('renders tiles without overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 360,
            child: AppStatsGrid(
              children: [
                AppStatTile(value: '1', label: 'أ', icon: Icons.star),
                AppStatTile(value: '2', label: 'ب', icon: Icons.star),
                AppStatTile(value: '3', label: 'ج', icon: Icons.star),
                AppStatTile(value: '4', label: 'د', icon: Icons.star),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('UI-2 AppQuickActionGrid', () {
    testWidgets('renders actions and fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppQuickActionGrid(
            items: [
              AppQuickActionItem(
                icon: Icons.assessment_outlined,
                label: 'التقارير',
                color: AppColors.success,
                onTap: () => tapped = true,
              ),
              const AppQuickActionItem(
                icon: Icons.calendar_month_outlined,
                label: 'الجدول',
                color: AppColors.info,
              ),
            ],
          ),
        ),
      );

      expect(find.text('التقارير'), findsOneWidget);
      expect(find.text('الجدول'), findsOneWidget);
      await tester.tap(find.text('التقارير'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('row layout renders and fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppQuickActionGrid(
            layout: AppQuickActionLayout.row,
            items: [
              AppQuickActionItem(
                icon: Icons.videocam_outlined,
                label: 'حصصي',
                color: AppColors.primaryLight,
                iconColor: AppColors.primary,
                onTap: () => tapped = true,
              ),
              const AppQuickActionItem(
                icon: Icons.assignment_outlined,
                label: 'واجباتي',
                color: Color(0xFFFFF3E0),
              ),
            ],
          ),
        ),
      );

      expect(find.text('حصصي'), findsOneWidget);
      await tester.tap(find.text('حصصي'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('UI-2 AppEmptyState', () {
    testWidgets('title subtitle and CTA', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _wrap(
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'لا بيانات',
            message: 'جرّب لاحقاً',
            actionLabel: 'إعادة',
            onAction: () => pressed = true,
          ),
        ),
      );

      expect(find.text('لا بيانات'), findsOneWidget);
      expect(find.text('جرّب لاحقاً'), findsOneWidget);
      await tester.tap(find.text('إعادة'));
      await tester.pump();
      expect(pressed, isTrue);
    });
  });

  group('UI-2 AppStatusChip', () {
    testWidgets('renders label for each tone', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Wrap(
            children: [
              AppStatusChip(label: 'نجاح', tone: AppStatusTone.success),
              AppStatusChip(label: 'تحذير', tone: AppStatusTone.warning),
              AppStatusChip(label: 'خطأ', tone: AppStatusTone.error),
              AppStatusChip(label: 'معلومة', tone: AppStatusTone.info),
              AppStatusChip(label: 'محايد', tone: AppStatusTone.neutral),
            ],
          ),
        ),
      );

      expect(find.text('نجاح'), findsOneWidget);
      expect(find.text('تحذير'), findsOneWidget);
      expect(find.text('خطأ'), findsOneWidget);
      expect(find.text('معلومة'), findsOneWidget);
      expect(find.text('محايد'), findsOneWidget);
    });
  });

  group('UI-2 AppSkeleton', () {
    testWidgets('pulse and bones render', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppSkeletonPulse(
            builder: (context, bone) {
              return Column(
                children: [
                  AppSkeletonBox(bone: bone, height: 20, width: 80),
                  AppSkeletonLine(bone: bone, width: 60),
                  AppSkeletonCircle(bone: bone, size: 32),
                ],
              );
            },
          ),
        ),
      );

      expect(find.byType(AppSkeletonBox), findsWidgets);
      expect(find.byType(AppSkeletonLine), findsOneWidget);
      expect(find.byType(AppSkeletonCircle), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });

  group('UI-2 AppSubpageScaffold', () {
    testWidgets('title back and content', (tester) async {
      var back = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleConfig.locale,
          supportedLocales: AppLocaleConfig.supportedLocales,
          localizationsDelegates: AppLocaleConfig.localizationsDelegates,
          theme: AppTheme.theme,
          home: AppSubpageScaffold(
            title: 'صفحة فرعية',
            onBack: () => back = true,
            body: const Center(child: Text('المحتوى')),
          ),
        ),
      );

      expect(find.text('صفحة فرعية'), findsOneWidget);
      expect(find.text('المحتوى'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pump();
      expect(back, isTrue);
    });
  });

  group('UI-2 AppSearchField', () {
    testWidgets('input and clear', (tester) async {
      final controller = TextEditingController();
      var last = '';
      await tester.pumpWidget(
        _wrap(
          AppSearchField(
            controller: controller,
            hint: 'بحث...',
            onChanged: (v) => last = v,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'أحمد');
      await tester.pump();
      expect(last, 'أحمد');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(last, isEmpty);
    });
  });

  group('UI-2 SectionHeader reused', () {
    testWidgets('existing SectionHeader still works', (tester) async {
      var action = false;
      await tester.pumpWidget(
        _wrap(
          SectionHeader(
            title: 'القسم',
            actionLabel: 'الكل',
            onAction: () => action = true,
          ),
        ),
      );

      expect(find.text('القسم'), findsOneWidget);
      await tester.tap(find.text('الكل'));
      await tester.pump();
      expect(action, isTrue);
    });
  });
}

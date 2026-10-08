import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/app_empty_state.dart';
import 'package:rafiq_academy/shared/widgets/app_search_field.dart';
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
  group('UI-5 shared empty/search polish', () {
    testWidgets('AppEmptyState renders Arabic title and message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppEmptyState(
            icon: Icons.groups_rounded,
            title: 'لا توجد حلقات مسندة إليك',
            message: 'عند إسناد حلقات لحسابك من قِبل الأكاديمية ستظهر هنا.',
          ),
        ),
      );

      expect(find.text('لا توجد حلقات مسندة إليك'), findsOneWidget);
      expect(find.textContaining('إسناد حلقات'), findsOneWidget);
      expect(find.text('Coming Soon'), findsNothing);
    });

    testWidgets('AppSearchField is RTL and accepts input', (tester) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      var changed = '';

      await tester.pumpWidget(
        _wrap(
          AppSearchField(
            controller: ctrl,
            hint: 'بحث في الحلقات...',
            onChanged: (v) => changed = v,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'فجر');
      await tester.pump();

      expect(changed, 'فجر');
      expect(ctrl.text, 'فجر');
      expect(find.text('بحث في الحلقات...'), findsOneWidget);
    });

    testWidgets('NotificationBadge uses directional end placement', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const NotificationBadge(
            count: 3,
            child: Icon(Icons.notifications_outlined),
          ),
        ),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.byType(PositionedDirectional), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/app_floating_bottom_nav.dart';

Widget _wrap(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          extendBody: true,
          body: const SizedBox.expand(),
          bottomNavigationBar: child,
        ),
      ),
    ),
  );
}

List<AppNavDestination> _destinations() => const [
      AppNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'الرئيسية',
      ),
      AppNavDestination(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        label: 'الحلقات',
      ),
      AppNavDestination(
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: 'المحادثات',
      ),
      AppNavDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'حسابي',
      ),
    ];

void main() {
  group('D4 AppFloatingBottomNav', () {
    testWidgets('wraps glass bar in RepaintBoundary (BASMA-106)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppFloatingBottomNav(
            selected: 0,
            onChanged: (_) {},
            destinations: _destinations(),
          ),
        ),
      );

      final nav = find.byType(AppFloatingBottomNav);
      expect(nav, findsOneWidget);
      expect(
        find.descendant(of: nav, matching: find.byType(RepaintBoundary)),
        findsWidgets,
      );
      expect(
        find.descendant(of: nav, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
    });

    testWidgets('narrow 320 + textScale 1.3 does not overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppFloatingBottomNav(
            selected: 1,
            onChanged: (_) {},
            destinations: _destinations(),
          ),
          size: const Size(320, 640),
        ),
      );
      await tester.pump();

      // Apply large text via MediaQuery on the pumped tree.
      final mq = tester.widget<MediaQuery>(find.byType(MediaQuery).first);
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleConfig.locale,
          supportedLocales: AppLocaleConfig.supportedLocales,
          localizationsDelegates: AppLocaleConfig.localizationsDelegates,
          theme: AppTheme.theme,
          home: MediaQuery(
            data: mq.data.copyWith(
              size: const Size(320, 640),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                extendBody: true,
                body: const SizedBox.expand(),
                bottomNavigationBar: AppFloatingBottomNav(
                  selected: 1,
                  onChanged: (_) {},
                  destinations: _destinations(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('الحلقات'), findsOneWidget);
    });
  });
}

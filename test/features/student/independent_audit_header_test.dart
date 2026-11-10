// Independent audit (2026-11-06) header layout regression. Test fixtures only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/student_header_widget.dart';

Widget _host({double scale = 1.0}) => MaterialApp(
  locale: AppLocaleConfig.locale,
  supportedLocales: AppLocaleConfig.supportedLocales,
  localizationsDelegates: AppLocaleConfig.localizationsDelegates,
  theme: AppTheme.theme,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: StudentHeaderWidget(
          name: '\u0623\u062d\u0645\u062f',
          avatarEmoji: 'A',
          coins: 1,
          totalStars: 2,
          streakDays: 0,
          showStreak: false,
          onAvatarTap: () {},
          onNotificationsTap: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('AUDIT-4: avatar group stays pinned to the header edge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    await tester.pumpWidget(_host());
    final c = tester.getCenter(find.text('A'));
    final edge = c.dx < 400 ? c.dx : 800 - c.dx;
    expect(edge, lessThan(70), reason: 'avatar drifted to ${c.dx}');
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('AUDIT-4b: narrow 320 + text scale 2 has no overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    await tester.pumpWidget(_host(scale: 2.0));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
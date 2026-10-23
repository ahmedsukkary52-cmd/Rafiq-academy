import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/teacher/presentation/tasks/create_halaqa_activity_sheet.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

Widget _wrap() {
  return MaterialApp(
    locale: AppLocaleConfig.locale,
    supportedLocales: AppLocaleConfig.supportedLocales,
    localizationsDelegates: AppLocaleConfig.localizationsDelegates,
    theme: AppTheme.theme,
    home: const Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: CreateHalaqaActivitySheet(halaqaId: 'h1')),
    ),
  );
}

void main() {
  testWidgets('sheet offers no audio response type while uploads are off', (
    tester,
  ) async {
    expect(AppCapabilities.audioUploadsEnabled, isFalse);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    final labels = chips.map((c) => (c.label as Text).data).toList();
    expect(labels, unorderedEquals(['نص', 'صورة']));
    expect(find.widgetWithText(FilterChip, 'صوت'), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });
}

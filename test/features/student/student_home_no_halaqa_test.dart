import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/presentation/widgets/student_no_halaqa_card.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

void main() {
  testWidgets('no-halaqa card is honest and has no schedule CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocaleConfig.locale,
        supportedLocales: AppLocaleConfig.supportedLocales,
        localizationsDelegates: AppLocaleConfig.localizationsDelegates,
        theme: AppTheme.theme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: StudentNoHalaqaCard()),
        ),
      ),
    );

    expect(find.byKey(const Key('student-home-no-halaqa')), findsOneWidget);
    expect(find.text('لم تُسند إليك حلقة بعد'), findsOneWidget);
    expect(find.textContaining('تربطك الإدارة بحلقة'), findsOneWidget);
    expect(find.text('اضغط لعرض جدول الحصص'), findsNothing);
  });
}

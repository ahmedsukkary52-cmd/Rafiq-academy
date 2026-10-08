import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/academy_branding.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/shared/theme/app_locale_config.dart';
import 'package:rafiq_academy/shared/widgets/app_back_button.dart';

void main() {
  group('UI-1 AcademyBranding', () {
    test('central strings are non-empty and consistent', () {
      expect(AcademyBranding.displayName, isNotEmpty);
      expect(AcademyBranding.shortName, isNotEmpty);
      expect(AcademyBranding.tagline, isNotEmpty);
      expect(AcademyBranding.fullTitle, contains(AcademyBranding.shortName));
      expect(AppConstants.appName, AcademyBranding.fullTitle);
      expect(
        AcademyBranding.versionFooter('1.0.0'),
        contains(AcademyBranding.displayName),
      );
      expect(AcademyBranding.versionFooter('1.0.0'), contains('1.0.0'));
    });
  });

  group('UI-1 AppLocaleConfig', () {
    test('Arabic + RTL only', () {
      expect(AppLocaleConfig.locale, const Locale('ar'));
      expect(AppLocaleConfig.supportedLocales, [const Locale('ar')]);
      expect(AppLocaleConfig.textDirection, TextDirection.rtl);
      expect(AppLocaleConfig.localizationsDelegates, isNotEmpty);
    });
  });

  group('UI-1 AppBackButton', () {
    test('iconFor maps RTL/LTR correctly', () {
      expect(
        AppBackButton.iconFor(TextDirection.rtl),
        Icons.chevron_right_rounded,
      );
      expect(
        AppBackButton.iconFor(TextDirection.ltr),
        Icons.chevron_left_rounded,
      );
    });

    testWidgets('pops navigator on tap under RTL', (tester) async {
      var popped = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: AppLocaleConfig.locale,
          supportedLocales: AppLocaleConfig.supportedLocales,
          localizationsDelegates: AppLocaleConfig.localizationsDelegates,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  appBar: AppBar(
                    leading: AppBackButton(onPressed: () => popped = true),
                  ),
                  body: const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pump();
      expect(popped, isTrue);
    });
  });
}

// Cairo is bundled, never downloaded: the theme uses the local family and the
// remaining GoogleFonts.cairo call sites resolve to the same bundled files.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

/// Bundled file per weight, with the byte length google_fonts 6.3.3 records
/// for the same Cairo variant (identical glyphs to the old runtime download).
const _cairoFiles = <int, (String, int)>{
  400: ('assets/fonts/Cairo-Regular.ttf', 91476),
  500: ('assets/fonts/Cairo-Medium.ttf', 91652),
  600: ('assets/fonts/Cairo-SemiBold.ttf', 91700),
  700: ('assets/fonts/Cairo-Bold.ttf', 91640),
  800: ('assets/fonts/Cairo-ExtraBold.ttf', 91724),
  900: ('assets/fonts/Cairo-Black.ttf', 91720),
};

Iterable<TextStyle?> _styles(TextTheme t) => [
  t.displayLarge,
  t.displayMedium,
  t.displaySmall,
  t.headlineLarge,
  t.headlineMedium,
  t.headlineSmall,
  t.titleLarge,
  t.titleMedium,
  t.titleSmall,
  t.bodyLarge,
  t.bodyMedium,
  t.bodySmall,
  t.labelLarge,
  t.labelMedium,
  t.labelSmall,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app_theme never goes through google_fonts', () {
    final src = File('lib/shared/theme/app_theme.dart').readAsStringSync();
    expect(src, isNot(contains('google_fonts')));
    expect(src, isNot(contains('GoogleFonts')));
    expect(AppTextStyles.fontFamily, 'Cairo');
  });

  test('every theme and helper text style uses the bundled Cairo family', () {
    for (final theme in [AppTheme.theme, AppTheme.darkTheme]) {
      for (final style in [
        ..._styles(theme.textTheme),
        ..._styles(theme.primaryTextTheme),
      ]) {
        expect(style?.fontFamily, 'Cairo');
      }
    }
    for (final style in [
      AppTextStyles.displayLarge,
      AppTextStyles.displayMedium,
      AppTextStyles.headlineLarge,
      AppTextStyles.headlineMedium,
      AppTextStyles.titleLarge,
      AppTextStyles.titleMedium,
      AppTextStyles.bodyLarge,
      AppTextStyles.bodyMedium,
      AppTextStyles.labelLarge,
      AppTextStyles.labelMedium,
      AppTextStyles.labelSmall,
    ]) {
      expect(style.fontFamily, 'Cairo');
    }
  });

  test('pubspec bundles one Cairo file per weight 400-900', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- family: Cairo'));
    for (final MapEntry(key: weight, value: (path, length))
        in _cairoFiles.entries) {
      expect(
        RegExp(
          '- asset: ${RegExp.escape(path)}\\s+weight: $weight\\b',
        ).hasMatch(pubspec),
        isTrue,
        reason: path,
      );
      expect(File(path).lengthSync(), length, reason: path);
    }
    expect(File('assets/fonts/Cairo-OFL.txt').existsSync(), isTrue);
  });

  test('no weight used in lib/ falls outside the bundled Cairo weights', () {
    final used = <int>{};
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final m in RegExp(
        r'FontWeight\.w(\d)00',
      ).allMatches(file.readAsStringSync())) {
        used.add(int.parse(m.group(1)!) * 100);
      }
    }
    expect(_cairoFiles.keys.toSet().containsAll(used), isTrue, reason: '$used');
  });

  test(
    'GoogleFonts.cairo resolves every weight from the bundle, offline',
    () async {
      GoogleFonts.config.allowRuntimeFetching = false;
      addTearDown(() => GoogleFonts.config.allowRuntimeFetching = true);
      for (final weight in _cairoFiles.keys) {
        GoogleFonts.cairo(fontWeight: FontWeight.values[weight ~/ 100 - 1]);
      }
      await expectLater(GoogleFonts.pendingFonts(), completes);
    },
  );
}

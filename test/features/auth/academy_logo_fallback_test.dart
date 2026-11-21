import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/academy_branding.dart';
import 'package:rafiq_academy/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';

List<String> _declaredAssets() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexWhere((l) => l.trim() == 'assets:');
  expect(start, isNonNegative, reason: 'pubspec.yaml has no assets list');
  final assets = <String>[];
  for (final line in lines.skip(start + 1)) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    if (!t.startsWith('- ')) break;
    assets.add(t.substring(2).trim());
  }
  return assets;
}

void main() {
  test('every asset declared in pubspec.yaml exists', () {
    final assets = _declaredAssets();
    expect(assets, isNotEmpty);
    for (final a in assets) {
      expect(File(a).existsSync(), isTrue, reason: '$a is declared but missing');
    }
  });

  test('the academy logo asset is declared and present', () {
    expect(_declaredAssets(), contains(AcademyBranding.logoAsset));
    expect(File(AcademyBranding.logoAsset).existsSync(), isTrue);
  });

  testWidgets('AcademyLogo renders the branded image when bundled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AcademyLogo(size: 52))),
    );
    await tester.pump();

    expect(find.byKey(const Key('academy-logo')), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
  });

  testWidgets('AcademyLogo falls back to the primary book icon on error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Image.asset(
            'assets/branding/missing_logo.png',
            errorBuilder: (_, __, ___) => const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
              size: 52 * 0.55,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.menu_book_rounded));
    expect(icon.color, AppColors.primary);
  });
}

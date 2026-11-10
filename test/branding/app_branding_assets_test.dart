import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/academy_branding.dart';
import 'package:rafiq_academy/features/auth/presentation/widgets/auth_widgets.dart';

/// PNG IHDR: width, height and colour type (2 = RGB, 6 = RGBA).
({int width, int height, int colorType}) _png(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: path);
  final view = ByteData.sublistView(bytes);
  return (
    width: view.getUint32(16),
    height: view.getUint32(20),
    colorType: bytes[25],
  );
}

const _res = 'android/app/src/main/res';
const _densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4};

void main() {
  test('Android launcher, adaptive foreground and splash icon per density', () {
    _densities.forEach((d, s) {
      final legacy = _png('$_res/mipmap-$d/ic_launcher.png');
      expect((legacy.width, legacy.height), ((48 * s).round(), (48 * s).round()), reason: d);
      expect(legacy.colorType, 6, reason: 'legacy icon keeps transparent corners ($d)');

      final fg = _png('$_res/mipmap-$d/ic_launcher_foreground.png');
      expect((fg.width, fg.height), ((108 * s).round(), (108 * s).round()), reason: d);

      final splash = _png('$_res/drawable-$d/splash_icon.png');
      expect((splash.width, splash.height), ((288 * s).round(), (288 * s).round()), reason: d);
      expect(splash.colorType, 6, reason: d);
    });
    final adaptive = File('$_res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(adaptive, contains('@mipmap/ic_launcher_foreground'));
    expect(adaptive, contains('@color/ic_launcher_background'));
    expect(
      File('$_res/values/colors.xml').readAsStringSync(),
      contains('name="ic_launcher_background"'),
    );
  });

  test('every launch path shows the logo on the brand colour (no white flash)', () {
    for (final f in ['drawable', 'drawable-v21']) {
      final xml = File('$_res/$f/launch_background.xml').readAsStringSync();
      expect(xml, contains('@color/rafiq_launch_background'), reason: f);
      expect(xml, contains('@drawable/splash_icon'), reason: f);
    }
    for (final f in ['values-v31', 'values-night-v31']) {
      final xml = File('$_res/$f/styles.xml').readAsStringSync();
      expect(xml, contains('windowSplashScreenBackground">@color/rafiq_launch_background'), reason: f);
      expect(xml, contains('windowSplashScreenAnimatedIcon">@drawable/splash_icon'), reason: f);
    }
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
    expect(storyboard, isNot(contains('red="1" green="1" blue="1"')));
    expect(storyboard, contains('<image name="LaunchImage" width="160" height="160"/>'));
    for (final (f, px) in [('LaunchImage.png', 160), ('LaunchImage@2x.png', 320), ('LaunchImage@3x.png', 480)]) {
      final p = _png('ios/Runner/Assets.xcassets/LaunchImage.imageset/$f');
      expect((p.width, p.height), (px, px), reason: f);
    }
  });

  test('iOS app icons match Contents.json sizes and carry no alpha', () {
    const dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final contents = File('$dir/Contents.json').readAsStringSync();
    final entries = RegExp(r'"size"\s*:\s*"([\d.]+)x[\d.]+"[^}]*?"filename"\s*:\s*"([^"]+)"[^}]*?"scale"\s*:\s*"(\d)x"|"size"\s*:\s*"([\d.]+)x[\d.]+"[^}]*?"scale"\s*:\s*"(\d)x"[^}]*?"filename"\s*:\s*"([^"]+)"')
        .allMatches(contents);
    final files = <String, int>{};
    for (final m in entries) {
      final size = double.parse(m.group(1) ?? m.group(4)!);
      final scale = int.parse(m.group(3) ?? m.group(5)!);
      files[m.group(2) ?? m.group(6)!] = (size * scale).round();
    }
    expect(files, isNotEmpty);
    files.forEach((file, px) {
      final p = _png('$dir/$file');
      expect((p.width, p.height), (px, px), reason: file);
      expect(p.colorType, 2, reason: '$file must be opaque for the App Store');
    });
  });

  test('in-app logo asset is bundled', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- ${AcademyBranding.logoAsset}'));
    final p = _png(AcademyBranding.logoAsset);
    expect((p.width, p.height, p.colorType), (512, 512, 6));
  });

  testWidgets('login header shows the logo; task pages keep their icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AuthBrandHeader(title: 'دخول'),
              AuthBrandHeader(title: 'استعادة', icon: Icons.lock_reset_rounded),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('academy-logo')), findsOneWidget);
    expect(find.byIcon(Icons.lock_reset_rounded), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Image && w.semanticLabel == AcademyBranding.displayName,
      ),
      findsOneWidget,
    );
  });
}

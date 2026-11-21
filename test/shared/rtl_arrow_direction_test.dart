import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/supervisor/presentation/widgets/supervisor_subpage_scaffold.dart';
import 'package:rafiq_academy/shared/widgets/admin_subpage_scaffold.dart';
import 'package:rafiq_academy/shared/widgets/app_back_button.dart';

/// Material arrow icons have `matchTextDirection: true`, so [Icon] mirrors
/// them under RTL. These tests check the direction the arrow is actually
/// DRAWN in, not just which constant was picked.
final _leftGlyphs = <IconData>{
  Icons.chevron_left,
  Icons.chevron_left_rounded,
  Icons.arrow_back_rounded,
  Icons.arrow_back_ios_new_rounded,
};
final _rightGlyphs = <IconData>{
  Icons.chevron_right,
  Icons.chevron_right_rounded,
  Icons.arrow_forward_rounded,
  Icons.arrow_forward_ios_rounded,
};

bool _isMirrored(WidgetTester tester, Finder icon) {
  final transforms = find.descendant(of: icon, matching: find.byType(Transform));
  if (transforms.evaluate().isEmpty) return false;
  return tester.widget<Transform>(transforms.first).transform.storage[0] < 0;
}

/// True when the rendered arrow points to the right of the screen.
bool _drawnPointingRight(WidgetTester tester, IconData data) {
  final icon = find.byIcon(data);
  expect(icon, findsOneWidget);
  final mirrored = _isMirrored(tester, icon);
  if (_leftGlyphs.contains(data)) return mirrored;
  if (_rightGlyphs.contains(data)) return !mirrored;
  throw ArgumentError('unclassified arrow icon $data');
}

Future<void> _pumpDirected(
  WidgetTester tester,
  TextDirection direction,
  Widget child,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Directionality(textDirection: direction, child: child),
    ),
  );
}

void main() {
  group('RTL arrow direction (rendered)', () {
    testWidgets('AppBackButton points right in RTL and left in LTR', (
      tester,
    ) async {
      await _pumpDirected(
        tester,
        TextDirection.rtl,
        Scaffold(body: AppBackButton(onPressed: () {})),
      );
      expect(
        _drawnPointingRight(tester, AppBackButton.iconFor(TextDirection.rtl)),
        isTrue,
      );

      await _pumpDirected(
        tester,
        TextDirection.ltr,
        Scaffold(body: AppBackButton(onPressed: () {})),
      );
      expect(
        _drawnPointingRight(tester, AppBackButton.iconFor(TextDirection.ltr)),
        isFalse,
      );
    });

    testWidgets('AdminSubpageScaffold back sits on the right and points right', (
      tester,
    ) async {
      await _pumpDirected(
        tester,
        TextDirection.rtl,
        const AdminSubpageScaffold(title: 'عنوان', body: SizedBox.shrink()),
      );
      const back = Icons.arrow_back_ios_new_rounded;
      expect(_drawnPointingRight(tester, back), isTrue);
      final screenWidth = tester.view.physicalSize.width /
          tester.view.devicePixelRatio;
      expect(tester.getCenter(find.byIcon(back)).dx, greaterThan(screenWidth / 2));
    });

    testWidgets(
      'SupervisorSubpageScaffold back sits on the right and points right',
      (tester) async {
        await _pumpDirected(
          tester,
          TextDirection.rtl,
          const SupervisorSubpageScaffold(
            title: 'عنوان',
            body: SizedBox.shrink(),
          ),
        );
        const back = Icons.chevron_left_rounded;
        expect(_drawnPointingRight(tester, back), isTrue);
        final screenWidth = tester.view.physicalSize.width /
            tester.view.devicePixelRatio;
        expect(
          tester.getCenter(find.byIcon(back)).dx,
          greaterThan(screenWidth / 2),
        );
      },
    );

    // Convention used by every fixed call site: Back = left glyph (drawn
    // pointing right in RTL); "open" / forward = right glyph (drawn pointing
    // left in RTL).
    for (final data in _leftGlyphs) {
      testWidgets('back glyph ${data.codePoint} is drawn pointing right in RTL', (
        tester,
      ) async {
        await _pumpDirected(tester, TextDirection.rtl, Icon(data));
        expect(_drawnPointingRight(tester, data), isTrue);
      });
    }
    for (final data in _rightGlyphs) {
      testWidgets('forward glyph ${data.codePoint} is drawn pointing left in RTL', (
        tester,
      ) async {
        await _pumpDirected(tester, TextDirection.rtl, Icon(data));
        expect(_drawnPointingRight(tester, data), isFalse);
      });
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural guard: D4 hot list pages must use builder/sliver builders,
/// not eager `...map` / `for (... in items)` into ListView children.
void main() {
  group('D4 lazy list structure', () {
    test('admin directory uses SliverChildBuilderDelegate for rows', () {
      final src = File(
        'lib/features/directory/presentation/admin_directory_page.dart',
      ).readAsStringSync();
      expect(src, contains('SliverChildBuilderDelegate'));
      expect(src, contains('CustomScrollView'));
      expect(
        src.contains('for (final p in _items)'),
        isFalse,
        reason: 'person rows must not be eagerly expanded',
      );
      expect(
        src.contains('for (final h in _items)'),
        isFalse,
        reason: 'halaqa rows must not be eagerly expanded',
      );
    });

    test('supervisor payments uses SliverChildBuilderDelegate', () {
      final src = File(
        'lib/features/supervisor/presentation/pages/supervisor_payments_page.dart',
      ).readAsStringSync();
      expect(src, contains('SliverChildBuilderDelegate'));
      expect(src, contains('CustomScrollView'));
      expect(
        src.contains('...visible.map'),
        isFalse,
        reason: 'payment rows must not be eagerly spread',
      );
    });

    test('admin registration requests uses SliverChildBuilderDelegate', () {
      final src = File(
        'lib/features/admin/presentation/pages/admin_registration_requests_page.dart',
      ).readAsStringSync();
      expect(src, contains('SliverChildBuilderDelegate'));
      expect(src, contains('CustomScrollView'));
      expect(
        src.contains('...pending.map'),
        isFalse,
        reason: 'registration rows must not be eagerly spread',
      );
    });

    test('floating nav isolates blur with RepaintBoundary', () {
      final src = File(
        'lib/shared/widgets/app_floating_bottom_nav.dart',
      ).readAsStringSync();
      expect(src, contains('RepaintBoundary'));
      expect(src, contains('BackdropFilter'));
    });
  });
}

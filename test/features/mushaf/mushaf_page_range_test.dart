import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/mushaf/domain/mushaf_page_range.dart';

void main() {
  group('MushafPageRange', () {
    test('accepts page 1', () {
      expect(MushafPageRange.isValidPage(1), isTrue);
    });

    test('accepts page 604', () {
      expect(MushafPageRange.isValidPage(604), isTrue);
    });

    test('rejects page 0', () {
      expect(MushafPageRange.isValidPage(0), isFalse);
    });

    test('rejects page >604', () {
      expect(MushafPageRange.isValidPage(605), isFalse);
      expect(MushafPageRange.isValidPage(1000), isFalse);
    });

    test('clampPage maps out-of-range safely', () {
      expect(MushafPageRange.clampPage(0), 1);
      expect(MushafPageRange.clampPage(700), 604);
      expect(MushafPageRange.clampPage(42), 42);
    });
  });
}

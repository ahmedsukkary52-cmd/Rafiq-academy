import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/halaqa_name_key.dart';

/// The Dart pre-check must agree with the server key
/// (`functions/src/halaqa/halaqaNameKey.ts`), read from its vector table.
void main() {
  final source = File('functions/src/halaqa/halaqaNameKey.ts').readAsStringSync();
  final vectors = RegExp(r'\{ input: "([^"]*)", expected: "([^"]*)" \}')
      .allMatches(source)
      .map((m) => (input: m[1]!, expected: m[2]!))
      .toList();

  test('server vector table is present', () {
    expect(vectors.length, greaterThanOrEqualTo(6));
  });

  for (final v in vectors) {
    test('key("${v.input}") == "${v.expected}"', () {
      expect(halaqaNameKey(v.input), v.expected);
    });
  }

  test('duplicate pre-check finds normalized clashes only', () {
    const existing = ['حلقة الفجر', 'حلقة النور'];
    expect(duplicateHalaqaName('حَلقه  الفجر', existing), 'حلقة الفجر');
    expect(duplicateHalaqaName('حلقة-النور', existing), 'حلقة النور');
    expect(duplicateHalaqaName('حلقة العصر', existing), isNull);
    expect(duplicateHalaqaName('   ', existing), isNull);
  });
}

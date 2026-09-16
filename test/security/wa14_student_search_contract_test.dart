import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student_search/domain/entities/student_search_entry.dart';
import 'package:rafiq_academy/shared/domain/arabic_search_normalizer.dart';
import 'package:rafiq_academy/shared/domain/student_search_contract.dart';

/// WA-14 / C13 — query-side contract tests for the student directory.
///
/// The projection itself is written by Cloud Functions; these tests pin the
/// Dart half of the contract so a client can never drift from the writer.
void main() {
  group('WA-14 Arabic normalization', () {
    test('matches every shared vector', () {
      expect(arabicNormalizationVectors.length, greaterThanOrEqualTo(16));
      for (final vector in arabicNormalizationVectors) {
        expect(
          ArabicSearchNormalizer.normalize(vector.input),
          vector.expected,
          reason: 'vector "${vector.label}" diverged',
        );
      }
    });

    test('is byte-identical to the TypeScript writer vectors', () {
      final ts = File(
        'functions/src/search/arabicNormalization.ts',
      ).readAsStringSync();

      for (final vector in arabicNormalizationVectors) {
        // Compare code units, not just glyphs: a visually identical string
        // with different code points would silently break prefix queries.
        final normalized = ArabicSearchNormalizer.normalize(vector.input);
        expect(
          normalized.codeUnits,
          vector.expected.codeUnits,
          reason: 'vector "${vector.label}" is not byte-identical',
        );
        expect(
          ts.contains('expected: "${vector.expected}"'),
          isTrue,
          reason: 'TypeScript vectors are missing "${vector.label}"',
        );
      }

      expect(
        ts.contains(
          'ARABIC_NORMALIZATION_VERSION = ${ArabicSearchNormalizer.version}',
        ),
        isTrue,
        reason: 'normalization version must match the TypeScript writer',
      );
    });

    test('keeps waw/yeh hamza unfolded', () {
      expect(ArabicSearchNormalizer.normalize('مؤمن'), 'مؤمن');
      expect(ArabicSearchNormalizer.normalize('رئيس'), 'رئيس');
    });

    test('is idempotent and total', () {
      for (final vector in arabicNormalizationVectors) {
        final once = ArabicSearchNormalizer.normalize(vector.input);
        expect(ArabicSearchNormalizer.normalize(once), once);
      }
      expect(ArabicSearchNormalizer.normalize(null), '');
    });
  });

  group('WA-14 projection contract', () {
    test('pins the frozen field set', () {
      expect(StudentSearchContract.collection, 'studentSearch');
      expect(StudentSearchContract.fields, [
        'studentId',
        'fullName',
        'fullNameNormalized',
        'halaqaId',
        'halaqaName',
        'halaqaIds',
        'visibleTo',
        'updatedAt',
        'normalizationVersion',
      ]);
      expect(StudentSearchContract.maxHalaqaMemberships, 2);
    });

    test('declares the same field set as the TypeScript writer', () {
      final ts = File(
        'functions/src/search/studentSearchContract.ts',
      ).readAsStringSync();
      for (final field in StudentSearchContract.fields) {
        expect(
          ts.contains('_FIELD = "$field"'),
          isTrue,
          reason: '"$field" is missing from the TypeScript contract',
        );
      }
    });

    test('no forbidden field is part of the contract', () {
      for (final forbidden in StudentSearchContract.forbiddenFields) {
        expect(
          StudentSearchContract.fields.contains(forbidden),
          isFalse,
          reason: '"$forbidden" must never be projected',
        );
      }
      // The privacy vault is never referenced on the query side either.
      for (final path in const [
        'lib/shared/domain/student_search_contract.dart',
        'lib/features/student_search/data/datasources/'
            'student_search_remote_datasource.dart',
        'lib/features/student_search/data/models/'
            'student_search_entry_model.dart',
      ]) {
        expect(File(path).readAsStringSync().contains('userPrivate'), isFalse);
      }
    });

    test('the entity exposes no authorization or private field', () {
      const entry = StudentSearchEntry(
        studentId: 'stu1',
        fullName: 'أحمد',
        fullNameNormalized: 'احمد',
        halaqaId: 'h1',
        halaqaName: 'حلقة الفجر',
        halaqaIds: ['h1'],
      );

      final serialized = jsonEncode({
        'studentId': entry.studentId,
        'fullName': entry.fullName,
        'fullNameNormalized': entry.fullNameNormalized,
        'halaqaId': entry.halaqaId,
        'halaqaName': entry.halaqaName,
        'halaqaIds': entry.halaqaIds,
      });
      for (final forbidden in StudentSearchContract.forbiddenFields) {
        expect(serialized.contains('"$forbidden"'), isFalse);
      }

      expect(entry.hasHalaqa, isTrue);
      expect(entry.disambiguationHint, 'حلقة الفجر');
    });

    test('an unassigned student falls back to the id for disambiguation', () {
      const entry = StudentSearchEntry(
        studentId: 'stu9',
        fullName: 'أحمد',
        fullNameNormalized: 'احمد',
        halaqaId: null,
        halaqaName: '',
        halaqaIds: [],
      );
      expect(entry.hasHalaqa, isFalse);
      expect(entry.disambiguationHint, 'stu9');
    });
  });

  group('WA-14 prefix range', () {
    test('bounds are normalized and ordered', () {
      const raw = '  أحـمَد ';
      expect(StudentSearchContract.prefixStart(raw), 'احمد');
      expect(
        StudentSearchContract.prefixEnd(raw),
        'احمد${StudentSearchContract.prefixRangeSuffix}',
      );
      expect(
        StudentSearchContract.prefixStart(
          raw,
        ).compareTo(StudentSearchContract.prefixEnd(raw)),
        lessThan(0),
      );
    });

    test('an empty query yields an empty lower bound (unfiltered listing)', () {
      expect(StudentSearchContract.prefixStart('   '), '');
    });

    test('document path requires a real student id', () {
      expect(StudentSearchContract.documentPath('stu1'), 'studentSearch/stu1');
      expect(
        () => StudentSearchContract.documentPath('  '),
        throwsArgumentError,
      );
    });
  });
}

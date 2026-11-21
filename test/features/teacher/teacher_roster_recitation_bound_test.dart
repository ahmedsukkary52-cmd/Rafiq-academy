import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/teacher/domain/services/halaqa_student_summary_projector.dart';

/// D2: roster enrichment must not load lifetime recitation history.
void main() {
  test('getHalaqaStudents bounds recitationRecords by the attendance window', () {
    final src = File(
      'lib/features/teacher/data/data_sources/teacher_remote_datasource_impl.dart',
    ).readAsStringSync();

    final rosterStart = src.indexOf('Future<List<HalaqaStudentSummaryModel>> getHalaqaStudents');
    expect(rosterStart, greaterThanOrEqualTo(0));
    final nextMethod = src.indexOf(
      'Future<List<RecitationRecordModel>> getHalaqaRecitationRecords',
      rosterStart,
    );
    final body = src.substring(
      rosterStart,
      nextMethod > rosterStart ? nextMethod : src.length,
    );

    expect(body.contains("FirestoreCollections.recitationRecords"), isTrue);
    expect(
      body.contains("isGreaterThanOrEqualTo: Timestamp.fromDate(from)"),
      isTrue,
      reason: 'recitation query must share the attendance `from` window',
    );
    expect(
      body.contains("orderBy('date', descending: true)"),
      isTrue,
    );
    // Unbounded halaqa-only get must not remain in the roster path.
    expect(
      RegExp(
        r"recitationRecords[\s\S]{0,200}\.where\('halaqaId'[\s\S]{0,80}\)\s*\.get\(\)",
      ).hasMatch(body),
      isFalse,
    );
    expect(HalaqaStudentSummaryProjector.attendanceWindowDays, 30);
  });
}

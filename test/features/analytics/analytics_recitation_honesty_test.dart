import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/features/analytics/domain/analytics_recitation_honesty.dart';
import 'package:rafiq_academy/shared/domain/student_at_risk_policy.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  group('AnalyticsRecitationHonesty (Phase 1)', () {
    test('pending recitation is excluded from performance', () {
      expect(
        AnalyticsRecitationHonesty.countsForPerformance(
          reviewStatus: 'pending',
          grade: RecitationGrades.excellent,
        ),
        isFalse,
      );
    });

    test('null / empty grade is excluded from performance', () {
      expect(
        AnalyticsRecitationHonesty.countsForPerformance(
          reviewStatus: 'reviewed',
          grade: null,
        ),
        isFalse,
      );
      expect(
        AnalyticsRecitationHonesty.countsForPerformance(
          reviewStatus: 'reviewed',
          grade: '   ',
        ),
        isFalse,
      );
    });

    test(
      'reviewed grade is included; missing reviewStatus treated as reviewed',
      () {
        expect(
          AnalyticsRecitationHonesty.countsForPerformance(
            reviewStatus: 'reviewed',
            grade: RecitationGrades.excellent,
          ),
          isTrue,
        );
        expect(
          AnalyticsRecitationHonesty.countsForPerformance(
            reviewStatus: null,
            grade: RecitationGrades.good,
          ),
          isTrue,
        );
      },
    );

    test('aggregatePerformance is event-weighted and skips pending/null', () {
      final result = AnalyticsRecitationHonesty.aggregatePerformance([
        const AnalyticsRecitationRef(
          studentId: 's1',
          grade: RecitationGrades.excellent,
          reviewStatus: 'reviewed',
        ),
        const AnalyticsRecitationRef(
          studentId: 's1',
          grade: RecitationGrades.excellent,
          reviewStatus: 'pending', // excluded
        ),
        const AnalyticsRecitationRef(
          studentId: 's2',
          grade: null,
          reviewStatus: 'reviewed', // excluded
        ),
        const AnalyticsRecitationRef(
          studentId: 's2',
          grade: RecitationGrades.good,
          reviewStatus: 'reviewed',
        ),
      ]);

      // Two events: ممتاز + جيد → average (100+60)/2 = 80
      expect(result.includedEventCount, 2);
      expect(result.averagePercent, 80);
      expect(result.distribution[RecitationGrades.excellent], 1);
      expect(result.distribution[RecitationGrades.good], 1);
      // Event-weighted (not unique students): still open product decision.
      expect(result.distribution.values.fold<int>(0, (a, b) => a + b), 2);
    });

    test('rankTopStudents orders by average and respects limit', () {
      final ranked = AnalyticsRecitationHonesty.rankTopStudents([
        const AnalyticsRecitationRef(
          studentId: 'low',
          studentName: 'Low',
          grade: RecitationGrades.good,
          reviewStatus: 'reviewed',
        ),
        const AnalyticsRecitationRef(
          studentId: 'high',
          studentName: 'High',
          grade: RecitationGrades.excellent,
          reviewStatus: 'reviewed',
        ),
        const AnalyticsRecitationRef(
          studentId: 'high',
          studentName: 'High',
          grade: RecitationGrades.excellent,
          reviewStatus: 'pending', // ignored
        ),
        const AnalyticsRecitationRef(
          studentId: 'mid',
          studentName: 'Mid',
          grade: RecitationGrades.veryGood,
          reviewStatus: 'reviewed',
        ),
      ], limit: 2);

      expect(ranked.length, 2);
      expect(ranked[0].studentId, 'high');
      expect(ranked[0].performancePercent, 100);
      expect(ranked[1].studentId, 'mid');
      expect(ranked[1].performancePercent, 80);
    });

    test('evaluatedStudentIds ignores pending and null-grade docs', () {
      final ids = AnalyticsRecitationHonesty.evaluatedStudentIds([
        const AnalyticsRecitationRef(
          studentId: 's1',
          grade: RecitationGrades.excellent,
          reviewStatus: 'pending',
        ),
        const AnalyticsRecitationRef(
          studentId: 's2',
          grade: null,
          reviewStatus: 'reviewed',
        ),
        const AnalyticsRecitationRef(
          studentId: 's3',
          grade: RecitationGrades.good,
          reviewStatus: 'reviewed',
        ),
      ]);

      expect(ids, {'s3'});
    });
  });

  group('At-risk + honesty input (policy thresholds unchanged)', () {
    final day = DateTime(2026, 8, 4);

    AttendanceMarkRef mark(String status, int daysAgo) => AttendanceMarkRef(
      id: '$status-$daysAgo',
      halaqaId: 'h1',
      studentId: 's1',
      date: day.subtract(Duration(days: daysAgo)),
      status: status,
    );

    test('pending-only recitations ⇒ no evaluation ⇒ at risk', () {
      final evaluated = AnalyticsRecitationHonesty.evaluatedStudentIds([
        const AnalyticsRecitationRef(
          studentId: 's1',
          grade: RecitationGrades.excellent,
          reviewStatus: 'pending',
        ),
      ]);
      expect(evaluated.contains('s1'), isFalse);

      final signal = StudentAtRiskPolicy.evaluate(
        marksInWindow: [mark('present', 1)],
        hasEvaluationInWindow: evaluated.contains('s1'),
      );
      expect(signal, RiskSignal.noRecentEvaluation);
    });

    test('reviewed grade ⇒ evaluated ⇒ not at risk (no repeated absence)', () {
      final evaluated = AnalyticsRecitationHonesty.evaluatedStudentIds([
        const AnalyticsRecitationRef(
          studentId: 's1',
          grade: RecitationGrades.good,
          reviewStatus: 'reviewed',
        ),
      ]);

      expect(
        StudentAtRiskPolicy.isAtRisk(
          marksInWindow: [mark('present', 1)],
          hasEvaluationInWindow: evaluated.contains('s1'),
        ),
        isFalse,
      );
    });

    test('thresholds and lowPerformance stay inactive/unmodified', () {
      expect(StudentAtRiskPolicy.windowDays, 14);
      expect(StudentAtRiskPolicy.repeatedAbsenceThreshold, 2);
      // lowPerformance is never returned by evaluate today.
      final signal = StudentAtRiskPolicy.evaluate(
        marksInWindow: const [],
        hasEvaluationInWindow: true,
      );
      expect(signal, isNot(RiskSignal.lowPerformance));
      expect(signal, isNull);
    });
  });

  group('Attendance aggregation unchanged (smoke)', () {
    test('late still counts as attended via AttendancePolicy', () {
      final statuses = AttendancePolicy.uniqueDayStatuses([
        AttendanceMarkRef(
          id: '1',
          halaqaId: 'h1',
          studentId: 's1',
          date: DateTime(2026, 8, 1),
          status: 'late',
        ),
        AttendanceMarkRef(
          id: '2',
          halaqaId: 'h1',
          studentId: 's2',
          date: DateTime(2026, 8, 1),
          status: 'absent',
        ),
      ]);
      expect(AttendancePolicy.attendancePercentFromStatuses(statuses), 50);
    });
  });

  group('Index inventory', () {
    test('documents required recitationRecords(halaqaId, date) composite', () {
      expect(
        AnalyticsFirestoreIndexInventory.collection,
        FirestoreCollections.recitationRecords,
      );
      expect(AnalyticsFirestoreIndexInventory.requiredCompositeFields, [
        'halaqaId',
        'date',
      ]);
      expect(AnalyticsFirestoreIndexInventory.inventoriedInRepo, isTrue);
    });
  });
}

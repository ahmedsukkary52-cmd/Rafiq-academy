import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/student_at_risk_policy.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  final day = DateTime(2026, 8, 4);

  AttendanceMarkRef mark(String status, int daysAgo) => AttendanceMarkRef(
        id: '$status-$daysAgo',
        halaqaId: 'h1',
        studentId: 's1',
        date: day.subtract(Duration(days: daysAgo)),
        status: status,
      );

  test('repeated absence wins over missing evaluation', () {
    final signal = StudentAtRiskPolicy.evaluate(
      marksInWindow: [mark('absent', 1), mark('absent', 3)],
      hasEvaluationInWindow: false,
    );
    expect(signal, RiskSignal.repeatedAbsence);
  });

  test('no recent evaluation alone → at risk', () {
    final signal = StudentAtRiskPolicy.evaluate(
      marksInWindow: [mark('present', 1)],
      hasEvaluationInWindow: false,
    );
    expect(signal, RiskSignal.noRecentEvaluation);
  });

  test('present with recent evaluation → not at risk', () {
    expect(
      StudentAtRiskPolicy.isAtRisk(
        marksInWindow: [mark('present', 1)],
        hasEvaluationInWindow: true,
      ),
      isFalse,
    );
  });

  test('thresholds stay centralized', () {
    expect(StudentAtRiskPolicy.windowDays, 14);
    expect(StudentAtRiskPolicy.repeatedAbsenceThreshold, 2);
  });
}

import '../utils/attendance_policy.dart';

/// Single owner of student “at risk” thresholds (analytics + teacher roster).
///
/// Matches the product rules already used by analytics `getAtRiskStudents`:
/// - window: last [windowDays] days
/// - [RiskSignal.repeatedAbsence]: ≥ [repeatedAbsenceThreshold] absences
///   after [AttendancePolicy.uniqueDayStatuses]
/// - [RiskSignal.noRecentEvaluation]: no recitation in the same window
///
/// [RiskSignal.lowPerformance] is reserved for a future product rule and is
/// **not** applied here (analytics does not apply it either).
enum RiskSignal { repeatedAbsence, noRecentEvaluation, lowPerformance }

class StudentAtRiskPolicy {
  const StudentAtRiskPolicy._();

  static const int windowDays = 14;
  static const int repeatedAbsenceThreshold = 2;

  /// Returns the primary risk signal, or `null` when the student is not at risk.
  ///
  /// Priority matches analytics: repeated absence wins over no recent evaluation.
  static RiskSignal? evaluate({
    required Iterable<AttendanceMarkRef> marksInWindow,
    required bool hasEvaluationInWindow,
  }) {
    final absences = AttendancePolicy.countAbsent(
      AttendancePolicy.uniqueDayStatuses(marksInWindow),
    );
    if (absences >= repeatedAbsenceThreshold) {
      return RiskSignal.repeatedAbsence;
    }
    if (!hasEvaluationInWindow) {
      return RiskSignal.noRecentEvaluation;
    }
    return null;
  }

  static bool isAtRisk({
    required Iterable<AttendanceMarkRef> marksInWindow,
    required bool hasEvaluationInWindow,
  }) =>
      evaluate(
        marksInWindow: marksInWindow,
        hasEvaluationInWindow: hasEvaluationInWindow,
      ) !=
      null;
}

import '../../../../core/constants/app_constants.dart';

/// Phase 0 locked Analytics honesty + aggregation helpers (event-weighted).
///
/// Locked product rules (do not invent alternatives here):
/// - Performance / top students: **reviewed** recitations with a **non-null,
///   non-empty** grade only.
/// - At-risk “evaluated”: same rule (reviewed + countable grade).
/// - Pending / missing-as-pending never count.
/// - Legacy docs with no `reviewStatus` field → treated as `reviewed`
///   (same convention as parent/student parsers).
/// - Performance distribution stays **event-weighted** (one grade occurrence =
///   one count). Student-vs-event weighting remains an open academy decision.
/// - [StudentAtRiskPolicy] thresholds / `lowPerformance` are unchanged.
///
/// CTA intent (wired in a later phase, not here):
/// - تقييم → existing Evaluations route
/// - تواصل → teacher↔student Chat only (never parent)
///
/// Required Firestore composite index for Analytics queries:
/// `recitationRecords`: `halaqaId` ASC + `date` ASC
/// — see [AnalyticsFirestoreIndexInventory] + `firestore.indexes.json`.
class AnalyticsRecitationHonesty {
  const AnalyticsRecitationHonesty._();

  /// Grade labels → weights used by Analytics (event-weighted).
  ///
  /// Includes both historical label variants for “needs work”.
  static const Map<String, double> gradeWeights = {
    RecitationGrades.excellent: 100.0,
    RecitationGrades.veryGood: 80.0,
    RecitationGrades.good: 60.0,
    'يحتاج تحسين': 40.0,
    RecitationGrades.needsRetry: 40.0, // 'يحتاج إعادة' — legacy/alternate
  };

  static const List<String> distributionBucketOrder = [
    RecitationGrades.excellent,
    RecitationGrades.veryGood,
    RecitationGrades.good,
    'يحتاج تحسين',
  ];

  /// Canonical bucket key for distribution UI (collapse legacy needs-retry).
  static String? distributionBucketFor(String grade) {
    if (grade == RecitationGrades.needsRetry || grade == 'يحتاج تحسين') {
      return 'يحتاج تحسين';
    }
    if (gradeWeights.containsKey(grade) &&
        grade != RecitationGrades.needsRetry) {
      return grade;
    }
    return null;
  }

  static bool isReviewedForAnalytics(String? reviewStatus) {
    // Missing field ⇒ reviewed (legacy live-eval docs).
    final status = reviewStatus ?? 'reviewed';
    return status != 'pending';
  }

  static bool hasCountableGrade(String? grade) {
    final trimmed = grade?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    return gradeWeights.containsKey(trimmed);
  }

  /// Performance average, distribution, and top-students inclusion.
  static bool countsForPerformance({
    required String? reviewStatus,
    required String? grade,
  }) => isReviewedForAnalytics(reviewStatus) && hasCountableGrade(grade);

  /// At-risk “has evaluation in window” — same honesty bar as performance.
  static bool countsAsEvaluationForAtRisk({
    required String? reviewStatus,
    required String? grade,
  }) => countsForPerformance(reviewStatus: reviewStatus, grade: grade);

  /// Event-weighted distribution + average from raw recitation field maps.
  ///
  /// Each included doc increments exactly one distribution bucket (event).
  static ({
    Map<String, int> distribution,
    double averagePercent,
    int includedEventCount,
  })
  aggregatePerformance(Iterable<AnalyticsRecitationRef> records) {
    final distribution = <String, int>{
      for (final key in distributionBucketOrder) key: 0,
    };

    double totalScore = 0;
    var included = 0;

    for (final record in records) {
      if (!countsForPerformance(
        reviewStatus: record.reviewStatus,
        grade: record.grade,
      )) {
        continue;
      }
      final grade = record.grade!.trim();
      final bucket = distributionBucketFor(grade);
      if (bucket == null) continue;

      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
      totalScore += gradeWeights[grade] ?? gradeWeights[bucket] ?? 0;
      included++;
    }

    final average = included > 0 ? totalScore / included : 0.0;
    return (
      distribution: distribution,
      averagePercent: average,
      includedEventCount: included,
    );
  }

  /// Per-student averages from countable events; highest first; [limit] cap.
  static List<AnalyticsTopStudentScore> rankTopStudents(
    Iterable<AnalyticsRecitationRef> records, {
    int limit = 5,
  }) {
    final scoreSum = <String, double>{};
    final eventCount = <String, int>{};
    final names = <String, String>{};

    for (final record in records) {
      if (!countsForPerformance(
        reviewStatus: record.reviewStatus,
        grade: record.grade,
      )) {
        continue;
      }
      final id = record.studentId;
      if (id.isEmpty) continue;
      final grade = record.grade!.trim();
      scoreSum[id] = (scoreSum[id] ?? 0) + (gradeWeights[grade] ?? 0);
      eventCount[id] = (eventCount[id] ?? 0) + 1;
      if (record.studentName != null && record.studentName!.trim().isNotEmpty) {
        names[id] = record.studentName!.trim();
      }
    }

    final averages =
        scoreSum.entries
            .map(
              (e) => AnalyticsTopStudentScore(
                studentId: e.key,
                studentName: names[e.key] ?? '',
                performancePercent: e.value / (eventCount[e.key] ?? 1),
              ),
            )
            .toList()
          ..sort(
            (a, b) => b.performancePercent.compareTo(a.performancePercent),
          );

    return averages.take(limit).toList();
  }

  /// Student ids that have at least one honest evaluation in [records].
  static Set<String> evaluatedStudentIds(
    Iterable<AnalyticsRecitationRef> records,
  ) {
    final ids = <String>{};
    for (final record in records) {
      if (record.studentId.isEmpty) continue;
      if (!countsAsEvaluationForAtRisk(
        reviewStatus: record.reviewStatus,
        grade: record.grade,
      )) {
        continue;
      }
      ids.add(record.studentId);
    }
    return ids;
  }
}

/// Minimal recitation fields needed for Analytics honesty (no Firestore types).
class AnalyticsRecitationRef {
  final String studentId;
  final String? studentName;
  final String? grade;
  final String? reviewStatus;

  const AnalyticsRecitationRef({
    required this.studentId,
    this.studentName,
    this.grade,
    this.reviewStatus,
  });
}

class AnalyticsTopStudentScore {
  final String studentId;
  final String studentName;
  final double performancePercent;

  const AnalyticsTopStudentScore({
    required this.studentId,
    required this.studentName,
    required this.performancePercent,
  });
}

/// Inventory of the composite index Analytics queries need.
///
/// Repo entry: `firestore.indexes.json` (Analytics Phase 2). Deploy via
/// Firebase CLI / console when ops allow — not automatic from app builds.
class AnalyticsFirestoreIndexInventory {
  const AnalyticsFirestoreIndexInventory._();

  static const collection = FirestoreCollections.recitationRecords;

  /// Fields for: where halaqaId == X + date >= / < range (and >= only).
  static const requiredCompositeFields = <String>['halaqaId', 'date'];

  static const inventoriedInRepo = true;

  static const description =
      'recitationRecords: halaqaId ASC + date ASC — required for '
      'GetHalaqaAnalytics / GetAtRiskStudents / GetTopStudents / '
      'Class Details header stats.';
}

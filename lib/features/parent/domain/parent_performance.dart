import '../../analytics/domain/analytics_recitation_honesty.dart';
import '../../student/domain/entities/recitation_record_entity.dart';

/// Parent-facing performance % using Analytics grade weights (100/80/60/40).
class ParentPerformance {
  const ParentPerformance._();

  static double? averagePercent(Iterable<RecitationRecordEntity> records) {
    var total = 0.0;
    var count = 0;
    for (final record in records) {
      if (record.isPendingReview) continue;
      final label = record.grade?.label.trim() ?? '';
      if (label.isEmpty) continue;
      if (!AnalyticsRecitationHonesty.hasCountableGrade(label)) continue;
      total += AnalyticsRecitationHonesty.gradeWeights[label] ?? 0;
      count++;
    }
    if (count == 0) return null;
    return total / count;
  }

  static Map<String, int> gradeCounts(Iterable<RecitationRecordEntity> records) {
    final counts = {
      for (final key in AnalyticsRecitationHonesty.distributionBucketOrder)
        key: 0,
    };
    for (final record in records) {
      if (record.isPendingReview) continue;
      final label = record.grade?.label.trim() ?? '';
      final bucket = AnalyticsRecitationHonesty.distributionBucketFor(label);
      if (bucket == null) continue;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    return counts;
  }
}

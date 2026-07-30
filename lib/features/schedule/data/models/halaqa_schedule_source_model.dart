import '../../domain/entities/halaqa_schedule_source.dart';

/// Data-layer alias for Firestore schedule payloads (same shape as domain).
typedef HalaqaScheduleSlotModel = HalaqaScheduleSlot;
typedef HalaqaScheduleSourceModel = HalaqaScheduleSource;

/// Parses a schedule slot map from Firestore.
HalaqaScheduleSlot halaqaScheduleSlotFromMap(Map<String, dynamic> map) {
  return HalaqaScheduleSlot(
    day: (map['day'] as String?)?.trim() ?? '',
    startTime: (map['startTime'] as String?)?.trim() ?? '',
    endTime: (map['endTime'] as String?)?.trim() ?? '',
  );
}

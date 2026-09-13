import '../../domain/entities/halaqa_schedule_source.dart';

/// Data-layer alias for Firestore schedule payloads (same shape as domain).
typedef HalaqaScheduleSlotModel = HalaqaScheduleSlot;
typedef HalaqaScheduleSourceModel = HalaqaScheduleSource;

/// Parses a schedule slot map from Firestore.
HalaqaScheduleSlot halaqaScheduleSlotFromMap(Map<String, dynamic> map) {
  final rawId = map['slotId'];
  final slotId = rawId is String ? rawId.trim() : '';
  return HalaqaScheduleSlot(
    day: (map['day'] as String?)?.trim() ?? '',
    startTime: (map['startTime'] as String?)?.trim() ?? '',
    endTime: (map['endTime'] as String?)?.trim() ?? '',
    slotId: slotId.isEmpty ? null : slotId,
  );
}

/// Serializes a schedule slot for Firestore (preserves slotId when present).
Map<String, dynamic> halaqaScheduleSlotToMap(HalaqaScheduleSlot slot) {
  return {
    'day': slot.day,
    'startTime': slot.startTime,
    'endTime': slot.endTime,
    if (slot.slotId != null && slot.slotId!.trim().isNotEmpty)
      'slotId': slot.slotId!.trim(),
  };
}

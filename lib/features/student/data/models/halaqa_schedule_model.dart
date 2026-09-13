import '../../domain/entities/halaqa_entity.dart';

class HalaqaScheduleModel extends HalaqaScheduleEntity {
  const HalaqaScheduleModel({
    required super.day,
    required super.startTime,
    required super.endTime,
    super.slotId,
  });

  factory HalaqaScheduleModel.fromMap(Map<String, dynamic> map) {
    final rawId = map['slotId'];
    final slotId = rawId is String ? rawId.trim() : '';
    return HalaqaScheduleModel(
      day: map['day'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      slotId: slotId.isEmpty ? null : slotId,
    );
  }

  Map<String, dynamic> toMap() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
    if (slotId != null && slotId!.trim().isNotEmpty) 'slotId': slotId!.trim(),
  };
}

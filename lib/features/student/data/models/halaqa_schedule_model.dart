import '../../domain/entities/halaqa_entity.dart';

class HalaqaScheduleModel extends HalaqaScheduleEntity {
  const HalaqaScheduleModel({
    required super.day,
    required super.startTime,
    required super.endTime,
  });

  factory HalaqaScheduleModel.fromMap(Map<String, dynamic> map) {
    return HalaqaScheduleModel(
      day: map['day'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'day': day,
    'startTime': startTime,
    'endTime': endTime,
  };
}

/// Raw halaqa schedule payload from Firestore (no derived session times).
class HalaqaScheduleSlotModel {
  final String day;
  final String startTime;
  final String endTime;

  const HalaqaScheduleSlotModel({
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  factory HalaqaScheduleSlotModel.fromMap(Map<String, dynamic> map) {
    return HalaqaScheduleSlotModel(
      day: (map['day'] as String?)?.trim() ?? '',
      startTime: (map['startTime'] as String?)?.trim() ?? '',
      endTime: (map['endTime'] as String?)?.trim() ?? '',
    );
  }
}

class HalaqaScheduleSourceModel {
  final String halaqaId;
  final String name;
  final String meetingLink;
  final List<HalaqaScheduleSlotModel> schedule;

  const HalaqaScheduleSourceModel({
    required this.halaqaId,
    required this.name,
    required this.meetingLink,
    required this.schedule,
  });
}

import '../../../student/domain/entities/halaqa_entity.dart';
import '../entities/halaqa_schedule_source.dart';

/// Bridges [HalaqaEntity] → schedule source for today's operational days.
///
/// Single conversion used by teacher agenda and supervisor day board (H2).
HalaqaScheduleSource halaqaScheduleSourceFromEntity(HalaqaEntity h) {
  return HalaqaScheduleSource(
    halaqaId: h.id,
    name: h.name,
    meetingLink: h.meetingLink,
    schedule: h.schedule
        .map(
          (s) => HalaqaScheduleSlot(
            day: s.day,
            startTime: s.startTime,
            endTime: s.endTime,
          ),
        )
        .toList(),
  );
}

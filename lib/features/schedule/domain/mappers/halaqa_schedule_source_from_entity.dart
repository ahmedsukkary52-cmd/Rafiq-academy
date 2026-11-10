import '../../../../shared/domain/halaqa_entity.dart';
import '../entities/halaqa_schedule_source.dart';

/// Bridges [HalaqaEntity] → schedule source for today's operational days.
///
/// Single conversion used by teacher agenda and supervisor day board (H2).
HalaqaScheduleSource halaqaScheduleSourceFromEntity(HalaqaEntity h) {
  return HalaqaScheduleSource(
    halaqaId: h.id,
    name: h.name,
    schedule: h.schedule
        .map(
          (s) => HalaqaScheduleSlot(
            day: s.day,
            startTime: s.startTime,
            endTime: s.endTime,
            slotId: s.slotId,
          ),
        )
        .toList(),
  );
}

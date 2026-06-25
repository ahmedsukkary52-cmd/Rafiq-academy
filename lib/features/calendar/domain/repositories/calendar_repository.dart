import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/calendar_event_entity.dart';

abstract class CalendarRepository {
  /// جلب أحداث شهر معيّن (للتقويم - تحميل مرة واحدة مش stream)
  Future<Either<Failure, List<CalendarEventEntity>>> getMonthEvents({
    required DateTime month,
    String? halaqaId,
  });

  /// إضافة حدث جديد (صلاحية المعلم والإدارة)
  Future<Either<Failure, Unit>> addEvent(CalendarEventEntity event);

  /// حذف حدث (صاحبه أو الإدارة)
  Future<Either<Failure, Unit>> deleteEvent(String eventId);
}

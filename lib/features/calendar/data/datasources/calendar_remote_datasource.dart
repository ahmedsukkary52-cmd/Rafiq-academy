import '../models/calendar_model.dart';

abstract class CalendarRemoteDatasource {
  Future<List<CalendarEventModel>> getMonthEvents({
    required DateTime month,
    String? halaqaId,
  });

  Future<void> addEvent(CalendarEventModel event);

  Future<void> deleteEvent(String eventId);
}

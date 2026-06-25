import 'package:equatable/equatable.dart';

import '../../domain/entities/calendar_event_entity.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object?> get props => [];
}

/// تحميل أحداث شهر معيّن (عند فتح الشاشة أو التنقل بين الأشهر)
class LoadMonthEventsEvent extends CalendarEvent {
  final DateTime month;
  final String? halaqaId;

  const LoadMonthEventsEvent({required this.month, this.halaqaId});

  @override
  List<Object?> get props => [month, halaqaId];
}

/// اختيار يوم من التقويم لعرض أحداثه في القائمة تحت
class SelectDayEvent extends CalendarEvent {
  final DateTime day;

  const SelectDayEvent(this.day);

  @override
  List<Object?> get props => [day];
}

/// إضافة حدث جديد
class AddEventEvent extends CalendarEvent {
  final CalendarEventEntity event;

  const AddEventEvent(this.event);

  @override
  List<Object?> get props => [event];
}

class ResetAddEventEvent extends CalendarEvent {
  const ResetAddEventEvent();
}

/// حذف حدث
class DeleteEventEvent extends CalendarEvent {
  final String eventId;

  const DeleteEventEvent(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/calendar_event_entity.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class CalendarState extends Equatable {
  /// كل أحداث الشهر المحمّل حالياً
  final SectionStatus eventsStatus;
  final List<CalendarEventEntity> monthEvents;
  final String? eventsError;

  /// الشهر المعروض حالياً
  final DateTime focusedMonth;

  /// اليوم المختار لعرض أحداثه في القائمة (null = اليوم الحالي)
  final DateTime? selectedDay;

  /// إضافة حدث جديد
  final SubmissionStatus addEventStatus;
  final String? addEventError;

  CalendarState({
    this.eventsStatus = SectionStatus.initial,
    this.monthEvents = const [],
    this.eventsError,
    DateTime? focusedMonth,
    this.selectedDay,
    this.addEventStatus = SubmissionStatus.idle,
    this.addEventError,
  }) : focusedMonth = focusedMonth ?? DateTime.now();

  factory CalendarState.initial() => CalendarState();

  /// أحداث اليوم المختار فقط
  List<CalendarEventEntity> get selectedDayEvents {
    final day = selectedDay ?? DateTime.now();
    return monthEvents
        .where((e) => e.dateOnly == DateTime(day.year, day.month, day.day))
        .toList();
  }

  /// map من كل يوم لقائمة أنواعه (لرسم النقاط على التقويم بكفاءة)
  Map<DateTime, List<CalendarEventType>> get eventTypesPerDay {
    final map = <DateTime, List<CalendarEventType>>{};
    for (final event in monthEvents) {
      map.putIfAbsent(event.dateOnly, () => []).add(event.type);
    }
    return map;
  }

  CalendarState copyWith({
    SectionStatus? eventsStatus,
    List<CalendarEventEntity>? monthEvents,
    Object? eventsError = _unset,
    DateTime? focusedMonth,
    Object? selectedDay = _unset,
    SubmissionStatus? addEventStatus,
    Object? addEventError = _unset,
  }) {
    return CalendarState(
      eventsStatus: eventsStatus ?? this.eventsStatus,
      monthEvents: monthEvents ?? this.monthEvents,
      eventsError: identical(eventsError, _unset)
          ? this.eventsError
          : eventsError as String?,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDay: identical(selectedDay, _unset)
          ? this.selectedDay
          : selectedDay as DateTime?,
      addEventStatus: addEventStatus ?? this.addEventStatus,
      addEventError: identical(addEventError, _unset)
          ? this.addEventError
          : addEventError as String?,
    );
  }

  @override
  List<Object?> get props => [
    eventsStatus,
    monthEvents,
    eventsError,
    focusedMonth,
    selectedDay,
    addEventStatus,
    addEventError,
  ];
}

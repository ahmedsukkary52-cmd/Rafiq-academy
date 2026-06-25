import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/usecases/calendar_usecases.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

/// @injectable (مش @singleton) لأن شاشة التقويم ممكن تتفتح من سياقات
/// مختلفة (نافذة الطالب، نافذة المعلم) بـ halaqaId مختلف في كل مرة.
/// بنمرر الـ halaqaId في أول event (LoadMonthEventsEvent) مش في
/// الـ constructor، عشان منحتاجش @factoryParam.
@injectable
class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final GetMonthEventsUseCase getMonthEvents;
  final AddCalendarEventUseCase addCalendarEvent;
  final DeleteCalendarEventUseCase deleteCalendarEvent;

  CalendarBloc({
    required this.getMonthEvents,
    required this.addCalendarEvent,
    required this.deleteCalendarEvent,
  }) : super(CalendarState.initial()) {
    on<LoadMonthEventsEvent>(_onLoadMonthEvents);
    on<SelectDayEvent>(_onSelectDay);
    on<AddEventEvent>(_onAddEvent);
    on<ResetAddEventEvent>(_onResetAddEvent);
    on<DeleteEventEvent>(_onDeleteEvent);
  }

  Future<void> _onLoadMonthEvents(
    LoadMonthEventsEvent event,
    Emitter<CalendarState> emit,
  ) async {
    emit(
      state.copyWith(
        eventsStatus: SectionStatus.loading,
        eventsError: null,
        focusedMonth: event.month,
      ),
    );

    final result = await getMonthEvents(
      GetMonthEventsParams(month: event.month, halaqaId: event.halaqaId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          eventsStatus: SectionStatus.error,
          eventsError: failure.message,
        ),
      ),
      (events) => emit(
        state.copyWith(eventsStatus: SectionStatus.loaded, monthEvents: events),
      ),
    );
  }

  void _onSelectDay(SelectDayEvent event, Emitter<CalendarState> emit) {
    emit(state.copyWith(selectedDay: event.day));
  }

  Future<void> _onAddEvent(
    AddEventEvent event,
    Emitter<CalendarState> emit,
  ) async {
    emit(
      state.copyWith(
        addEventStatus: SubmissionStatus.submitting,
        addEventError: null,
      ),
    );

    final result = await addCalendarEvent(event.event);

    result.fold(
      (failure) => emit(
        state.copyWith(
          addEventStatus: SubmissionStatus.error,
          addEventError: failure.message,
        ),
      ),
      (_) {
        // Optimistic: نضيف الحدث للقائمة المحلية فوراً بدل ما
        // نعمل reload كامل للشهر
        final updated = [...state.monthEvents, event.event]
          ..sort((a, b) => a.date.compareTo(b.date));

        emit(
          state.copyWith(
            addEventStatus: SubmissionStatus.success,
            monthEvents: updated,
          ),
        );
      },
    );
  }

  void _onResetAddEvent(ResetAddEventEvent event, Emitter<CalendarState> emit) {
    emit(
      state.copyWith(
        addEventStatus: SubmissionStatus.idle,
        addEventError: null,
      ),
    );
  }

  Future<void> _onDeleteEvent(
    DeleteEventEvent event,
    Emitter<CalendarState> emit,
  ) async {
    // Optimistic: نشيل الحدث فوراً
    final updated = state.monthEvents
        .where((e) => e.id != event.eventId)
        .toList();
    emit(state.copyWith(monthEvents: updated));

    await deleteCalendarEvent(DeleteEventParams(event.eventId));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/calendar_event_entity.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../widgets/add_calendar_event_sheet.dart';

/// Quarantined (H6 / A-H8): teacher calendar route removed from [AppRouter].
/// Page kept for possible future product; not reachable from live nav.
class CalendarPage extends StatefulWidget {
  final String? halaqaId;

  const CalendarPage({super.key, this.halaqaId});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final CalendarBloc _bloc;
  bool _addSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _bloc = sl<CalendarBloc>();
    _loadMonth(DateTime.now());
  }

  void _loadMonth(DateTime month) {
    _bloc.add(LoadMonthEventsEvent(month: month, halaqaId: widget.halaqaId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<CalendarBloc, CalendarState>(
        listenWhen: (previous, current) =>
            previous.addEventStatus != current.addEventStatus,
        listener: (context, state) {
          if (state.addEventStatus == SubmissionStatus.success) {
            AppSnackBar.showSuccess(context, 'تم إضافة الحدث');
            context.read<CalendarBloc>().add(const ResetAddEventEvent());
          } else if (state.addEventStatus == SubmissionStatus.error) {
            // An open sheet shows the error inline beside the kept inputs.
            if (!_addSheetOpen) {
              AppSnackBar.showError(
                context,
                state.addEventError ?? 'تعذر إضافة الحدث',
              );
            }
            context.read<CalendarBloc>().add(const ResetAddEventEvent());
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('التقويم الأكاديمي'),
            actions: [
              TextButton.icon(
                onPressed: () => _showAddEventSheet(context),
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  '+ حدث',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          body: BlocBuilder<CalendarBloc, CalendarState>(
            buildWhen: (previous, current) =>
                previous.eventsStatus != current.eventsStatus ||
                previous.monthEvents != current.monthEvents ||
                previous.eventsError != current.eventsError ||
                previous.focusedMonth != current.focusedMonth ||
                previous.selectedDay != current.selectedDay,
            builder: (context, state) {
              final eventsByDay = <DateTime, List<CalendarEventEntity>>{};
              for (final event in state.monthEvents) {
                eventsByDay
                    .putIfAbsent(event.dateOnly, () => <CalendarEventEntity>[])
                    .add(event);
              }
              final dayEvents = state.selectedDayEvents;

              return Column(
                children: [
                  // ── التقويم ────────────────────────────────────
                  Container(
                    color: AppColors.surface,
                    child: TableCalendar<CalendarEventEntity>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: state.focusedMonth,
                      locale: 'ar',

                      selectedDayPredicate: (day) =>
                          isSameDay(day, state.selectedDay ?? DateTime.now()),

                      onDaySelected: (selected, focused) {
                        _bloc.add(SelectDayEvent(selected));
                      },

                      onPageChanged: (focused) {
                        _loadMonth(focused);
                      },

                      eventLoader: (day) {
                        final key = DateTime(day.year, day.month, day.day);
                        return eventsByDay[key] ?? const [];
                      },

                      calendarBuilders: CalendarBuilders(
                        // نقاط الأحداث تحت الأيام
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          final types = events.map((e) => (e).type).toSet();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: types.take(3).map((t) {
                              return Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: _colorForType(t),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        defaultTextStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        weekendTextStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                        ),
                        outsideDaysVisible: false,
                      ),

                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: AppTextStyles.titleLarge,
                        leftChevronPadding: const EdgeInsets.all(4),
                        rightChevronPadding: const EdgeInsets.all(4),
                        rightChevronIcon: const Icon(Icons
                            .chevron_right_rounded),
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded),
                      ),
                    ),
                  ),

                  // ── Legend ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.paddingM,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: CalendarEventType.values.map((t) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(t.label, style: AppTextStyles.labelSmall),
                              const SizedBox(width: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _colorForType(t),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // ── أحداث اليوم المختار ─────────────────────────
                  Expanded(
                    child: dayEvents.isEmpty
                        ? Center(
                            child: Text(
                              'لا توجد أحداث في هذا اليوم',
                              style: AppTextStyles.bodyMedium,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.paddingM,
                              vertical: 8,
                            ),
                            itemCount: dayEvents.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final event = dayEvents[i];
                              return _EventCard(event: event);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _colorForType(CalendarEventType t) => switch (t) {
    CalendarEventType.session => AppColors.eventSession,
    CalendarEventType.exam => AppColors.eventExam,
    CalendarEventType.holiday => AppColors.eventHoliday,
    CalendarEventType.occasion => AppColors.eventOccasion,
  };

  Future<void> _showAddEventSheet(BuildContext context) async {
    _addSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _bloc,
        child: AddCalendarEventSheet(halaqaId: widget.halaqaId),
      ),
    );
    _addSheetOpen = false;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _EventCard
// ══════════════════════════════════════════════════════════════════════════════

class _EventCard extends StatelessWidget {
  final CalendarEventEntity event;

  const _EventCard({required this.event});

  Color get _typeColor => switch (event.type) {
    CalendarEventType.session => AppColors.eventSession,
    CalendarEventType.exam => AppColors.eventExam,
    CalendarEventType.holiday => AppColors.eventHoliday,
    CalendarEventType.occasion => AppColors.eventOccasion,
  };

  @override
  Widget build(BuildContext context) {
    final isToday =
        event.dateOnly ==
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // الشريط الجانبي الملوّن
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: _typeColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(AppSizes.radiusL),
                bottomRight: Radius.circular(AppSizes.radiusL),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // تفاصيل الحدث
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull,
                            ),
                          ),
                          child: Text(
                            'اليوم',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Text(event.title, style: AppTextStyles.titleMedium),
                    ],
                  ),
                  if (event.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description!,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
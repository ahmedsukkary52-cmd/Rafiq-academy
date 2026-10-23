import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/calendar_event_entity.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';

/// Stays open (inputs intact) until [CalendarBloc] confirms the create; a
/// failure is shown inline so the user can retry without retyping.
class AddCalendarEventSheet extends StatefulWidget {
  final String? halaqaId;

  const AddCalendarEventSheet({super.key, this.halaqaId});

  @override
  State<AddCalendarEventSheet> createState() => _AddCalendarEventSheetState();
}

class _AddCalendarEventSheetState extends State<AddCalendarEventSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  CalendarEventType _type = CalendarEventType.session;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<CalendarBloc>();
    if (bloc.state.addEventStatus == SubmissionStatus.submitting) return;
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _error = null);
    final description = _descCtrl.text.trim();
    bloc.add(
      AddEventEvent(
        CalendarEventEntity(
          id: '',
          title: _titleCtrl.text.trim(),
          type: _type,
          date: _date,
          description: description.isEmpty ? null : description,
          halaqaId: widget.halaqaId,
          createdBy: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listenWhen: (p, c) => p.addEventStatus != c.addEventStatus,
      listener: (context, state) {
        if (state.addEventStatus == SubmissionStatus.success) {
          Navigator.of(context).pop();
        } else if (state.addEventStatus == SubmissionStatus.error) {
          setState(() => _error = state.addEventError ?? 'تعذر إضافة الحدث');
        }
      },
      buildWhen: (p, c) => p.addEventStatus != c.addEventStatus,
      builder: (context, state) {
        final submitting = state.addEventStatus == SubmissionStatus.submitting;
        return _buildSheet(context, submitting);
      },
    );
  }

  Widget _buildSheet(BuildContext context, bool submitting) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXL),
        ),
      ),
      padding: EdgeInsets.only(
        top: AppSizes.paddingL,
        left: AppSizes.paddingM,
        right: AppSizes.paddingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('إضافة حدث جديد', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),

            // اسم الحدث
            Text('اسم الحدث', style: AppTextStyles.labelLarge),
            const SizedBox(height: 6),
            AppTextField(
              hint: 'مثال: اختبار الحفظ الشهري',
              controller: _titleCtrl,
            ),

            const SizedBox(height: 16),

            // نوع الحدث
            Text('نوع الحدث', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: CalendarEventType.values.map((t) {
                final selected = t == _type;
                final color = _colorForType(t);
                return GestureDetector(
                  onTap: submitting ? null : () => setState(() => _type = t),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.12)
                          : AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      border: Border.all(
                        color: selected ? color : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      t.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // التاريخ
            Text('التاريخ', style: AppTextStyles.labelLarge),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: submitting
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textHint,
                      size: 18,
                    ),
                    Text(
                      '${_date.day}/${_date.month}/${_date.year}',
                      style: AppTextStyles.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ملاحظة اختيارية
            Text('وصف (اختياري)', style: AppTextStyles.labelLarge),
            const SizedBox(height: 6),
            AppTextField(hint: 'تفاصيل إضافية...', controller: _descCtrl),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('add-calendar-event-error'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.right,
              ),
            ],

            const SizedBox(height: 24),

            AppButton(
              key: const Key('add-calendar-event-submit'),
              label: 'إضافة الحدث',
              isLoading: submitting,
              onPressed: _submit,
            ),
          ],
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
}

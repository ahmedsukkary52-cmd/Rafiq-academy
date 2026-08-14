import 'package:flutter/material.dart';

import '../../../../../shared/theme/app_theme.dart';

/// Figma B1 «تقديم طلب اعتذار» form — local UI state only (Phase 1).
class TeacherExcusesFormSection extends StatelessWidget {
  final List<String> halaqaOptions;
  final String? selectedHalaqa;
  final String dateLabel;
  final TextEditingController reasonController;
  final ValueChanged<String?> onHalaqaChanged;
  final VoidCallback onDateTap;
  final VoidCallback onSubmit;
  final bool submitEnabled;

  const TeacherExcusesFormSection({
    super.key,
    required this.halaqaOptions,
    required this.selectedHalaqa,
    required this.dateLabel,
    required this.reasonController,
    required this.onHalaqaChanged,
    required this.onDateTap,
    required this.onSubmit,
    this.submitEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8EEF0), width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تقديم طلب اعتذار',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),
          const _FieldLabel('الحلقة'),
          const SizedBox(height: 5),
          _HalaqaField(
            options: halaqaOptions,
            value: selectedHalaqa,
            onChanged: onHalaqaChanged,
          ),
          const SizedBox(height: 8),
          const _FieldLabel('التاريخ'),
          const SizedBox(height: 5),
          _DateField(label: dateLabel, onTap: onDateTap),
          const SizedBox(height: 8),
          const _FieldLabel('سبب الاعتذار'),
          const SizedBox(height: 5),
          TextField(
            controller: reasonController,
            maxLines: 2,
            minLines: 2,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'اكتب السبب هنا...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: submitEnabled ? onSubmit : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Center(
                    child: Text(
                      'إرسال الطلب',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: const Color(0xFF4A4A5A),
        ),
      ),
    );
  }
}

class _HalaqaField extends StatelessWidget {
  final List<String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _HalaqaField({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasOptions = options.isNotEmpty;
    final effective = hasOptions && value != null && options.contains(value)
        ? value
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EEF0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: effective,
          hint: Text(
            hasOptions ? 'اختر الحلقة' : 'لا توجد حلقات بعد',
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textHint,
            ),
            textAlign: TextAlign.right,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textHint,
          ),
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          items: [
            for (final name in options)
              DropdownMenuItem(
                value: name,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(name, textAlign: TextAlign.right),
                ),
              ),
          ],
          onChanged: hasOptions ? onChanged : null,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DateField({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5FAFB),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EEF0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textHint,
              ),
              const Spacer(),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

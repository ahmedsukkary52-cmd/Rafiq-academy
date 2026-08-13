import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/attendance_policy.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../halaqa_activity/domain/usecases/halaqa_activity_usecases.dart';
import '../../../halaqa_activity/presentation/halaqa_activity_ui_mapper.dart';

Future<HalaqaActivityUi?> showCreateHalaqaActivitySheet(
  BuildContext context, {
  required String halaqaId,
}) {
  return showModalBottomSheet<HalaqaActivityUi>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXL),
      ),
    ),
    builder: (_) => CreateHalaqaActivitySheet(halaqaId: halaqaId),
  );
}

class CreateHalaqaActivitySheet extends StatefulWidget {
  final String halaqaId;

  const CreateHalaqaActivitySheet({super.key, required this.halaqaId});

  @override
  State<CreateHalaqaActivitySheet> createState() =>
      _CreateHalaqaActivitySheetState();
}

class _CreateHalaqaActivitySheetState extends State<CreateHalaqaActivitySheet> {
  final _promptCtrl = TextEditingController();
  final _selectedTypes = <ActivityResponseTypeUi>{
    ActivityResponseTypeUi.text,
  };
  DateTime? _deadline;
  bool _shareToPosts = false;
  String? _promptError;
  String? _typesError;
  bool _submitting = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  void _toggleType(ActivityResponseTypeUi type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
      _typesError = null;
    });
  }

  Future<void> _pickDeadline() async {
    final now = AttendancePolicy.dayStart(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'موعد اختياري (حتى الجلسة القادمة عادةً)',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked == null || !mounted) return;
    setState(() => _deadline = AttendancePolicy.dayStart(picked));
  }

  bool _validate() {
    var ok = true;
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      _promptError = 'اكتب نص المهمة أولاً';
      ok = false;
    } else {
      _promptError = null;
    }
    if (_selectedTypes.isEmpty) {
      _typesError = 'اختر نوع رد واحد على الأقل';
      ok = false;
    } else {
      _typesError = null;
    }
    setState(() {});
    return ok;
  }

  Future<void> _publish() async {
    if (_submitting) return;
    if (!_validate()) return;

    String teacherId = '';
    String teacherName = 'المعلم';
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        teacherId = auth.user.uid;
        if (auth.user.name.trim().isNotEmpty) {
          teacherName = auth.user.name.trim();
        }
      }
    } catch (_) {}
    if (teacherId.isEmpty) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لنشر المهمة');
      return;
    }

    setState(() => _submitting = true);
    final result = await sl<PublishHalaqaActivityUseCase>()(
      PublishHalaqaActivityParams(
        halaqaId: widget.halaqaId,
        teacherId: teacherId,
        teacherName: teacherName,
        prompt: _promptCtrl.text,
        allowedResponseTypes: _selectedTypes
            .map(HalaqaActivityUiMapper.toDomainType)
            .toSet(),
        deadline: _deadline,
        alsoShareAsPost: _shareToPosts,
      ),
    );
    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _submitting = false);
        AppSnackBar.showError(context, failure.message);
      },
      (_) async {
        final loaded = await sl<ListHalaqaActivitiesUseCase>()(
          HalaqaActivityHalaqaParams(widget.halaqaId),
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        final created = loaded.fold(
          (_) => null,
          (items) => items.isEmpty
              ? null
              : HalaqaActivityUiMapper.toUi(items.first),
        );
        AppSnackBar.showSuccess(
          context,
          _shareToPosts
              ? 'تم نشر المهمة للحلقة (مع إعلان في المنشورات إن أمكن)'
              : 'تم نشر المهمة للحلقة',
        );
        Navigator.of(context).pop(created);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.paddingM,
        12,
        AppSizes.paddingM,
        AppSizes.paddingM + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'مهمة جديدة',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تُرسل لكل طلاب الحلقة — نشاط خفيف وليست حفظ/مراجعة.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text('نص المهمة', style: AppTextStyles.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _promptCtrl,
              maxLines: 4,
              textAlign: TextAlign.right,
              onChanged: (_) {
                if (_promptError != null) {
                  setState(() => _promptError = null);
                }
              },
              decoration: InputDecoration(
                hintText: 'مثال: اكتب فقرة قصيرة عن معنى الصبر…',
                errorText: _promptError,
              ),
            ),
            const SizedBox(height: AppSizes.paddingM),
            Text('أنواع الرد المسموحة', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ActivityResponseTypeUi.values.map((type) {
                final selected = _selectedTypes.contains(type);
                final icon = switch (type) {
                  ActivityResponseTypeUi.text => Icons.notes_rounded,
                  ActivityResponseTypeUi.image => Icons.image_outlined,
                  ActivityResponseTypeUi.audio => Icons.mic_none_rounded,
                };
                return FilterChip(
                  selected: selected,
                  label: Text(type.labelAr),
                  avatar: Icon(icon, size: 16),
                  onSelected: (_) => _toggleType(type),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            if (_typesError != null) ...[
              const SizedBox(height: 6),
              Text(
                _typesError!,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.right,
              ),
            ],
            const SizedBox(height: AppSizes.paddingM),
            AppCard(
              onTap: _pickDeadline,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إزالة الموعد',
                    onPressed: _deadline == null
                        ? null
                        : () => setState(() => _deadline = null),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _deadline == null
                          ? AppColors.textHint
                          : AppColors.error,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'موعد اختياري',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _deadline == null
                            ? 'بدون موعد — أو حتى الجلسة القادمة'
                            : '${_deadline!.year}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.day.toString().padLeft(2, '0')}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.event_outlined,
                    color: AppColors.primary.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  value: _shareToPosts,
                  onChanged: (v) => setState(() => _shareToPosts = v),
                  title: Text(
                    'نشر في المنشورات',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'إعلان اختياري فقط — المنشورات ليست مصدر الحقيقة',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  activeThumbColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.paddingL),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _publish,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('نشر للحلقة'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

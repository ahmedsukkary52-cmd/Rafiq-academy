import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/halaqa_meeting_link.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/halaqa_meeting_link_builder.dart';
import '../../../../shared/widgets/meeting_link_dialog.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../../domain/usecases/admin_operations_usecases.dart';
import '../bloc/admin_operations_bloc.dart';
import '../widgets/admin_operation_widgets.dart';

/// P0-04 — Halaqa + weekly schedule creation through `adminCreateHalaqa`
/// (D8 ≥1 slot, D9 conflict engine, teacher lock) and `adminAddHalaqaSlot`.
class AdminHalaqatPage extends StatelessWidget {
  const AdminHalaqatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminOperationsScaffold(
      title: 'الحلقات والمواعيد',
      builder: (context, state) => _HalaqatBody(state: state),
    );
  }
}

class _HalaqatBody extends StatelessWidget {
  final AdminOperationsState state;
  const _HalaqatBody({required this.state});

  void _openCreate(BuildContext context) {
    final bloc = context.read<AdminOperationsBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: bloc, child: const _CreateHalaqaSheet()),
    );
  }

  Future<void> _openAddSlot(BuildContext context, HalaqaEntity halaqa) async {
    final slot = await showDialog<HalaqaSlotInput>(
      context: context,
      builder: (_) => const _SlotDialog(),
    );
    if (slot == null || !context.mounted) return;
    context.read<AdminOperationsBloc>().add(
      AddHalaqaSlotEvent(AddHalaqaSlotParams(halaqaId: halaqa.id, slot: slot)),
    );
  }

  Future<void> _openMeetingLink(
    BuildContext context,
    HalaqaEntity halaqa,
    MeetingLinkLoaded current,
  ) async {
    final result = await showMeetingLinkDialog(
      context,
      currentLink: current.joinableLink ?? '',
      canClear: true,
      storedLinkExists: current.link != null,
    );
    if (result == null || !context.mounted) return;
    context.read<AdminOperationsBloc>().add(
      SetHalaqaMeetingLinkEvent(
        result.clear
            ? SetHalaqaMeetingLinkParams.clear(halaqa.id)
            : SetHalaqaMeetingLinkParams(
                halaqaId: halaqa.id,
                meetingLink: result.link!,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (state.halaqat.isEmpty)
          const AppEmptyState(
            icon: Icons.groups_outlined,
            title: 'لا توجد حلقات بعد',
            message: 'أنشئ أول حلقة مع موعد أسبوعي واحد على الأقل',
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingM,
              AppSizes.paddingM,
              AppSizes.paddingM,
              96,
            ),
            itemCount: state.halaqat.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final h = state.halaqat[i];
              return AdminSectionCard(
                title: h.name.trim().isEmpty ? h.id : h.name.trim(),
                subtitle:
                    'المعلم: ${state.nameOf(h.teacherId)}'
                    '${h.supervisorId.isEmpty ? '' : ' · المشرف: ${state.nameOf(h.supervisorId)}'}'
                    ' · ${h.studentIds.length} طالب',
                children: [
                  if (h.schedule.isEmpty)
                    Text(
                      'لا توجد مواعيد',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.error,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in h.schedule)
                          Chip(
                            label: Text('${s.day} ${s.startTime}–${s.endTime}'),
                          ),
                      ],
                    ),
                  HalaqaMeetingLinkBuilder(
                    halaqaId: h.id,
                    reloadToken: state.halaqat,
                    builder: (context, view, reload) => _MeetingLinkRow(
                      view: view,
                      onRetry: reload,
                      onEdit: state.isSubmitting || view is! MeetingLinkLoaded
                          ? null
                          : () => _openMeetingLink(context, h, view),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => _openAddSlot(context, h),
                      icon: const Icon(Icons.add_alarm_rounded),
                      label: const Text('إضافة موعد'),
                    ),
                  ),
                ],
              );
            },
          ),
        PositionedDirectional(
          end: AppSizes.paddingM,
          bottom: AppSizes.paddingM,
          child: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إنشاء حلقة'),
          ),
        ),
      ],
    );
  }
}

class _MeetingLinkRow extends StatelessWidget {
  final MeetingLinkView view;
  final VoidCallback? onEdit;
  final VoidCallback onRetry;

  const _MeetingLinkRow({
    required this.view,
    required this.onEdit,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final view = this.view;
    final link = view is MeetingLinkLoaded ? view.joinableLink : null;
    final missing =
        view is MeetingLinkLoaded &&
        view.availability == MeetingLinkAvailability.missing;
    final status = switch (view) {
      MeetingLinkLoading() => 'رابط الاجتماع: جارٍ التحقق…',
      MeetingLinkDenied() => 'لا تملك صلاحية عرض رابط الاجتماع',
      MeetingLinkFailed() => 'تعذر تحميل رابط الاجتماع',
      MeetingLinkLoaded(:final availability) => switch (availability) {
        MeetingLinkAvailability.missing => 'رابط الاجتماع: لم يُضبط بعد',
        MeetingLinkAvailability.joinable => 'رابط الاجتماع:',
        MeetingLinkAvailability.invalid =>
          'رابط الاجتماع المحفوظ غير صالح — حدّثه',
      },
    };
    return Row(
      children: [
        Icon(
          Icons.videocam_outlined,
          size: 18,
          color: link != null ? AppColors.primary : AppColors.error,
        ),
        const SizedBox(width: 6),
        Text(status, style: AppTextStyles.labelSmall),
        if (link != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              link,
              textDirection: TextDirection.ltr,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall,
            ),
          ),
        ] else
          const Spacer(),
        if (view is MeetingLinkFailed)
          TextButton(
            key: const Key('adminMeetingLinkRetry'),
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          )
        else
          TextButton(
            onPressed: onEdit,
            child: Text(missing ? 'إضافة رابط' : 'تعديل الرابط'),
          ),
      ],
    );
  }
}

class _CreateHalaqaSheet extends StatefulWidget {
  const _CreateHalaqaSheet();

  @override
  State<_CreateHalaqaSheet> createState() => _CreateHalaqaSheetState();
}

class _CreateHalaqaSheetState extends State<_CreateHalaqaSheet> {
  final _name = TextEditingController();
  final _link = TextEditingController();
  final _requestId = newHalaqaRequestId();
  final List<HalaqaSlotInput> _slots = [];
  String? _teacherId;
  String? _supervisorId;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _addSlot() async {
    final slot = await showDialog<HalaqaSlotInput>(
      context: context,
      builder: (_) => const _SlotDialog(),
    );
    if (slot != null) setState(() => _slots.add(slot));
  }

  void _submit() {
    context.read<AdminOperationsBloc>().add(
      CreateHalaqaEvent(
        CreateHalaqaParams(
          name: _name.text,
          teacherId: _teacherId ?? '',
          supervisorId: _supervisorId,
          meetingLink: _link.text,
          schedule: List.of(_slots),
          requestId: _requestId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminOperationsBloc>().state;
    return BlocListener<AdminOperationsBloc, AdminOperationsState>(
      listenWhen: (p, c) =>
          p.submissionStatus == SubmissionStatus.submitting &&
          c.submissionStatus == SubmissionStatus.success,
      listener: (context, _) => Navigator.of(context).maybePop(),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              Text('إنشاء حلقة', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الحلقة'),
              ),
              const SizedBox(height: 12),
              AdminUserDropdown(
                label: 'المعلم',
                users: state.teachers,
                value: _teacherId,
                onChanged: (v) => setState(() => _teacherId = v),
              ),
              const SizedBox(height: 12),
              AdminUserDropdown(
                label: 'المشرف (اختياري)',
                users: state.supervisors,
                value: _supervisorId,
                onChanged: (v) => setState(() => _supervisorId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _link,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'رابط الاجتماع (اختياري)',
                  helperText: 'رابط https:// من تطبيق الاجتماع',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'المواعيد الأسبوعية (${_slots.length})',
                      style: AppTextStyles.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSlot,
                    icon: const Icon(Icons.add_alarm_rounded),
                    label: const Text('إضافة موعد'),
                  ),
                ],
              ),
              for (var i = 0; i < _slots.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_slots[i].day} ${_slots[i].startTime}–${_slots[i].endTime}',
                  ),
                  trailing: IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _slots.removeAt(i)),
                  ),
                ),
              if (_slots.isEmpty)
                Text(
                  'يجب إضافة موعد واحد على الأقل',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              const SizedBox(height: 16),
              AdminSubmitButton(label: 'إنشاء الحلقة', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog();

  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  String _day = kHalaqaDayLabels.first;
  final _start = TextEditingController(text: '16:00');
  final _end = TextEditingController(text: '17:00');
  String? _error;

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _confirm() {
    final slot = HalaqaSlotInput(
      day: _day,
      startTime: _start.text.trim(),
      endTime: _end.text.trim(),
    );
    final error = validateSlotInput(slot);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, slot);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('موعد أسبوعي'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _day,
            decoration: const InputDecoration(labelText: 'اليوم'),
            items: [
              for (final d in kHalaqaDayLabels)
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) => setState(() => _day = v ?? _day),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'من (HH:mm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _end,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'إلى (HH:mm)'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        AppButton(label: 'إضافة', width: 96, height: 40, onPressed: _confirm),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/domain/halaqa_meeting_link.dart';
import '../../../../shared/domain/halaqa_name_key.dart';
import '../../../../shared/domain/meeting_link_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/halaqa_meeting_link_builder.dart';
import '../../../../shared/widgets/meeting_link_dialog.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/domain/halaqa_entity.dart';
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
    // Prefer GoRouter query when under a RouteBase; widget tests / embeds
    // without a router still render the directory (create stays closed).
    var openCreate = false;
    try {
      openCreate =
          GoRouterState.of(context).uri.queryParameters['create'] == '1';
    } catch (_) {
      openCreate = false;
    }
    return AdminOperationsScaffold(
      title: 'الحلقات والمواعيد',
      builder: (context, state) =>
          _HalaqatBody(state: state, openCreateOnLoad: openCreate),
    );
  }
}

class _HalaqatBody extends StatefulWidget {
  final AdminOperationsState state;
  final bool openCreateOnLoad;
  const _HalaqatBody({required this.state, this.openCreateOnLoad = false});

  @override
  State<_HalaqatBody> createState() => _HalaqatBodyState();
}

class _HalaqatBodyState extends State<_HalaqatBody> {
  var _didAutoOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoOpen) return;
        _didAutoOpen = true;
        _openCreate(context);
      });
    }
  }

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
    final state = widget.state;
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
              final title =
                  h.name.trim().isEmpty ? 'حلقة بدون اسم' : h.name.trim();
              final teacher = state.nameOf(h.teacherId);
              final supervisor = h.supervisorId.isEmpty
                  ? null
                  : state.nameOf(h.supervisorId);
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSizes.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${h.studentIds.length} طالب',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.school_outlined,
                          label: 'المعلم: $teacher',
                        ),
                        if (supervisor != null)
                          _MetaChip(
                            icon: Icons.supervisor_account_outlined,
                            label: 'المشرف: $supervisor',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppColors.primaryLight,
                              side: BorderSide.none,
                              label: Text(
                                '${s.day} ${_displayClock(s.startTime)}–${_displayClock(s.endTime)}',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    HalaqaMeetingLinkBuilder(
                      halaqaId: h.id,
                      getMeetingLink: sl<GetHalaqaMeetingLinkUseCase>(),
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
                ),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

enum _StudentRosterFilter { all, inHalaqa, withoutHalaqa }

class _CreateHalaqaSheet extends StatefulWidget {
  const _CreateHalaqaSheet();

  @override
  State<_CreateHalaqaSheet> createState() => _CreateHalaqaSheetState();
}

class _CreateHalaqaSheetState extends State<_CreateHalaqaSheet> {
  final _name = TextEditingController();
  final _link = TextEditingController();
  final _studentSearch = TextEditingController();
  final _scrollController = ScrollController();
  final _requestId = newHalaqaRequestId();
  final List<HalaqaSlotInput> _slots = [];
  final Set<String> _selectedStudentIds = {};
  String? _teacherId;
  String? _supervisorId;
  String? _sheetError;
  bool _submitLocked = false;
  _StudentRosterFilter _studentFilter = _StudentRosterFilter.all;

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    _studentSearch.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addSlot() async {
    final slot = await showDialog<HalaqaSlotInput>(
      context: context,
      builder: (_) => const _SlotDialog(),
    );
    if (slot != null) setState(() => _slots.add(slot));
  }

  String? _duplicateError(AdminOperationsState state) {
    final clash = duplicateHalaqaName(
      _name.text,
      state.halaqat.map((h) => h.name),
    );
    return clash == null ? null : 'يوجد حلقة بنفس الاسم بالفعل ($clash)';
  }

  void _showSheetMessage(String message, {required bool error}) {
    if (!error) return;
    setState(() => _sheetError = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  bool get _canSubmit {
    final nameOk = _name.text.trim().isNotEmpty;
    final teacherOk = (_teacherId ?? '').trim().isNotEmpty;
    return nameOk && teacherOk && _slots.isNotEmpty;
  }

  void _submit() {
    if (_submitLocked ||
        context.read<AdminOperationsBloc>().state.isSubmitting) {
      return;
    }
    final state = context.read<AdminOperationsBloc>().state;
    final dup = _duplicateError(state);
    if (dup != null) {
      _showSheetMessage(dup, error: true);
      return;
    }
    if (_name.text.trim().isEmpty) {
      _showSheetMessage('أدخل اسم الحلقة', error: true);
      return;
    }
    if (_teacherId == null || _teacherId!.trim().isEmpty) {
      _showSheetMessage('اختر معلم الحلقة', error: true);
      return;
    }
    if (_slots.isEmpty) {
      _showSheetMessage('أضف موعداً أسبوعياً واحداً على الأقل', error: true);
      return;
    }
    final meetingLink = normalizeMeetingLinkInput(_link.text);
    if (meetingLink != _link.text) {
      _link.value = TextEditingValue(
        text: meetingLink,
        selection: TextSelection.collapsed(offset: meetingLink.length),
      );
    }
    final linkError =
        meetingLink.isEmpty ? null : meetingLinkErrorText(meetingLink);
    if (linkError != null) {
      _showSheetMessage(linkError, error: true);
      return;
    }
    setState(() {
      _submitLocked = true;
      _sheetError = null;
    });
    context.read<AdminOperationsBloc>().add(
      CreateHalaqaEvent(
        CreateHalaqaParams(
          name: _name.text,
          teacherId: _teacherId ?? '',
          supervisorId: _supervisorId,
          meetingLink: meetingLink.isEmpty ? null : meetingLink,
          schedule: List.of(_slots),
          requestId: _requestId,
        ),
        admitStudentIds: _selectedStudentIds.toList(),
      ),
    );
  }

  List<AdminDirectoryUser> _filteredStudents(AdminOperationsState state) {
    final q = _studentSearch.text.trim().toLowerCase();
    return state.students.where((s) {
      final inHalaqa = state.halaqatOf(s.uid).isNotEmpty;
      final passFilter = switch (_studentFilter) {
        _StudentRosterFilter.all => true,
        _StudentRosterFilter.inHalaqa => inHalaqa,
        _StudentRosterFilter.withoutHalaqa => !inHalaqa,
      };
      if (!passFilter) return false;
      if (q.isEmpty) return true;
      return s.displayName.toLowerCase().contains(q) ||
          s.uid.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminOperationsBloc>().state;
    final students = _filteredStudents(state);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    final submitting = state.isSubmitting || _submitLocked;

    return BlocListener<AdminOperationsBloc, AdminOperationsState>(
      listenWhen: (p, c) =>
          p.submissionStatus != c.submissionStatus &&
          (c.submissionStatus == SubmissionStatus.success ||
              c.submissionStatus == SubmissionStatus.error),
      listener: (context, s) {
        if (s.submissionStatus == SubmissionStatus.success) {
          Navigator.of(context).maybePop();
          return;
        }
        setState(() => _submitLocked = false);
        final message = s.message;
        if (message != null && message.isNotEmpty) {
          _showSheetMessage(message, error: true);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingM,
                    AppSizes.paddingM,
                    AppSizes.paddingM,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'إنشاء حلقة',
                          style: AppTextStyles.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                if (_sheetError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      AppSizes.paddingS,
                      AppSizes.paddingM,
                      0,
                    ),
                    child: Material(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _sheetError!,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    children: [
                      TextField(
                        key: const Key('halaqa-name-field'),
                        controller: _name,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'اسم الحلقة',
                          errorText: _duplicateError(state),
                        ),
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
                        enableSuggestions: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        inputFormatters: const [MeetingLinkInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'رابط Zoom أو Google Meet (اختياري)',
                          helperText:
                              'الصق الرابط كما هو — مثال: https://meet.google.com/xxx-xxxx-xxx',
                          helperMaxLines: 2,
                        ),
                        onEditingComplete: () {
                          final n = normalizeMeetingLinkInput(_link.text);
                          if (n != _link.text) _link.value = TextEditingValue(
                            text: n,
                            selection: TextSelection.collapsed(offset: n.length),
                          );
                        },
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
                            '${_slots[i].day} ${_displayClock(_slots[i].startTime)}–${_displayClock(_slots[i].endTime)}',
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
                      const SizedBox(height: 20),
                      Text(
                        'إضافة طلاب (اختياري)',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اختر من القائمة — يمكن البحث والفلترة',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _studentSearch,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'ابحث باسم الطالب…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _studentSearch.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _studentSearch.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: AppColors.surfaceGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusM,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final f in _StudentRosterFilter.values)
                            FilterChip(
                              selected: _studentFilter == f,
                              label: Text(switch (f) {
                                _StudentRosterFilter.all => 'الكل',
                                _StudentRosterFilter.inHalaqa => 'في حلقة',
                                _StudentRosterFilter.withoutHalaqa =>
                                  'بدون حلقة',
                              }),
                              onSelected: (_) =>
                                  setState(() => _studentFilter = f),
                            ),
                        ],
                      ),
                      if (_selectedStudentIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'محدد: ${_selectedStudentIds.length}',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: students.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'لا يوجد طلاب مطابقون',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.textHint,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: students.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                                itemBuilder: (context, i) {
                                  final s = students[i];
                                  final selected = _selectedStudentIds.contains(
                                    s.uid,
                                  );
                                  final inHalaqa = state
                                      .halaqatOf(s.uid)
                                      .isNotEmpty;
                                  return CheckboxListTile(
                                    dense: true,
                                    value: selected,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      s.displayName,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      inHalaqa
                                          ? 'مسجّل في حلقة'
                                          : 'بدون حلقة حالياً',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: inHalaqa
                                            ? AppColors.textSecondary
                                            : AppColors.warning,
                                      ),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedStudentIds.add(s.uid);
                                        } else {
                                          _selectedStudentIds.remove(s.uid);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      if (!_canSubmit) ...[
                        Text(
                          'أكمل الاسم والمعلم وموعداً أسبوعياً واحداً على الأقل',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingM,
                    8,
                    AppSizes.paddingM,
                    AppSizes.paddingM,
                  ),
                  child: AdminSubmitButton(
                    label: submitting ? 'جاري الإنشاء…' : 'إنشاء الحلقة',
                    onPressed: (!_canSubmit || submitting) ? null : _submit,
                  ),
                ),
              ],
            ),
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
  TimeOfDay _start = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  String? _error;

  String _wire(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _label12(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'ص' : 'م';
    return '$hour:$minute $period';
  }

  Future<void> _pick(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      helpText: start ? 'وقت البداية' : 'وقت النهاية',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(alwaysUse24HourFormat: false),
          child: Localizations.override(
            context: context,
            locale: const Locale('ar'),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  void _confirm() {
    final slot = HalaqaSlotInput(
      day: _day,
      startTime: _wire(_start),
      endTime: _wire(_end),
    );
    final error = validateSlotInput(slot);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, slot);
  }

  Widget _timeField({
    required String caption,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            caption,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
              ),
            ),
            child: Text(
              _label12(time),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
          Text(
            'اختر الساعة بنظام 12 — تُحفظ للطالب والولي والمشرف والمعلم',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _timeField(
                caption: 'من',
                time: _start,
                onTap: () => _pick(true),
              ),
              const SizedBox(width: 12),
              _timeField(
                caption: 'إلى',
                time: _end,
                onTap: () => _pick(false),
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

String _displayClock(String hhmm) {
  final parts = hhmm.trim().split(':');
  if (parts.length < 2) return hhmm;
  final hour = int.tryParse(parts[0]);
  final minute = parts[1];
  if (hour == null) return hhmm;
  final period = hour < 12 ? 'ص' : 'م';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute $period';
}

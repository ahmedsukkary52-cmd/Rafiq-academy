import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/achievement_issue_entity.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_absence_requests_section.dart';
import '../widgets/supervisor_day_board_section.dart';

enum _ActiveDialog { none, achievement, registerStudent }

/// Supervisor home — halaqat list, detail, and write actions (Sprints 1–5).
///
/// H6 / A-H16: “رفع تقرير” UI removed (write-only ops path; no in-app reader).
class SupervisorHomePage extends StatefulWidget {
  const SupervisorHomePage({super.key});

  @override
  State<SupervisorHomePage> createState() => _SupervisorHomePageState();
}

class _SupervisorHomePageState extends State<SupervisorHomePage> {
  String? _selectedHalaqaId;
  final _detailKey = GlobalKey();
  _ActiveDialog _activeDialog = _ActiveDialog.none;

  static const _achievementTypes = ['star', 'badge', 'certificate'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHalaqat());
  }

  void _loadHalaqat() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    context.read<SupervisorBloc>().add(
      LoadSupervisedHalaqatEvent(authState.user.uid),
    );
  }

  void _selectHalaqa(String halaqaId) {
    setState(() => _selectedHalaqaId = halaqaId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _detailKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  static String _orUnavailable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'غير متوفر' : trimmed;
  }

  void _closeActiveDialog() {
    if (_activeDialog == _ActiveDialog.none) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    _activeDialog = _ActiveDialog.none;
  }

  Future<void> _openIssueAchievementDialog(HalaqaEntity halaqa) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    _activeDialog = _ActiveDialog.achievement;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _IssueAchievementDialog(
        studentIds: halaqa.studentIds,
        halaqaId: halaqa.id,
        issuedBy: authState.user.uid,
        achievementTypes: _achievementTypes,
        onSubmit: (data) {
          context.read<SupervisorBloc>().add(IssueAchievementEvent(data));
        },
      ),
    );
    if (mounted) _activeDialog = _ActiveDialog.none;
  }

  Future<void> _openRegisterStudentDialog(HalaqaEntity halaqa) async {
    _activeDialog = _ActiveDialog.registerStudent;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RegisterStudentDialog(
        halaqaId: halaqa.id,
        onSubmit: (studentId) {
          context.read<SupervisorBloc>().add(
            RegisterNewStudentEvent(halaqaId: halaqa.id, studentId: studentId),
          );
        },
      ),
    );
    if (mounted) _activeDialog = _ActiveDialog.none;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final supervisorName = authState is AuthAuthenticated
        ? authState.user.name
        : '';

    return MultiBlocListener(
      listeners: [
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (prev, curr) =>
              prev.issueAchievementStatus != curr.issueAchievementStatus ||
              prev.issueAchievementError != curr.issueAchievementError,
          listener: (context, state) {
            if (state.issueAchievementStatus == SubmissionStatus.success) {
              if (_activeDialog == _ActiveDialog.achievement) {
                _closeActiveDialog();
              }
              AppSnackBar.showSuccess(context, 'تم منح الإنجاز بنجاح');
              context.read<SupervisorBloc>().add(
                const ResetIssueAchievementEvent(),
              );
            } else if (state.issueAchievementStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.issueAchievementError ?? 'تعذر منح الإنجاز',
              );
            }
          },
        ),
        BlocListener<SupervisorBloc, SupervisorState>(
          listenWhen: (prev, curr) =>
              prev.registerStudentStatus != curr.registerStudentStatus ||
              prev.registerStudentError != curr.registerStudentError,
          listener: (context, state) {
            if (state.registerStudentStatus == SubmissionStatus.success) {
              if (_activeDialog == _ActiveDialog.registerStudent) {
                _closeActiveDialog();
              }
              AppSnackBar.showSuccess(context, 'تم ربط الطالب بالحلقة بنجاح');
              context.read<SupervisorBloc>().add(
                const ResetRegisterStudentEvent(),
              );
              _loadHalaqat();
            } else if (state.registerStudentStatus == SubmissionStatus.error) {
              AppSnackBar.showError(
                context,
                state.registerStudentError ?? 'تعذر تسجيل الطالب',
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('نافذة المشرف')),
        body: BlocBuilder<SupervisorBloc, SupervisorState>(
          buildWhen: (prev, curr) =>
              prev.halaqatStatus != curr.halaqatStatus ||
              prev.halaqat != curr.halaqat ||
              prev.halaqatError != curr.halaqatError,
          builder: (context, state) {
            if (state.halaqatStatus == SectionStatus.initial ||
                state.halaqatStatus == SectionStatus.loading) {
              return const AppLoadingWidget();
            }

            if (state.halaqatStatus == SectionStatus.error) {
              return AppErrorWidget(
                message: state.halaqatError ?? 'حدث خطأ',
                onRetry: _loadHalaqat,
              );
            }

            if (state.halaqat.isEmpty) {
              return const _EmptyHalaqat();
            }

            HalaqaEntity? selected;
            if (_selectedHalaqaId != null) {
              for (final h in state.halaqat) {
                if (h.id == _selectedHalaqaId) {
                  selected = h;
                  break;
                }
              }
            }

            return ListView(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              children: [
                Text(
                  supervisorName.isEmpty ? 'المشرف' : supervisorName,
                  style: AppTextStyles.headlineLarge,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'الحلقات تحت الإشراف: ${state.halaqat.length}',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: AppSizes.paddingM),
                BlocBuilder<SupervisorBloc, SupervisorState>(
                  buildWhen: (prev, curr) =>
                      prev.dayBoardStatus != curr.dayBoardStatus ||
                      prev.dayBoard != curr.dayBoard ||
                      prev.dayBoardError != curr.dayBoardError,
                  builder: (context, boardState) {
                    return SupervisorDayBoardSection(
                      status: boardState.dayBoardStatus,
                      board: boardState.dayBoard,
                      error: boardState.dayBoardError,
                      onRetry: () => context.read<SupervisorBloc>().add(
                        const LoadSupervisorDayBoardEvent(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSizes.paddingL),
                BlocBuilder<SupervisorBloc, SupervisorState>(
                  buildWhen: (prev, curr) =>
                      prev.absenceRequestsStatus !=
                          curr.absenceRequestsStatus ||
                      prev.absenceRequests != curr.absenceRequests ||
                      prev.absenceRequestsError != curr.absenceRequestsError ||
                      prev.halaqat != curr.halaqat,
                  builder: (context, reqState) {
                    final auth = context.read<AuthBloc>().state;
                    final supervisorId = auth is AuthAuthenticated
                        ? auth.user.uid
                        : null;
                    return SupervisorAbsenceRequestsSection(
                      status: reqState.absenceRequestsStatus,
                      requests: reqState.absenceRequests,
                      error: reqState.absenceRequestsError,
                      onRetry: () {
                        if (supervisorId == null) return;
                        context.read<SupervisorBloc>().add(
                          LoadSupervisedAbsenceRequestsEvent(
                            supervisorId: supervisorId,
                            date: DateTime.now(),
                          ),
                        );
                      },
                      halaqaName: (id) {
                        for (final h in reqState.halaqat) {
                          if (h.id == id) {
                            final name = h.name.trim();
                            return name.isEmpty ? id : name;
                          }
                        }
                        return id;
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSizes.paddingL),
                Text(
                  'الحلقات والأدوات',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'إنجازات وتقارير وربط طلاب — ثانوية عن متابعة اليوم',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: AppSizes.paddingM),
                ...state.halaqat.map(
                  (halaqa) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HalaqaCard(
                      halaqa: halaqa,
                      isSelected: halaqa.id == _selectedHalaqaId,
                      onTap: () => _selectHalaqa(halaqa.id),
                    ),
                  ),
                ),
                if (_selectedHalaqaId != null) ...[
                  const SizedBox(height: AppSizes.paddingM),
                  KeyedSubtree(
                    key: _detailKey,
                    child: selected == null
                        ? const _DetailUnavailable(
                            message: 'الحلقة المحددة غير متوفرة',
                          )
                        : _HalaqaDetailSection(
                            halaqa: selected,
                            onIssueAchievement: () =>
                                _openIssueAchievementDialog(selected!),
                            onRegisterStudent: () =>
                                _openRegisterStudentDialog(selected!),
                            formatValue: _orUnavailable,
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IssueAchievementDialog extends StatefulWidget {
  final List<String> studentIds;
  final String halaqaId;
  final String issuedBy;
  final List<String> achievementTypes;
  final ValueChanged<AchievementIssueEntity> onSubmit;

  const _IssueAchievementDialog({
    required this.studentIds,
    required this.halaqaId,
    required this.issuedBy,
    required this.achievementTypes,
    required this.onSubmit,
  });

  @override
  State<_IssueAchievementDialog> createState() =>
      _IssueAchievementDialogState();
}

class _IssueAchievementDialogState extends State<_IssueAchievementDialog> {
  final _titleCtrl = TextEditingController();
  final _manualStudentCtrl = TextEditingController();
  String? _studentId;
  late String _type;

  @override
  void initState() {
    super.initState();
    _type = widget.achievementTypes.first;
    if (widget.studentIds.length == 1) {
      _studentId = widget.studentIds.first;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _manualStudentCtrl.dispose();
    super.dispose();
  }

  String? get _resolvedStudentId {
    if (widget.studentIds.isNotEmpty) return _studentId;
    final manual = _manualStudentCtrl.text.trim();
    return manual.isEmpty ? null : manual;
  }

  void _submit() {
    final studentId = _resolvedStudentId;
    final title = _titleCtrl.text.trim();
    if (studentId == null || title.isEmpty) return;

    widget.onSubmit(
      AchievementIssueEntity(
        studentId: studentId,
        type: _type,
        title: title,
        issuedBy: widget.issuedBy,
        halaqaId: widget.halaqaId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupervisorBloc, SupervisorState>(
      buildWhen: (prev, curr) =>
          prev.issueAchievementStatus != curr.issueAchievementStatus,
      builder: (context, state) {
        final submitting =
            state.issueAchievementStatus == SubmissionStatus.submitting;
        final canSubmit =
            _resolvedStudentId != null && _titleCtrl.text.trim().isNotEmpty;

        return AlertDialog(
          title: Text(
            'منح إنجاز',
            textAlign: TextAlign.right,
            style: AppTextStyles.headlineMedium,
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('الطالب', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  if (widget.studentIds.isEmpty) ...[
                    Text(
                      'لا يوجد طلاب في هذه الحلقة — أدخل معرّف الطالب يدوياً',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      hint: 'معرّف الطالب',
                      controller: _manualStudentCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              _studentId != null &&
                                  widget.studentIds.contains(_studentId)
                              ? _studentId
                              : null,
                          isExpanded: true,
                          hint: Text(
                            'اختر الطالب',
                            style: AppTextStyles.bodyMedium,
                          ),
                          items: widget.studentIds
                              .map(
                                (id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    id,
                                    style: AppTextStyles.bodyMedium,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: submitting
                              ? null
                              : (value) => setState(() => _studentId = value),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('النوع', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _type,
                        isExpanded: true,
                        items: widget.achievementTypes
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  _typeLabel(t),
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _type = value);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('العنوان', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  AppTextField(
                    hint: 'مثال: ختم جزء عمّ',
                    controller: _titleCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (submitting) ...[
                    const SizedBox(height: 16),
                    const Center(child: AppLoadingWidget()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      context.read<SupervisorBloc>().add(
                        const ResetIssueAchievementEvent(),
                      );
                      Navigator.of(context).pop();
                    },
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'منح',
              width: 100,
              height: 40,
              onPressed: submitting || !canSubmit ? null : _submit,
            ),
          ],
        );
      },
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'star' => 'نجمة',
    'badge' => 'شارة',
    'certificate' => 'شهادة',
    _ => type,
  };
}

class _RegisterStudentDialog extends StatefulWidget {
  final String halaqaId;
  final ValueChanged<String> onSubmit;

  const _RegisterStudentDialog({
    required this.halaqaId,
    required this.onSubmit,
  });

  @override
  State<_RegisterStudentDialog> createState() => _RegisterStudentDialogState();
}

class _RegisterStudentDialogState extends State<_RegisterStudentDialog> {
  final _studentIdCtrl = TextEditingController();

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final studentId = _studentIdCtrl.text.trim();
    if (studentId.isEmpty) return;
    widget.onSubmit(studentId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupervisorBloc, SupervisorState>(
      buildWhen: (prev, curr) =>
          prev.registerStudentStatus != curr.registerStudentStatus,
      builder: (context, state) {
        final submitting =
            state.registerStudentStatus == SubmissionStatus.submitting;
        final canSubmit = _studentIdCtrl.text.trim().isNotEmpty;

        return AlertDialog(
          title: Text(
            'تسجيل طالب',
            textAlign: TextAlign.right,
            style: AppTextStyles.headlineMedium,
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'يربط طالبًا موجودًا مسبقًا بالحلقة المحددة. لا ينشئ حسابًا جديدًا.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textHint,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الحلقة: ${widget.halaqaId}',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 16),
                  Text('معرّف الطالب', style: AppTextStyles.labelLarge),
                  const SizedBox(height: 6),
                  AppTextField(
                    hint: 'أدخل studentId الموجود',
                    controller: _studentIdCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (submitting) ...[
                    const SizedBox(height: 16),
                    const Center(child: AppLoadingWidget()),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      context.read<SupervisorBloc>().add(
                        const ResetRegisterStudentEvent(),
                      );
                      Navigator.of(context).pop();
                    },
              child: const Text('إلغاء'),
            ),
            AppButton(
              label: 'ربط',
              width: 100,
              height: 40,
              onPressed: submitting || !canSubmit ? null : _submit,
            ),
          ],
        );
      },
    );
  }
}

class _HalaqaCard extends StatelessWidget {
  final HalaqaEntity halaqa;
  final bool isSelected;
  final VoidCallback onTap;

  const _HalaqaCard({
    required this.halaqa,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = halaqa.schedule;
    final scheduleLabel = schedule.isEmpty
        ? 'غير متوفر'
        : schedule
              .map((s) => '${s.day} ${s.startTime}–${s.endTime}')
              .join(' · ');
    final statusLabel = halaqa.status.trim().isEmpty
        ? 'غير متوفر'
        : halaqa.status.trim();

    return AppCard(
      onTap: onTap,
      color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: isSelected ? AppColors.primary : AppColors.textHint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  halaqa.name.trim().isEmpty ? 'غير متوفر' : halaqa.name.trim(),
                  style: AppTextStyles.titleLarge,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  'الحالة: $statusLabel',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textHint,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 2),
                Text(
                  scheduleLabel,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 2),
                Text(
                  'الطلاب: ${halaqa.studentIds.length}',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(Icons.groups_outlined, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _HalaqaDetailSection extends StatelessWidget {
  final HalaqaEntity halaqa;
  final VoidCallback onIssueAchievement;
  final VoidCallback onRegisterStudent;
  final String Function(String) formatValue;

  const _HalaqaDetailSection({
    required this.halaqa,
    required this.onIssueAchievement,
    required this.onRegisterStudent,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = halaqa.schedule;
    final scheduleLabel = schedule.isEmpty
        ? 'غير متوفر'
        : schedule
              .map((s) => '${s.day} ${s.startTime}–${s.endTime}')
              .join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تفاصيل الحلقة',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(label: 'الاسم', value: formatValue(halaqa.name)),
              _DetailRow(label: 'الحالة', value: formatValue(halaqa.status)),
              _DetailRow(label: 'الجدول', value: scheduleLabel),
              _DetailRow(
                label: 'رابط اللقاء',
                value: formatValue(halaqa.meetingLink),
              ),
              _DetailRow(
                label: 'معرّف المعلم',
                value: formatValue(halaqa.teacherId),
              ),
              _DetailRow(
                label: 'معرّف المشرف',
                value: formatValue(halaqa.supervisorId),
              ),
              _DetailRow(
                label: 'عدد الطلاب',
                value: '${halaqa.studentIds.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.paddingM),
        Text(
          'إجراءات',
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 8),
        _ActionRow(
          label: 'منح إنجاز',
          trailing: 'فتح',
          onTap: onIssueAchievement,
        ),
        const SizedBox(height: 8),
        _ActionRow(
          label: 'تسجيل طالب',
          trailing: 'فتح',
          onTap: onRegisterStudent,
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final String trailing;
  final VoidCallback onTap;

  const _ActionRow({
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            trailing,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          ),
          const Spacer(),
          Text(label, style: AppTextStyles.titleMedium),
        ],
      ),
    );
  }
}

class _DetailUnavailable extends StatelessWidget {
  final String message;

  const _DetailUnavailable({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        message,
        style: AppTextStyles.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyHalaqat extends StatelessWidget {
  const _EmptyHalaqat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_rounded,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد حلقات مسندة إليك',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'عند إسناد حلقات لحسابك من قِبل الأكاديمية ستظهر هنا.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

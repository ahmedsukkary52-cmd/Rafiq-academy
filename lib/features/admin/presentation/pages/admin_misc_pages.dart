import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../awards/data/award_grant_errors.dart';
import '../../../awards/domain/award_submission_id.dart';
import '../../../awards/domain/unresolved_award_store.dart';
import '../../../awards/presentation/widgets/unresolved_award_panel.dart';
import '../../data/admin_grant_reward_payload_codec.dart';
import '../../data/admin_rewards_history_repository.dart';
import '../../domain/admin_grant_reward_params.dart';
import '../../domain/admin_rewards_view.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../../../../shared/widgets/app_filter_chip.dart';
export 'admin_reports_page.dart' show AdminReportsPage;

/// Shared scaffold for admin sub-pages with optional header stats.
class AdminFeatureShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> sections;

  const AdminFeatureShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: title,
      subtitle: subtitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: sections,
      ),
    );
  }
}

const _recipientsUnavailableMessage =
    'تعذر تحديد مستلمي الجائزة من قائمة الحلقات. يجري تحديث القائمة؛ '
    'أعد المحاولة بعد قليل.';

const _chooseStudentHalaqaMessage =
    'الطالب مسجل في أكثر من حلقة. اختر الحلقة التي تُمنح فيها الجائزة.';

class AdminRewardsPage extends StatefulWidget {
  final Future<List<AdminRewardHistoryEntry>> Function()? historyLoader;

  const AdminRewardsPage({super.key, this.historyLoader});

  @override
  State<AdminRewardsPage> createState() => _AdminRewardsPageState();
}

class _AdminRewardsPageState extends State<AdminRewardsPage> {
  AdminRewardTargetKind _target = AdminRewardTargetKind.student;
  String _rewardType = 'star';
  String? _selectedTargetId;
  String? _selectedStudentHalaqaId;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _studentSearchCtrl = TextEditingController();
  String _studentQuery = '';
  List<AdminRewardHistoryEntry> _history = const [];
  bool _historyLoading = true;
  String? _historyError;
  late final AwardSubmissionId<AdminGrantRewardParams> _submissionId;

  Future<void> _fetchHistory() async {
    try {
      final loader =
          widget.historyLoader ?? AdminRewardsHistoryRepository().recent;
      final entries = await loader();
      if (!mounted) return;
      setState(() {
        _history = entries;
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e is String ? e : 'تعذر تحميل سجل الجوائز';
        _historyLoading = false;
      });
    }
  }

  void _reloadHistory() {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    _fetchHistory();
  }

  List<RewardStudentOption> _visibleStudents(AdminState state) {
    final all = rewardStudentOptions(state.studentRoster);
    final filtered = filterRewardStudents(all, _studentQuery);
    final selected = _selectedTargetId;
    if (selected == null || filtered.any((o) => o.uid == selected)) {
      return filtered;
    }
    return [...all.where((o) => o.uid == selected), ...filtered];
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
    final auth = context.read<AuthBloc>().state;
    final grantor = auth is AuthAuthenticated ? auth.user.uid : '';
    _submissionId = AwardSubmissionId.durable(
      scope: AwardOperationScope(
        operation: AwardOperationScope.grantAward,
        form: 'admin',
        uid: grantor,
      ),
      store: sl<UnresolvedAwardStore>(),
      codec: const AdminGrantRewardPayloadCodec(),
    );
    _submissionId.restore().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AdminBloc>();
      bloc.add(const LoadAdminDirectoryEvent());
      if (bloc.state.rosterStatus != SectionStatus.loaded) {
        bloc.add(const LoadStudentRosterEvent());
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _studentSearchCtrl.dispose();
    super.dispose();
  }

  List<({String id, String label})> _halaqaOptions(AdminState state) => state
      .halaqatDirectory
      .map((h) => (id: h.id, label: h.name))
      .toList();

  /// The selected student's halaqat; a choice is required when there are
  /// several.
  List<({String id, String label})> _studentHalaqaOptions(AdminState state) {
    final studentId = _selectedTargetId;
    if (_target != AdminRewardTargetKind.student || studentId == null) {
      return const [];
    }
    return [
      for (final h in halaqatOfStudent(state.studentRoster, studentId))
        (id: h.id, label: h.name),
    ];
  }

  Future<void> _grant(BuildContext context, String actorId) async {
    final title = _titleCtrl.text.trim();
    final targetId = _selectedTargetId?.trim() ?? '';
    if (title.isEmpty || targetId.isEmpty) {
      AppSnackBar.showError(context, 'أكمل الحقول المطلوبة');
      return;
    }
    final description = _descCtrl.text.trim();
    final target = _target;
    final rewardType = _rewardType;
    final bloc = context.read<AdminBloc>();
    final studentHalaqaId = _selectedStudentHalaqaId;
    if (bloc.state.rosterStatus == SectionStatus.loaded &&
        studentHalaqaId == null &&
        _studentHalaqaOptions(bloc.state).length > 1) {
      AppSnackBar.showError(context, _chooseStudentHalaqaMessage);
      return;
    }
    final resolved = bloc.state.rosterStatus == SectionStatus.loaded
        ? resolveAdminRewardRecipients(
            roster: bloc.state.studentRoster,
            kind: target,
            targetId: targetId,
            studentHalaqaId: target == AdminRewardTargetKind.student
                ? studentHalaqaId
                : null,
          )
        : null;
    if (resolved == null) {
      AppSnackBar.showError(context, _recipientsUnavailableMessage);
      bloc.add(const LoadStudentRosterEvent());
      return;
    }
    final preparing = _submissionId.prepare(
      [
        target,
        targetId,
        rewardType,
        title,
        description,
        resolved.halaqaId,
        '|',
        ...resolved.recipientStudentIds,
      ],
      (awardId) => AdminGrantRewardParams(
        awardId: awardId,
        targetKind: target,
        targetId: targetId,
        type: rewardType,
        title: title,
        description: description.isEmpty ? null : description,
        grantedBy: actorId,
        halaqaId: resolved.halaqaId,
        halaqaName: resolved.halaqaName,
        studentName: resolved.studentName,
        recipientStudentIds: resolved.recipientStudentIds,
      ),
    );
    setState(() {});
    final prepared = await preparing;
    final params = prepared.payload;
    if (params != null) bloc.add(GrantAdminRewardEvent(params: params));
    if (!mounted) return;
    setState(() {});
    if (prepared.status == AwardPrepareStatus.localSaveFailed) {
      AppSnackBar.showError(this.context, kAwardLocalSaveFailedMessage);
    }
  }

  Future<void> _abandonUnresolved() async {
    await _submissionId.abandon();
    if (!mounted) return;
    setState(() {});
    context.read<AdminBloc>().add(const LoadStudentRosterEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminBloc, AdminState>(
      listenWhen: (p, c) => p.grantRewardStatus != c.grantRewardStatus,
      listener: (context, state) {
        if (state.grantRewardStatus == SubmissionStatus.success) {
          _submissionId.complete();
          AppSnackBar.showSuccess(context, 'تم منح الجائزة');
          context.read<AdminBloc>()
            ..add(const ResetGrantRewardEvent())
            ..add(const LoadStudentRosterEvent());
          _titleCtrl.clear();
          _descCtrl.clear();
          _reloadHistory();
        } else if (state.grantRewardStatus == SubmissionStatus.error) {
          final message = state.grantRewardError ?? 'تعذر المنح';
          if (isAwardGrantUnconfirmed(message)) {
            _submissionId.markUnresolved();
            setState(() {});
            FocusScope.of(context).unfocus();
          } else {
            _submissionId.confirmedFailure();
          }
          AppSnackBar.showError(context, message);
          context.read<AdminBloc>().add(const ResetGrantRewardEvent());
        }
      },
      builder: (context, state) {
        final pinned = _submissionId.unresolved?.payload;
        final problem = _submissionId.recoveryProblem;
        final locked = _submissionId.blocksNewSubmission;
        final submitting =
            state.grantRewardStatus == SubmissionStatus.submitting;
        return AdminFeatureShell(
          title: 'مركز التحفيز والمكافآت',
          subtitle: 'منح لطالب أو حلقة',
          sections: [
            if (pinned != null || problem != null) ...[
              UnresolvedAwardPanel(
                summary: pinned?.title ?? kAwardRecordUnreadableSummary,
                blockedReason: awardRecoveryNotice(problem),
                enabled: !submitting,
                onAbandon: _abandonUnresolved,
              ),
              const SizedBox(height: 12),
            ],
            IgnorePointer(
              ignoring: locked,
              child: Opacity(
                opacity: locked ? 0.5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<AdminRewardTargetKind>(
                      segments: const [
                        ButtonSegment(
                          value: AdminRewardTargetKind.student,
                          label: Text('طالب'),
                        ),
                        ButtonSegment(
                          value: AdminRewardTargetKind.halaqa,
                          label: Text('حلقة'),
                        ),
                      ],
                      selected: {_target},
                      onSelectionChanged: (s) => setState(() {
                        _target = s.first;
                        _selectedTargetId = null;
                        _selectedStudentHalaqaId = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    AdminSectionHeader(title: 'نوع الجائزة'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          [
                            ('star', 'نجمة'),
                            ('badge', 'شارة'),
                            ('certificate', 'شهادة'),
                          ].map((entry) {
                            return AppFilterChip(
                              label: entry.$2,
                              selected: _rewardType == entry.$1,
                              onTap: () =>
                                  setState(() => _rewardType = entry.$1),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 12),
                    if (_target == AdminRewardTargetKind.student) ...[
                      TextField(
                        key: const Key('reward-student-search'),
                        controller: _studentSearchCtrl,
                        onChanged: (v) => setState(() => _studentQuery = v),
                        decoration: InputDecoration(
                          labelText: 'ابحث عن طالب بالاسم',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                          ),
                        ),
                      ),
                      if (_studentQuery.trim().isNotEmpty &&
                          filterRewardStudents(
                            rewardStudentOptions(state.studentRoster),
                            _studentQuery,
                          ).isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'لا يوجد طالب بهذا الاسم',
                            key: const Key('reward-student-no-match'),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: _selectedTargetId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _target == AdminRewardTargetKind.student
                            ? 'اختر الطالب'
                            : 'اختر الحلقة',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                      ),
                      items: _target == AdminRewardTargetKind.student
                          ? [
                              for (final o in _visibleStudents(state))
                                DropdownMenuItem(
                                  value: o.uid,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(o.displayName),
                                      Text(
                                        o.halaqaContext,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: AppColors.textHint,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                            ]
                          : [
                              for (final o in _halaqaOptions(state))
                                DropdownMenuItem(
                                  value: o.id,
                                  child: Text(o.label),
                                ),
                            ],
                      selectedItemBuilder:
                          _target == AdminRewardTargetKind.student
                          ? (context) => [
                              for (final o in _visibleStudents(state))
                                Text(
                                  o.displayName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ]
                          : null,
                      onChanged: (v) => setState(() {
                        _selectedTargetId = v;
                        _selectedStudentHalaqaId = null;
                      }),
                    ),
                    if (_studentHalaqaOptions(state) case final halaqat
                        when halaqat.length > 1) ...[
                      const SizedBox(height: 12),
                      KeyedSubtree(
                        key: ValueKey(_selectedTargetId),
                        child: DropdownButtonFormField<String>(
                          key: const Key('admin-reward-student-halaqa'),
                          initialValue:
                              halaqat.any(
                                (h) => h.id == _selectedStudentHalaqaId,
                              )
                              ? _selectedStudentHalaqaId
                              : null,
                          decoration: InputDecoration(
                            labelText:
                                'الطالب مسجل في أكثر من حلقة: اختر الحلقة',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusL,
                              ),
                            ),
                          ),
                          items: [
                            for (final h in halaqat)
                              DropdownMenuItem(
                                value: h.id,
                                child: Text(h.label),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedStudentHalaqaId = v),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'عنوان الجائزة',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'السبب (اختياري)',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pinned == null && !locked && _selectedTargetId != null) ...[
              const SizedBox(height: 16),
              _RewardPreview(
                typeLabel: adminRewardFormTypeLabel(_rewardType),
                title: _titleCtrl.text.trim(),
                reason: _descCtrl.text.trim(),
                recipients: state.rosterStatus == SectionStatus.loaded
                    ? resolveAdminRewardRecipients(
                        roster: state.studentRoster,
                        kind: _target,
                        targetId: _selectedTargetId!,
                        studentHalaqaId:
                            _target == AdminRewardTargetKind.student
                            ? _selectedStudentHalaqaId
                            : null,
                      )
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            AppButton(
              key: const Key('admin-reward-grant'),
              label: submitting
                  ? 'جاري المنح…'
                  : pinned != null
                  ? kAwardGrantRetrySameLabel
                  : 'منح الجائزة',
              onPressed: submitting
                  ? null
                  : pinned != null
                  ? (_submissionId.canRetry
                        ? () => context.read<AdminBloc>().add(
                            GrantAdminRewardEvent(params: pinned),
                          )
                        : null)
                  : locked
                  ? null
                  : () {
                      final auth = context.read<AuthBloc>().state;
                      if (auth is! AuthAuthenticated) return;
                      _grant(context, auth.user.uid);
                    },
            ),
            const SizedBox(height: 24),
            const AdminSectionHeader(title: 'آخر الجوائز الممنوحة'),
            const SizedBox(height: 8),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_historyError != null)
              AppErrorWidget(
                key: const Key('reward-history-error'),
                message: _historyError!,
                onRetry: _reloadHistory,
              )
            else if (_history.isEmpty)
              Text(
                'لم تُمنح جوائز بعد',
                key: const Key('reward-history-empty'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              )
            else
              for (final e in _history) _RewardHistoryTile(entry: e),
          ],
        );
      },
    );
  }
}

class _RewardPreview extends StatelessWidget {
  final String typeLabel;
  final String title;
  final String reason;
  final AdminRewardRecipients? recipients;

  const _RewardPreview({
    required this.typeLabel,
    required this.title,
    required this.reason,
    required this.recipients,
  });

  @override
  Widget build(BuildContext context) {
    final r = recipients;
    final count = r?.recipientStudentIds.length ?? 0;
    final who = r == null
        ? 'حدّد المستلم والحلقة لإكمال المعاينة'
        : r.studentName != null
        ? 'المستلم: ${r.studentName!.trim().isEmpty ? 'طالب بدون اسم' : r.studentName!.trim()} · الحلقة: ${r.halaqaName}'
        : 'المستلمون: جميع طلاب ${r.halaqaName} ($count طالب)';
    return AppCard(
      key: const Key('reward-preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'معاينة الجائزة',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$typeLabel · ${title.isEmpty ? 'أدخل عنوان الجائزة' : title}',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(who, style: AppTextStyles.bodyMedium),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('السبب: $reason', style: AppTextStyles.bodyMedium),
          ],
          const SizedBox(height: 6),
          Text(
            'تظهر الجائزة في صفحة جوائز ${count > 1 ? 'كل طالب' : 'الطالب'} بعد المنح.',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardHistoryTile extends StatelessWidget {
  final AdminRewardHistoryEntry entry;

  const _RewardHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final details = [
      entry.typeLabel,
      entry.recipientLabel,
      if (entry.halaqaName.isNotEmpty) entry.halaqaName,
      if (date != null) formatDateDmy(date),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        key: Key('reward-history-${entry.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.title,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(details, style: AppTextStyles.labelSmall),
            if (entry.reason.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'السبب: ${entry.reason}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

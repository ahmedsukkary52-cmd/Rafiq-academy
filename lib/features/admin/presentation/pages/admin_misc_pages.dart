import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../awards/data/award_grant_errors.dart';
import '../../../awards/domain/award_submission_id.dart';
import '../../../awards/domain/unresolved_award_store.dart';
import '../../../awards/presentation/widgets/unresolved_award_panel.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/bloc/chat_conversations_state.dart';
import '../../data/admin_grant_reward_payload_codec.dart';
import '../../domain/admin_grant_reward_params.dart';
import '../../domain/entities/communication_settings_entity.dart';
import '../admin_format.dart';
import '../admin_report_export.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';
import '../widgets/admin_loading_skeletons.dart';

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

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  AdminReportKind _kind = AdminReportKind.students;
  String _format = 'csv';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<AdminBloc>();
      bloc.add(const RefreshAdminDashboardEvent());
      if (bloc.state.teachersStatus != SectionStatus.loaded) {
        bloc.add(const LoadAllTeachersEvent());
      }
    });
  }

  Future<void> _export() async {
    final state = context.read<AdminBloc>().state;
    final rows = AdminReportExport.buildCsvRows(
      kind: _kind,
      stats: state.stats,
      finance: state.financialSummary,
      complaints: state.complaints,
      teachers: state.teachers,
    );
    final csv = AdminReportExport.toCsv(rows);
    if (_format == 'csv') {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        AppSnackBar.showSuccess(context, 'تم نسخ التقرير CSV');
      }
      return;
    }
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rows.map((row) => pw.Text(row.join(' | '))).toList(),
        ),
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'admin_report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminFeatureShell(
      title: 'مركز التقارير',
      subtitle: 'تصدير من البيانات المتاحة (Client export)',
      sections: [
        AdminSectionHeader(title: 'نوع التقرير'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AdminReportKind.values.map((k) {
            final label = switch (k) {
              AdminReportKind.students => 'طلاب',
              AdminReportKind.teachers => 'معلمون',
              AdminReportKind.finance => 'مالي',
            };
            return AdminFilterChip(
              label: label,
              selected: _kind == k,
              onTap: () => setState(() => _kind = k),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        AdminSectionHeader(title: 'تصدير كـ'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ExportChip(
                label: 'PDF',
                selected: _format == 'pdf',
                onTap: () => setState(() => _format = 'pdf'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExportChip(
                label: 'CSV',
                selected: _format == 'csv',
                onTap: () => setState(() => _format = 'csv'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppButton(label: 'تصدير الآن', onPressed: _export),
      ],
    );
  }
}

const _recipientsUnavailableMessage =
    'تعذر تحديد مستلمي الجائزة من قائمة الحلقات. يجري تحديث القائمة؛ '
    'أعد المحاولة بعد قليل.';

const _chooseStudentHalaqaMessage =
    'الطالب مسجل في أكثر من حلقة. اختر الحلقة التي تُمنح فيها الجائزة.';

class AdminRewardsPage extends StatefulWidget {
  const AdminRewardsPage({super.key});

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
  late final AwardSubmissionId<AdminGrantRewardParams> _submissionId;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  List<({String id, String label})> _targetOptions(AdminState state) {
    if (_target == AdminRewardTargetKind.halaqa) {
      return state.halaqatDirectory
          .map((h) => (id: h.id, label: h.name))
          .toList();
    }
    final seen = <String>{};
    return [
      for (final s in state.studentRoster.expand((h) => h.students))
        if (seen.add(s.uid)) (id: s.uid, label: s.name),
    ];
  }

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
                            return AdminFilterChip(
                              label: entry.$2,
                              selected: _rewardType == entry.$1,
                              onTap: () =>
                                  setState(() => _rewardType = entry.$1),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedTargetId,
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
                      items: _targetOptions(state)
                          .map(
                            (o) => DropdownMenuItem(
                              value: o.id,
                              child: Text(o.label),
                            ),
                          )
                          .toList(),
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
                      decoration: InputDecoration(
                        labelText: 'السبب',
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
          ],
        );
      },
    );
  }
}

class AdminCommunicationSettingsPage extends StatefulWidget {
  const AdminCommunicationSettingsPage({super.key});

  @override
  State<AdminCommunicationSettingsPage> createState() =>
      _AdminCommunicationSettingsPageState();
}

class _AdminCommunicationSettingsPageState
    extends State<AdminCommunicationSettingsPage> {
  CommunicationSettingsEntity? _draft;

  /// The bloc is a singleton: settings from an earlier visit must not be
  /// editable (or savable) until this visit's own load has finished.
  bool _awaitingLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    setState(() {
      _awaitingLoad = true;
      _draft = null;
    });
    context.read<AdminBloc>().add(const LoadCommunicationSettingsEvent());
  }

  void _onStateChanged(BuildContext context, AdminState state) {
    final load = state.communicationSettingsStatus;
    if (_awaitingLoad &&
        (load == SectionStatus.loaded || load == SectionStatus.error)) {
      setState(() => _awaitingLoad = false);
    }
    final save = state.saveCommunicationSettingsStatus;
    if (save == SubmissionStatus.success) {
      setState(() => _draft = null);
      AppSnackBar.showSuccess(context, 'تم حفظ الإعدادات');
      context.read<AdminBloc>().add(const ResetCommunicationSettingsEvent());
    } else if (save == SubmissionStatus.error) {
      AppSnackBar.showError(
        context,
        state.saveCommunicationSettingsError ?? 'تعذر الحفظ',
      );
      context.read<AdminBloc>().add(const ResetCommunicationSettingsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminBloc, AdminState>(
      listenWhen: (p, c) =>
          p.communicationSettingsStatus != c.communicationSettingsStatus ||
          p.saveCommunicationSettingsStatus !=
              c.saveCommunicationSettingsStatus,
      listener: _onStateChanged,
      builder: (context, state) {
        final load = state.communicationSettingsStatus;
        if (load == SectionStatus.error && !_awaitingLoad) {
          return AdminSubpageScaffold(
            title: 'إعدادات التواصل',
            body: AppErrorWidget(
              key: const Key('communication-settings-load-error'),
              message:
                  state.communicationSettingsError ??
                  'تعذر تحميل إعدادات التواصل',
              onRetry: _load,
            ),
          );
        }
        final loaded = state.communicationSettings;
        if (_awaitingLoad || load != SectionStatus.loaded || loaded == null) {
          return const AdminSubpageScaffold(
            title: 'إعدادات التواصل',
            body: const AdminSettingsTogglesSkeleton(),
          );
        }
        final s = _draft ?? loaded;
        final saving =
            state.saveCommunicationSettingsStatus ==
            SubmissionStatus.submitting;
        return AdminFeatureShell(
          title: 'إعدادات التواصل',
          sections: [
            AppCard(
              // ListTiles paint ink on the nearest Material, not on the card.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('رد تلقائي خارج أوقات العمل'),
                      value: s.autoReplyOutsideHours,
                      onChanged: saving
                          ? null
                          : (v) => setState(
                              () => _draft = CommunicationSettingsEntity(
                                autoReplyOutsideHours: v,
                                broadcastsNeedApproval:
                                    s.broadcastsNeedApproval,
                                maxFileSizeMb: s.maxFileSizeMb,
                                allowedFileTypes: s.allowedFileTypes,
                                conversationRetentionDays:
                                    s.conversationRetentionDays,
                              ),
                            ),
                    ),
                    SwitchListTile(
                      title: const Text('تحتاج البثوث موافقة المدير'),
                      value: s.broadcastsNeedApproval,
                      onChanged: saving
                          ? null
                          : (v) => setState(
                              () => _draft = CommunicationSettingsEntity(
                                autoReplyOutsideHours: s.autoReplyOutsideHours,
                                broadcastsNeedApproval: v,
                                maxFileSizeMb: s.maxFileSizeMb,
                                allowedFileTypes: s.allowedFileTypes,
                                conversationRetentionDays:
                                    s.conversationRetentionDays,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                    label: 'الحد الأقصى لحجم الملف',
                    value: '${s.maxFileSizeMb} MB',
                  ),
                  const Divider(),
                  _InfoRow(label: 'أنواع الملفات', value: s.allowedFileTypes),
                  const Divider(),
                  _InfoRow(
                    label: 'مدة الاحتفاظ',
                    value: '${s.conversationRetentionDays} يوم',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              key: const Key('communication-settings-save'),
              label: 'حفظ',
              isLoading: saving,
              onPressed: () {
                context.read<AdminBloc>().add(
                  SaveCommunicationSettingsEvent(settings: s),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class AdminFinanceDetailPage extends StatefulWidget {
  const AdminFinanceDetailPage({super.key});

  @override
  State<AdminFinanceDetailPage> createState() => _AdminFinanceDetailPageState();
}

class _AdminFinanceDetailPageState extends State<AdminFinanceDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadFinancialSummaryEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminFeatureShell(
      title: 'لوحة مالية تفصيلية',
      sections: [
        BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            final f = state.financialSummary;
            if (state.financialStatus == SectionStatus.loading || f == null) {
              return const AdminFinanceDetailSkeleton();
            }
            return AppCard(
              child: Column(
                children: [
                  _InfoRow(
                    label: 'إيرادات مدفوعة',
                    value: '${formatAdminCount(f.totalRevenue.round())} ر.س',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'معلق',
                    value: '${formatAdminCount(f.totalPending.round())} ر.س',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'متأخر',
                    value: '${formatAdminCount(f.totalOverdue.round())} ر.س',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class AdminCommunicationAnalyticsPage extends StatefulWidget {
  const AdminCommunicationAnalyticsPage({super.key});

  @override
  State<AdminCommunicationAnalyticsPage> createState() =>
      _AdminCommunicationAnalyticsPageState();
}

class _AdminCommunicationAnalyticsPageState
    extends State<AdminCommunicationAnalyticsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        context.read<ChatConversationsBloc>().add(
          StartWatchingAllConversationsEvent(auth.user.uid),
        );
      }
    });
  }

  List<double> _weekdayCounts(List<ConversationEntity> conversations) {
    final counts = List<double>.filled(7, 0);
    for (final c in conversations) {
      final at = c.lastMessageAt;
      if (at == null) continue;
      counts[at.weekday % 7] += 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatConversationsBloc, ChatConversationsState>(
      builder: (context, chatState) {
        final convCount = chatState.conversations.length;
        final chartValues = _weekdayCounts(chatState.conversations);
        final hasChartData = chartValues.any((v) => v > 0);

        return AdminFeatureShell(
          title: 'تحليلات التواصل',
          subtitle: 'آخر 7 أيام',
          sections: [
            _SummaryCard(
              value: adminFormatCount(convCount),
              label: 'محادثات نشطة',
              icon: Icons.chat_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            if (chatState.conversationsStatus == SectionStatus.loading)
              const AdminBarChartSkeleton()
            else if (!hasChartData)
              const AdminPlaceholderCard(
                icon: Icons.bar_chart_outlined,
                title: 'لا بيانات بعد',
                message: 'سيظهر الرسم عند توفر نشاط محادثات في الأسبوع الحالي.',
              )
            else
              AppCard(
                child: AdminSimpleBarChart(
                  values: chartValues,
                  labels: const ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Private tiles ─────────────────────────────────────────────────────────────

class _ExportChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ExportChip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

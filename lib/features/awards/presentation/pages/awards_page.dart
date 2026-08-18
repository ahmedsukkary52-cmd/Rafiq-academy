import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../../teacher/presentation/bloc/teacher_bloc.dart';
import '../../../teacher/presentation/widgets/teacher_loading_skeletons.dart';
import '../../domain/award_recipient_selection.dart';
import '../../domain/entities/award_entities.dart';
import '../bloc/awards_bloc.dart';
import '../bloc/awards_event.dart';
import '../bloc/awards_state.dart';

class AwardsPage extends StatefulWidget {
  final String halaqaId;
  final bool embedded;

  const AwardsPage({
    super.key,
    required this.halaqaId,
    this.embedded = false,
  });

  @override
  State<AwardsPage> createState() => _AwardsPageState();
}

class _AwardsPageState extends State<AwardsPage> {
  late final AwardsBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<AwardsBloc>();
    _bloc.add(LoadAwardsDashboardEvent(widget.halaqaId));
  }

  @override
  void didUpdateWidget(AwardsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.halaqaId != widget.halaqaId) {
      _bloc.add(LoadAwardsDashboardEvent(widget.halaqaId));
    }
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
      child: BlocListener<AwardsBloc, AwardsState>(
        listenWhen: (previous, current) =>
            previous.grantStatus != current.grantStatus,
        listener: (context, state) {
          if (state.grantStatus == SubmissionStatus.success) {
            AppSnackBar.showSuccess(context, 'تم منح الجائزة بنجاح');
            _bloc.add(const ResetGrantAwardEvent());
          } else if (state.grantStatus == SubmissionStatus.error) {
            AppSnackBar.showError(
              context,
              state.grantError ?? 'تعذر منح الجائزة',
            );
            _bloc.add(const ResetGrantAwardEvent());
          }
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              automaticallyImplyLeading: !widget.embedded,
              title: Text(
                'الجوائز',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () => _showCreateAwardSheet(context),
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  label: Text(
                    'جائزة جديدة',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            body: BlocBuilder<AwardsBloc, AwardsState>(
              buildWhen: (previous, current) =>
                  previous.statsStatus != current.statsStatus ||
                  previous.stats != current.stats ||
                  previous.statsError != current.statsError ||
                  previous.awardsStatus != current.awardsStatus ||
                  previous.grantedAwards != current.grantedAwards ||
                  previous.awardsError != current.awardsError,
              builder: (context, state) {
                if (state.statsStatus == SectionStatus.initial ||
                    (state.statsStatus == SectionStatus.loading &&
                        state.stats == null)) {
                  return const TeacherAwardsDashboardSkeleton();
                }

                if (state.statsStatus == SectionStatus.error &&
                    state.stats == null) {
                  return AppErrorWidget(
                    message: state.statsError ?? 'تعذر تحميل الجوائز',
                    onRetry: () => _bloc.add(
                      LoadAwardsDashboardEvent(widget.halaqaId),
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.paddingM,
                          AppSizes.paddingM,
                          AppSizes.paddingM,
                          0,
                        ),
                        child: _AwardsStatsRow(stats: state.stats),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.paddingM,
                          AppSizes.paddingL,
                          AppSizes.paddingM,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'أنواع الجوائز',
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.15,
                              children: AwardTypeInfo.catalogPresets
                                  .map(
                                    (type) => _AwardTypeCard(
                                      type: type,
                                      onTap: () => _showCreateAwardSheet(
                                        context,
                                        preset: type,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'سجل الجوائز',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    if (state.awardsStatus == SectionStatus.loading &&
                        state.grantedAwards.isEmpty)
                      const SliverToBoxAdapter(
                        child: TeacherAwardsHistorySkeleton(),
                      )
                    else if (state.grantedAwards.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'لا توجد جوائز ممنوحة بعد',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: state.grantedAwards.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _AwardHistoryTile(
                              award: state.grantedAwards[index],
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateAwardSheet(BuildContext context, {AwardType? preset}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _bloc,
        child: CreateAwardSheet(
          halaqaId: widget.halaqaId,
          preset: preset,
        ),
      ),
    );
  }
}

Color _awardTypeColor(AwardType type) => switch (type) {
  AwardType.completionBadge || AwardType.completion => AppColors.awardCompletion,
  AwardType.performanceStars ||
  AwardType.performance => AppColors.awardPerformance,
  AwardType.perfectAttendance ||
  AwardType.attendance => AppColors.awardAttendance,
  AwardType.studentOfWeek || AwardType.achievement => AppColors.awardWeekly,
  AwardType.custom => AppColors.primary,
};

IconData _awardTypeIcon(AwardType type) => switch (type) {
  AwardType.completionBadge || AwardType.completion => Icons.verified_rounded,
  AwardType.performanceStars || AwardType.performance => Icons.star_rounded,
  AwardType.perfectAttendance ||
  AwardType.attendance => Icons.person_rounded,
  AwardType.studentOfWeek ||
  AwardType.achievement => Icons.emoji_events_rounded,
  AwardType.custom => Icons.workspace_premium_outlined,
};

class _AwardsStatsRow extends StatelessWidget {
  final AwardsStatsEntity? stats;

  const _AwardsStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          value: '${stats?.totalAwardsCount ?? 0}',
          label: 'إجمالي الجوائز',
          icon: Icons.emoji_events_outlined,
          iconBg: AppColors.secondaryBg,
          iconColor: AppColors.secondary,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${stats?.thisMonthCount ?? 0}',
          label: 'هذا الشهر',
          icon: Icons.calendar_month_outlined,
          iconBg: AppColors.primaryLight,
          iconColor: AppColors.primaryDark,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${stats?.totalRecipients ?? 0}',
          label: 'الطلاب المكرمون',
          icon: Icons.groups_outlined,
          iconBg: AppColors.successBg,
          iconColor: AppColors.success,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: const [
            BoxShadow(
              color: AppColors.softShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardTypeCard extends StatelessWidget {
  final AwardType type;
  final VoidCallback onTap;

  const _AwardTypeCard({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _awardTypeColor(type);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
                child: Icon(_awardTypeIcon(type), color: Colors.white, size: 26),
              ),
              const SizedBox(height: 8),
              Text(
                type.title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                type.description,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwardHistoryTile extends StatelessWidget {
  final GrantedAwardEntity award;

  const _AwardHistoryTile({required this.award});

  @override
  Widget build(BuildContext context) {
    final count = award.recipientCount > 0
        ? award.recipientCount
        : award.honoredStudentIds.length;
    final imageUrl = award.imageUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(award.type),
                  )
                : _imageFallback(award.type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  award.displayTitle,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((award.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    award.description!.trim(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  [
                    award.type.formCategory.title,
                    '$count طالب',
                    if (award.halaqaScopeLabel.isNotEmpty)
                      award.halaqaScopeLabel,
                    formatDateDmy(award.grantedAt),
                  ].join(' · '),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback(AwardType type) {
    return Container(
      width: 64,
      height: 64,
      color: _awardTypeColor(type),
      child: Icon(_awardTypeIcon(type), color: Colors.white),
    );
  }
}

class CreateAwardSheet extends StatefulWidget {
  final String halaqaId;
  final AwardType? preset;
  final String? preselectedStudentId;

  const CreateAwardSheet({
    super.key,
    required this.halaqaId,
    this.preset,
    this.preselectedStudentId,
  });

  @override
  State<CreateAwardSheet> createState() => _CreateAwardSheetState();
}

class _CreateAwardSheetState extends State<CreateAwardSheet> {
  late AwardType _type;
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  late AwardRecipientSelection _selection;
  final _rosters = <String, List<AwardRecipientStudent>>{};
  final _loadingHalaqat = <String>{};
  final _rosterErrors = <String, String>{};
  String? _imagePath;
  String? _imageName;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _type = preset?.formCategory ?? AwardType.attendance;
    if (preset != null) {
      _titleCtrl.text = preset.title;
      _descriptionCtrl.text = preset.description;
    }
    _selection = AwardRecipientSelection(
      selectedHalaqaIds: {widget.halaqaId},
      selectedStudentIds: {
        if ((widget.preselectedStudentId ?? '').trim().isNotEmpty)
          widget.preselectedStudentId!.trim(),
      },
    );
    _titleCtrl.addListener(_onFieldsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seedKnownRoster();
      _ensureSelectedRosters();
    });
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onFieldsChanged);
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _onFieldsChanged() => setState(() {});

  void _seedKnownRoster() {
    final teacherState = context.read<TeacherBloc>().state;
    final loadedId = teacherState.studentsHalaqaId;
    if (loadedId == null || teacherState.students.isEmpty) return;
    _rosters.putIfAbsent(
      loadedId,
      () => AwardRecipientSelection.uniqueStudents(
        teacherState.students.map(
          (student) => AwardRecipientStudent(
            uid: student.uid,
            name: student.name,
            imageUrl: student.profileImageUrl,
          ),
        ),
      ),
    );
    _selection = _selection.ensuringStudentSelected(
      widget.preselectedStudentId ?? '',
    );
  }

  Future<void> _ensureSelectedRosters() async {
    for (final halaqaId in _selection.selectedHalaqaIds) {
      await _ensureRoster(halaqaId);
    }
  }

  Future<void> _ensureRoster(String halaqaId) async {
    if (_rosters.containsKey(halaqaId) || _loadingHalaqat.contains(halaqaId)) {
      return;
    }
    setState(() {
      _loadingHalaqat.add(halaqaId);
      _rosterErrors.remove(halaqaId);
    });
    final result = await sl<GetHalaqaStudentsUseCase>()(
      HalaqaStudentsParams(halaqaId),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _loadingHalaqat.remove(halaqaId);
        _rosterErrors[halaqaId] = failure.message;
      }),
      (students) => setState(() {
        _loadingHalaqat.remove(halaqaId);
        _rosters[halaqaId] = AwardRecipientSelection.uniqueStudents(
          students.map(
            (student) => AwardRecipientStudent(
              uid: student.uid,
              name: student.name,
              imageUrl: student.profileImageUrl,
            ),
          ),
        );
        _selection = _selection.ensuringStudentSelected(
          widget.preselectedStudentId ?? '',
        );
      }),
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _imagePath = path;
      _imageName = result!.files.single.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.user.uid : '';
    final teacherState = context.watch<TeacherBloc>().state;
    final loadedId = teacherState.studentsHalaqaId;
    if (loadedId != null &&
        teacherState.students.isNotEmpty &&
        !_rosters.containsKey(loadedId)) {
      _rosters[loadedId] = AwardRecipientSelection.uniqueStudents(
        teacherState.students.map(
          (student) => AwardRecipientStudent(
            uid: student.uid,
            name: student.name,
            imageUrl: student.profileImageUrl,
          ),
        ),
      );
    }
    final teacherHalaqat = teacherState.halaqat
        .map((halaqa) => AwardHalaqaOption(id: halaqa.id, name: halaqa.name))
        .toList(growable: false);
    final allHalaqaIds = teacherHalaqat.map((halaqa) => halaqa.id);
    final allHalaqatSelected =
        teacherHalaqat.isNotEmpty &&
        _selection.selectedHalaqaIds.length == teacherHalaqat.length &&
        _selection.selectedHalaqaIds.containsAll(allHalaqaIds);
    final groups = AwardRecipientSelection.visibleGroups(
      teacherHalaqat: teacherHalaqat,
      selectedHalaqaIds: _selection.selectedHalaqaIds,
      rosters: _rosters,
    );
    final recipients = _selection.resolvedRecipients(_rosters);
    final selectedHalaqat = AwardRecipientSelection.selectedHalaqatInOrder(
      teacherHalaqat: teacherHalaqat,
      selectedHalaqaIds: _selection.selectedHalaqaIds,
    );
    final selectedHalaqaIds = selectedHalaqat.map((h) => h.id).toList();
    final selectedHalaqaNames = selectedHalaqat.map((h) => h.name).toList();
    final primaryHalaqaId = AwardRecipientSelection.primaryHalaqaId(
      selectedHalaqaIds: selectedHalaqaIds,
      preferredHalaqaId: widget.halaqaId,
    );
    final matchingPrimary = selectedHalaqat.where((h) => h.id == primaryHalaqaId);
    final halaqaName = matchingPrimary.isEmpty
        ? (selectedHalaqaNames.isEmpty ? null : selectedHalaqaNames.first)
        : matchingPrimary.first.name;
    final showGlobalSelectAll =
        groups.length > 1 &&
        groups.any((group) => group.students.isNotEmpty);

    return _BottomSheet(
      title: 'جائزة جديدة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('اسم الجائزة', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          AppTextField(hint: 'مثال: حضور مثالي', controller: _titleCtrl),
          const SizedBox(height: 16),
          Text('الوصف / السبب', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          AppTextField(
            hint: 'مثال: للالتزام بالحضور طوال الشهر',
            controller: _descriptionCtrl,
          ),
          const SizedBox(height: 16),
          Text('نوع الجائزة', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AwardTypeInfo.formTypes.map((type) {
              final selected = type == _type;
              return ChoiceChip(
                label: Text(type.title),
                selected: selected,
                onSelected: (_) => setState(() => _type = type),
                selectedColor: AppColors.primaryLight,
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('صورة الجائزة', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              _imageName == null || _imageName!.isEmpty
                  ? 'اختيار صورة'
                  : _imageName!,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('الحلقات المستفيدة', style: AppTextStyles.labelLarge),
              const Spacer(),
              Text(
                'المحدد: ${_selection.selectedHalaqaCount}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (teacherHalaqat.isEmpty)
            Text(
              'لا توجد حلقات محمّلة',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            CheckboxListTile(
              value: allHalaqatSelected,
              onChanged: (_) {
                setState(() {
                  _selection = _selection.toggleSelectAllHalaqat(
                    allHalaqaIds: allHalaqaIds,
                    rosters: _rosters,
                  );
                });
                _ensureSelectedRosters();
              },
              title: const Text('اختيار الكل'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            ...teacherHalaqat.map(
              (halaqa) => CheckboxListTile(
                value: _selection.selectedHalaqaIds.contains(halaqa.id),
                onChanged: (_) {
                  setState(() {
                    _selection = _selection.toggleHalaqa(
                      halaqa.id,
                      allHalaqaIds: allHalaqaIds,
                      rosters: _rosters,
                    );
                  });
                  _ensureSelectedRosters();
                },
                title: Text(halaqa.name),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          if (_selection.hasHalaqa) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('الطلاب المستفيدون', style: AppTextStyles.labelLarge),
                const Spacer(),
                Text(
                  'المحدد: ${_selection.selectedStudentCount}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (showGlobalSelectAll)
              CheckboxListTile(
                value: _selection.isGlobalAllSelected(_rosters),
                onChanged: (_) {
                  setState(() {
                    _selection = _selection.toggleSelectAllStudents(_rosters);
                  });
                },
                title: const Text('اختيار كل الطلاب'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ...groups.map((group) {
              final loading = _loadingHalaqat.contains(group.halaqaId);
              final error = _rosterErrors[group.halaqaId];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      group.halaqaName,
                      style: AppTextStyles.labelLarge,
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (error != null)
                    Text(
                      error,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    )
                  else if (group.students.isEmpty)
                    Text(
                      'لا يوجد طلاب في هذه الحلقة',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    )
                  else ...[
                    CheckboxListTile(
                      value: _selection.isHalaqaFullySelected(
                        group.halaqaId,
                        _rosters,
                      ),
                      onChanged: (_) {
                        setState(() {
                          _selection = _selection.toggleSelectAllInHalaqa(
                            group.halaqaId,
                            _rosters,
                          );
                        });
                      },
                      title: const Text('اختيار كل طلاب الحلقة'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    ...group.students.map(
                      (student) => CheckboxListTile(
                        value: _selection.selectedStudentIds.contains(
                          student.uid,
                        ),
                        onChanged: (_) {
                          setState(() {
                            _selection = _selection.toggleStudent(student.uid);
                          });
                        },
                        title: Text(student.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
          const SizedBox(height: 16),
          Text(
            'الحلقات: ${_selection.selectedHalaqaCount}',
            style: AppTextStyles.bodyMedium,
          ),
          Text(
            'الطلاب: ${recipients.length}',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          BlocBuilder<AwardsBloc, AwardsState>(
            buildWhen: (previous, current) =>
                previous.grantStatus != current.grantStatus,
            builder: (context, state) {
              final submitting =
                  state.grantStatus == SubmissionStatus.submitting;
              final canSubmit = AwardRecipientSelection.canGrant(
                hasHalaqa: _selection.hasHalaqa,
                hasStudent: recipients.isNotEmpty,
                title: _titleCtrl.text,
              );
              return AppButton(
                label: 'منح الجائزة',
                isLoading: submitting,
                onPressed: !canSubmit || submitting
                    ? null
                    : () {
                        final title = _titleCtrl.text.trim();
                        final selected = recipients;
                        if (selected.isEmpty) return;
                        final first = selected.first;
                        context.read<AwardsBloc>().add(
                          GrantAwardEvent(
                            GrantedAwardEntity(
                              id: '',
                              studentId: first.uid,
                              studentName: first.name,
                              studentImageUrl: first.imageUrl,
                              type: _type,
                              title: title,
                              description: _descriptionCtrl.text.trim().isEmpty
                                  ? null
                                  : _descriptionCtrl.text.trim(),
                              localImagePath: _imagePath,
                              grantedBy: uid,
                              halaqaId: primaryHalaqaId,
                              halaqaName: halaqaName,
                              halaqaIds: selectedHalaqaIds,
                              halaqaNames: selectedHalaqaNames,
                              grantedAt: DateTime.now(),
                              recipientStudentIds: selected
                                  .map((s) => s.uid)
                                  .toList(),
                              recipientCount: selected.length,
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusXL),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: AppSizes.paddingL,
            left: AppSizes.paddingM,
            right: AppSizes.paddingM,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + AppSizes.paddingL,
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: AppTextStyles.headlineMedium),
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

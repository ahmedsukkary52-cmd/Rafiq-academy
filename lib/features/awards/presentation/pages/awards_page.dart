import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../teacher/presentation/bloc/teacher_bloc.dart';
import '../../domain/entities/award_entities.dart';
import '../bloc/awards_bloc.dart';
import '../bloc/awards_event.dart';
import '../bloc/awards_state.dart';

class AwardsPage extends StatefulWidget {
  final String halaqaId;

  /// Home tab: no route back affordance beyond the shell.
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
                  onPressed: () => _showGrantAwardSheet(context),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AppColors.primary,
                  ),
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
                  return const AppLoadingWidget();
                }

                if (state.statsStatus == SectionStatus.error &&
                    state.stats == null) {
                  return AppErrorWidget(
                    message: state.statsError ?? 'تعذر تحميل الجوائز',
                    onRetry: () =>
                        _bloc.add(
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
                          24,
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
                              children: AwardType.values
                                  .map((type) => _AwardTypeCard(type: type))
                                  .toList(),
                            ),
                          ],
                        ),
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

  void _showGrantAwardSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: _bloc,
        child: _GrantAwardSheet(halaqaId: widget.halaqaId),
      ),
    );
  }
}

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
          label: 'المستفيدون',
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

  const _AwardTypeCard({required this.type});

  Color get _color => switch (type) {
    AwardType.completionBadge => AppColors.awardCompletion,
    AwardType.performanceStars => AppColors.awardPerformance,
    AwardType.perfectAttendance => AppColors.awardAttendance,
    AwardType.studentOfWeek => AppColors.awardWeekly,
  };

  IconData get _icon => switch (type) {
    AwardType.completionBadge => Icons.verified_rounded,
    AwardType.performanceStars => Icons.star_rounded,
    AwardType.perfectAttendance => Icons.person_rounded,
    AwardType.studentOfWeek => Icons.emoji_events_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(AppSizes.paddingM),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Icon(_icon, color: Colors.white, size: 26),
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
    );
  }
}

class _GrantAwardSheet extends StatefulWidget {
  final String halaqaId;

  const _GrantAwardSheet({required this.halaqaId});

  @override
  State<_GrantAwardSheet> createState() => _GrantAwardSheetState();
}

class _GrantAwardSheetState extends State<_GrantAwardSheet> {
  AwardType _type = AwardType.performanceStars;
  String? _studentId;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.user.uid : '';
    final teacherState = context
        .watch<TeacherBloc>()
        .state;
    final students = teacherState.studentsHalaqaId == widget.halaqaId
        ? teacherState.students
        : const [];

    return _BottomSheet(
      title: 'منح جائزة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('نوع الجائزة', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3,
            physics: const NeverScrollableScrollPhysics(),
            children: AwardType.values.map((t) {
              final selected = t == _type;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.title,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('الطالب', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          if (students.isEmpty)
            Text(
              'لا يوجد طلاب محمّلون لهذه الحلقة',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
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
                          students.any((s) => s.uid == _studentId)
                      ? _studentId
                      : null,
                  isExpanded: true,
                  hint: Text('اختر الطالب', style: AppTextStyles.bodyMedium),
                  items: [
                    for (final s in students)
                      DropdownMenuItem<String>(
                        value: s.uid,
                        child: Text(s.name, style: AppTextStyles.bodyMedium),
                      ),
                  ],
                  onChanged: (value) => setState(() => _studentId = value),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('ملاحظة (اختياري)', style: AppTextStyles.labelLarge),
          const SizedBox(height: 6),
          AppTextField(hint: 'مثال: ختم جزء تبارك', controller: _noteCtrl),
          const SizedBox(height: 20),
          AppButton(
            label: 'منح الجائزة',
            onPressed: _studentId == null
                ? null
                : () {
                    final selected = students.firstWhere(
                      (s) => s.uid == _studentId,
                    );
                    context.read<AwardsBloc>().add(
                      GrantAwardEvent(
                        GrantedAwardEntity(
                          id: '',
                          studentId: _studentId!,
                          studentName: selected.name,
                          studentImageUrl: selected.profileImageUrl,
                          type: _type,
                          note: _noteCtrl.text.trim().isEmpty
                              ? null
                              : _noteCtrl.text.trim(),
                          grantedBy: uid,
                          halaqaId: widget.halaqaId,
                          grantedAt: DateTime.now(),
                        ),
                      ),
                    );
                    Navigator.pop(context);
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
    );
  }
}

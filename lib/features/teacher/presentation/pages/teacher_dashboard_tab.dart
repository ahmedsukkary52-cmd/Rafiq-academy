import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/halaqa_schedule_label.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../presentation/bloc/teacher_bloc.dart';
import '../../presentation/bloc/teacher_event.dart';
import '../../presentation/bloc/teacher_state.dart';

class TeacherDashboardTab extends StatelessWidget {
  const TeacherDashboardTab({super.key});

  void _retryHalaqat(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<TeacherBloc>().add(LoadTeacherHalaqatEvent(auth.user.uid));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final auth = authState is AuthAuthenticated ? authState : null;
    final teacherName = auth?.user.name ?? '';

    return BlocBuilder<TeacherBloc, TeacherState>(
      builder: (context, state) {
        final halaqat = state.halaqat;
        final nextHalaqa = halaqat.isNotEmpty ? halaqat.first : null;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (auth == null) return;
            final bloc = context.read<TeacherBloc>();
            bloc.add(LoadTeacherHalaqatEvent(auth.user.uid));
            await bloc.stream.firstWhere(
              (s) =>
                  s.halaqatStatus == SectionStatus.loaded ||
                  s.halaqatStatus == SectionStatus.error,
            );
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _TeacherHeader(
                  name: teacherName,
                  halaqaName: nextHalaqa?.name ?? '',
                ),
              ),
              ..._bodySlivers(context, state, nextHalaqa),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _bodySlivers(
    BuildContext context,
    TeacherState state,
    HalaqaEntity? nextHalaqa,
  ) {
    if (state.halaqatStatus == SectionStatus.initial ||
        state.halaqatStatus == SectionStatus.loading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: AppLoadingWidget(),
        ),
      ];
    }

    if (state.halaqatStatus == SectionStatus.error) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorWidget(
            message: state.halaqatError ?? 'تعذر تحميل الحلقات',
            onRetry: () => _retryHalaqat(context),
          ),
        ),
      ];
    }

    final totalStudents = state.halaqat.fold<int>(
      0,
      (sum, h) => sum + h.studentIds.length,
    );

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingM,
            16,
            AppSizes.paddingM,
            0,
          ),
          child: _TeacherStatsRow(
            studentsCount: totalStudents,
            halaqatCount: state.halaqat.length,
          ),
        ),
      ),
      if (state.halaqat.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSizes.paddingM,
              16,
              AppSizes.paddingM,
              0,
            ),
            child: _EmptyHalaqatCard(),
          ),
        )
      else if (nextHalaqa != null) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.paddingM,
              16,
              AppSizes.paddingM,
              0,
            ),
            child: _HalaqaShortcutCard(
              halaqaName: nextHalaqa.name,
              studentsCount: nextHalaqa.studentIds.length,
              scheduleLabel: halaqaScheduleLabel(nextHalaqa.schedule),
              onOpenTap: () => context.push('/teacher/halaqa/${nextHalaqa.id}'),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: _HalaqaQuickLinksCard(
              onEvaluationsTap: () =>
                  context.push('/teacher/halaqa/${nextHalaqa.id}/evaluations'),
              onAnalyticsTap: () =>
                  context.push('/teacher/halaqa/${nextHalaqa.id}/analytics'),
            ),
          ),
        ),
      ],
    ];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TeacherHeader
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherHeader extends StatelessWidget {
  final String name;
  final String halaqaName;

  const _TeacherHeader({required this.name, required this.halaqaName});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      '',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final dayName = weekdays[now.weekday];

    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: AppSizes.paddingM,
        right: AppSizes.paddingM,
        bottom: AppSizes.paddingXL,
      ),
      child: Column(
        children: [
          // شريط أيقونات علوي
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الأستاذ $name',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (halaqaName.isNotEmpty)
                        Text(
                          'معلم تحفيظ · $halaqaName',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0] : 'م',
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              BlocBuilder<NotificationsBloc, NotificationsState>(
                bloc: sl<NotificationsBloc>(),
                builder: (context, notifState) {
                  return NotificationBadge(
                    count: notifState.unreadCount,
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () => context.push(AppRoutes.teacherNotifs),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // التحية
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'يوم $dayName مبارك!',
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'السلام عليكم',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TeacherStatsRow - إحصاءات حقيقية فقط
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherStatsRow extends StatelessWidget {
  final int studentsCount;
  final int halaqatCount;

  const _TeacherStatsRow({
    required this.studentsCount,
    required this.halaqatCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$studentsCount',
            label: 'إجمالي الطلاب',
            icon: Icons.person_outline_rounded,
            color: AppColors.primaryLight,
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: '$halaqatCount',
            label: 'الحلقات',
            icon: Icons.calendar_today_outlined,
            color: const Color(0xFFE8F5E9),
            iconColor: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _EmptyHalaqatCard extends StatelessWidget {
  const _EmptyHalaqatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'لا توجد حلقات مسندة إليك حالياً',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(label, style: AppTextStyles.labelSmall),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HalaqaShortcutCard — فتح حلقة محمّلة مسبقاً (بدون ادّعاء جلسة مباشرة)
// ══════════════════════════════════════════════════════════════════════════════

class _HalaqaShortcutCard extends StatelessWidget {
  final String halaqaName;
  final int studentsCount;
  final String? scheduleLabel;
  final VoidCallback onOpenTap;

  const _HalaqaShortcutCard({
    required this.halaqaName,
    required this.studentsCount,
    required this.scheduleLabel,
    required this.onOpenTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = scheduleLabel?.trim();
    final hasSchedule = label != null && label.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'فتح الحلقة',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasSchedule) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white60,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Text(
                halaqaName,
                style: const TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$studentsCount طالباً',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.people_outline,
                    color: Colors.white60,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HalaqaQuickLinksCard — اختصارات تنقّل فقط (بدون ادّعاء ذكاء اصطناعي)
// ══════════════════════════════════════════════════════════════════════════════

class _HalaqaQuickLinksCard extends StatelessWidget {
  final VoidCallback onEvaluationsTap;
  final VoidCallback onAnalyticsTap;

  const _HalaqaQuickLinksCard({
    required this.onEvaluationsTap,
    required this.onAnalyticsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'اختصارات الحلقة',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'انتقال سريع إلى صفحات الحلقة',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              _QuickLinkChip(label: 'تحليلات الحلقة', onTap: onAnalyticsTap),
              _QuickLinkChip(label: 'التقييمات', onTap: onEvaluationsTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLinkChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickLinkChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 13,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

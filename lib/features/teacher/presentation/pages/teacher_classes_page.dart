import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';

class TeacherClassesPage extends StatefulWidget {
  const TeacherClassesPage({super.key});

  @override
  State<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

class _TeacherClassesPageState extends State<TeacherClassesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = context.read<TeacherBloc>().state.halaqatStatus;
      if (status == SectionStatus.initial) {
        _loadHalaqat();
      }
    });
  }

  void _comingSoon(BuildContext context) {
    AppSnackBar.showInfo(context, 'قريبًا');
  }

  void _loadHalaqat() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    context.read<TeacherBloc>().add(
      LoadTeacherHalaqatEvent(authState.user.uid),
    );
  }

  Future<void> _onRefresh() async {
    _loadHalaqat();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حلقاتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _comingSoon(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _comingSoon(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _comingSoon(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: BlocBuilder<TeacherBloc, TeacherState>(
        builder: (context, state) {
          if (state.halaqatStatus == SectionStatus.loading ||
              state.halaqatStatus == SectionStatus.initial) {
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

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: state.halaqat.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _HalaqaCard(halaqa: state.halaqat[i]),
            ),
          );
        },
      ),
    );
  }
}

class _HalaqaCard extends StatelessWidget {
  final HalaqaEntity halaqa;

  const _HalaqaCard({required this.halaqa});

  @override
  Widget build(BuildContext context) {
    final scheduleLabel = _scheduleLabel(halaqa);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _ActionChip(
                    label: 'تقييم',
                    color: AppColors.secondaryBg,
                    textColor: AppColors.secondary,
                    onTap: () => context.push(
                      '/teacher/halaqa/${halaqa.id}/evaluations',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionChip(
                    label: 'عرض الحلقة',
                    color: AppColors.primary,
                    textColor: Colors.white,
                    onTap: () {
                      context.read<TeacherBloc>().add(
                        SelectHalaqaEvent(halaqa.id),
                      );
                      context.push('/teacher/halaqa/${halaqa.id}');
                    },
                  ),
                ],
              ),
              if (halaqa.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    'فعّالة',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(halaqa.name, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${halaqa.studentIds.length} طالب',
                style: AppTextStyles.labelMedium,
              ),
              if (scheduleLabel != null) ...[
                const SizedBox(width: 16),
                Row(
                  children: [
                    Text(scheduleLabel, style: AppTextStyles.labelMedium),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String? _scheduleLabel(HalaqaEntity halaqa) {
    final schedule = halaqa.schedule;
    if (schedule.isEmpty) return null;

    final days = schedule
        .map((s) => _dayShort(s.day))
        .where((d) => d.isNotEmpty)
        .toList();
    final daysLabel = days.join('، ');

    final first = schedule.first;
    final start = first.startTime.trim();
    final end = first.endTime.trim();
    final timeLabel = start.isEmpty
        ? ''
        : end.isEmpty
        ? start
        : '$start–$end';

    if (daysLabel.isEmpty && timeLabel.isEmpty) return null;
    if (daysLabel.isEmpty) return timeLabel;
    if (timeLabel.isEmpty) return daysLabel;
    return '$daysLabel · $timeLabel';
  }

  String _dayShort(String day) => switch (day.trim()) {
    'الأحد' => 'أح',
    'الاثنين' => 'إث',
    'الثلاثاء' => 'ثل',
    'الأربعاء' => 'أر',
    'الخميس' => 'خم',
    'الجمعة' => 'جم',
    'السبت' => 'سب',
    _ => day.trim(),
  };
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _EmptyHalaqat extends StatelessWidget {
  const _EmptyHalaqat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_rounded,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حلقات مسندة إليك',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/review_item_entity.dart';
import '../bloc/review_schedule_bloc.dart';

class StudentReviewSchedulePage extends StatelessWidget {
  const StudentReviewSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final studentId = auth is AuthAuthenticated ? auth.user.uid : '';

    return BlocProvider(
      create: (_) =>
          sl<ReviewScheduleBloc>()
            ..add(LoadReviewMonthEvent(studentId: studentId)),
      child: _ReviewScheduleView(studentId: studentId),
    );
  }
}

class _ReviewScheduleView extends StatelessWidget {
  final String studentId;

  const _ReviewScheduleView({required this.studentId});

  void _retry(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final id = auth is AuthAuthenticated ? auth.user.uid : studentId;
    context.read<ReviewScheduleBloc>().add(LoadReviewMonthEvent(studentId: id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        ),
        title: const Text(
          'جدول المراجعة 📅',
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: BlocBuilder<ReviewScheduleBloc, ReviewScheduleState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.month != current.month ||
            previous.errorMessage != current.errorMessage,
        builder: (context, state) {
          if (state.status == SectionStatus.loading ||
              state.status == SectionStatus.initial) {
            return const AppLoadingWidget();
          }

          if (state.status == SectionStatus.error) {
            return AppErrorWidget(
              message: state.errorMessage ?? 'تعذر تحميل جدول المراجعة',
              onRetry: () => _retry(context),
            );
          }

          final month = state.month;
          if (month == null) {
            return AppErrorWidget(
              message: 'لا توجد بيانات',
              onRetry: () => _retry(context),
            );
          }

          final isEmpty =
              month.daysWithReview.isEmpty && month.weekItems.isEmpty;

          return ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context
                              .read<ReviewScheduleBloc>()
                              .add(const ChangeReviewMonthEvent(-1)),
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          onPressed: () => context
                              .read<ReviewScheduleBloc>()
                              .add(const ChangeReviewMonthEvent(1)),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const Spacer(),
                        Text(month.monthTitle, style: AppTextStyles.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _HijriMonthGrid(
                      year: month.hijriYear,
                      month: month.hijriMonth,
                      daysWithReview: month.daysWithReview.toSet(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('هذا الأسبوع', style: AppTextStyles.labelMedium),
              ),
              const SizedBox(height: 10),
              if (isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      const Text(
                        'لا توجد مراجعات مجدولة في هذا الشهر',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'إعادة المحاولة',
                        width: 160,
                        height: 44,
                        onPressed: () => _retry(context),
                      ),
                    ],
                  ),
                )
              else if (month.weekItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'لا توجد مراجعات في هذا الأسبوع',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...month.weekItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReviewWeekTile(item: item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HijriMonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Set<int> daysWithReview;

  const _HijriMonthGrid({
    required this.year,
    required this.month,
    required this.daysWithReview,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = HijriCalendar().getDaysInMonth(year, month);
    final gFirst = HijriCalendar().hijriToGregorian(year, month, 1);
    // weekday: 1=Mon ... 7=Sun — نبدأ من الأحد في الشبكة
    final startOffset = gFirst.weekday % 7; // Sun=0
    final today = HijriCalendar.now();
    const weekDays = ['أح', 'إث', 'ثل', 'أر', 'خم', 'جم', 'سب'];

    return Column(
      children: [
        Row(
          children: weekDays
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startOffset + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();
            final day = index - startOffset + 1;
            final isToday =
                today.hYear == year &&
                today.hMonth == month &&
                today.hDay == day;
            final hasDot = daysWithReview.contains(day);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (hasDot)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewWeekTile extends StatelessWidget {
  final ReviewItemEntity item;

  const _ReviewWeekTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (item.status) {
      ReviewItemStatus.completed => (
        const Color(0xFFE8F5E9),
        AppColors.success,
        'مكتمل ✅',
      ),
      ReviewItemStatus.today => (
        AppColors.primaryLight,
        AppColors.primaryDark,
        'اليوم ⚡',
      ),
      ReviewItemStatus.upcoming => (
        AppColors.surfaceGrey,
        AppColors.textSecondary,
        'قادم',
      ),
    };

    return AppCard(
      hasBorder: item.status == ReviewItemStatus.today,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(item.rangeLabel, style: AppTextStyles.titleMedium),
                Text(
                  '${item.versesCount} آيات',
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${item.hijriDay}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  item.hijriMonthName.replaceAll(' ', ''),
                  style: const TextStyle(color: Colors.white70, fontSize: 8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

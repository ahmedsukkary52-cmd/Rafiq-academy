import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../bloc/student_bloc.dart';
import '../bloc/student_state.dart';

class DashboardSurahItem {
  final int number;
  final String name;
  final int versesCount;
  final String type; // مكية or مدنية
  final int completedVerses;
  final bool isCompleted;

  const DashboardSurahItem({
    required this.number,
    required this.name,
    required this.versesCount,
    required this.type,
    this.completedVerses = 0,
    this.isCompleted = false,
  });
}

class StudentMushafDashboard extends StatelessWidget {
  const StudentMushafDashboard({super.key});

  // TODO: القفل هيتفعل لاحقاً بناءً على خطة الحفظ اللي هيحددها المعلم لكل طالب - لحد ذلك كل السور مفتوحة
  static const List<DashboardSurahItem> _surahs = [
    DashboardSurahItem(
      number: 1,
      name: 'الفاتحة',
      versesCount: 7,
      type: 'مكية',
      isCompleted: true,
    ),
    DashboardSurahItem(
      number: 114,
      name: 'الناس',
      versesCount: 6,
      type: 'مكية',
      isCompleted: true,
    ),
    DashboardSurahItem(
      number: 113,
      name: 'الفلق',
      versesCount: 5,
      type: 'مكية',
      isCompleted: true,
    ),
    DashboardSurahItem(
      number: 67,
      name: 'الملك',
      versesCount: 30,
      type: 'مكية',
      completedVerses: 21,
    ),
    DashboardSurahItem(
      number: 68,
      name: 'القلم',
      versesCount: 52,
      type: 'مكية',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            final profile = state.profile;
            final overallProgress = (profile?.overallProgressPercent ?? 70.0)
                .round();
            final completedJuz = profile?.completedJuz ?? 1;

            return CustomScrollView(
              slivers: [
                // ── Header القسم العلوي الملون ────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 16,
                      bottom: 30,
                      left: 20,
                      right: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF14B2BA),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(AppSizes.radiusXL),
                        bottomRight: Radius.circular(AppSizes.radiusXL),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '📖 مصحفي',
                                  style: TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'تقدم حفظك ومراجعتك',
                                  style: TextStyle(
                                    fontFamily: 'NotoNaskhArabic',
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                              ],
                            ),
                            // الختمة badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'الختمة\n$completedJuz/٣٠',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Progress circles row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const _ProgressCircle(
                              percent: 40,
                              label: 'الإتقان',
                              color: Color(0xFF2DC4B2),
                            ),
                            const _ProgressCircle(
                              percent: 80,
                              label: 'المراجعة',
                              color: Color(0xFFF5A623),
                            ),
                            _ProgressCircle(
                              percent: overallProgress,
                              label: 'الحفظ',
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── السور المحفوظة ──────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'السور المحفوظة',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── مكتبة الصوتيات ─────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/student/audio'),
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF5A623), Color(0xFFD48815)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF5A623).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.headphones_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مكتبة الصوتيات',
                                        style: TextStyle(
                                          fontFamily: 'NotoNaskhArabic',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'استمع إلى تلاوات ومحاضرات',
                                        style: TextStyle(
                                          fontFamily: 'NotoNaskhArabic',
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── مصحف حر كامل ─────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/student/mushaf?free=true'),
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF14B2BA), Color(0xFF0E8E96)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF14B2BA).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.auto_stories_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مصحف حر كامل',
                                        style: TextStyle(
                                          fontFamily: 'NotoNaskhArabic',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'اقرأ أي سورة من المصحف كاملاً',
                                        style: TextStyle(
                                          fontFamily: 'NotoNaskhArabic',
                                          fontSize: 11,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 32,
                  ),
                  sliver: SliverList.separated(
                    itemCount: _surahs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _surahs[index];
                      return _SurahCard(item: item);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  final int percent;
  final String label;
  final Color color;

  const _ProgressCircle({
    required this.percent,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                value: percent / 100,
                strokeWidth: 6,
                backgroundColor: isWhite
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

class _SurahCard extends StatelessWidget {
  final DashboardSurahItem item;

  const _SurahCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final Widget stateBadge = item.isCompleted
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCFF4DF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 12, color: Color(0xFF20AF68)),
                SizedBox(width: 4),
                Text(
                  'محفوظة',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF20AF68),
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFCFF4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'جارٍ ⚡',
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF14AEB8),
              ),
            ),
          );

    final bool isInProgress = !item.isCompleted && item.completedVerses > 0;

    final Color numberBgColor = item.number == 114
        ? const Color(0xFFF5A623)
        : item.number == 113
        ? const Color(0xFF20AF68)
        : const Color(0xFF14B2BA);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isInProgress
            ? Border.all(color: const Color(0xFF14B2BA), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/student/mushaf?surah=${item.number}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: numberBgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${item.number}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.versesCount} آيات · ${item.type}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  stateBadge,
                ],
              ),
              if (item.isCompleted) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 1,
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceGrey,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF14B2BA),
                    ),
                  ),
                ),
              ] else if (isInProgress && item.completedVerses > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.completedVerses / item.versesCount,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceGrey,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF14B2BA),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تم حفظ ${item.completedVerses} آيات',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${item.completedVerses}/${item.versesCount}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

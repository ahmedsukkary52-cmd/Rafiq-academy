import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../presentation/bloc/teacher_bloc.dart';
import '../../presentation/bloc/teacher_event.dart';
import '../../presentation/bloc/teacher_state.dart';

class TeacherDashboardTab extends StatelessWidget {
  const TeacherDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state as AuthAuthenticated?;
    final teacherName = authState?.user.name ?? '';

    return BlocBuilder<TeacherBloc, TeacherState>(
      builder: (context, state) {
        final halaqat = state.halaqat;
        final nextHalaqa = halaqat.isNotEmpty ? halaqat.first : null;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            if (authState != null) {
              context.read<TeacherBloc>().add(
                LoadTeacherHalaqatEvent(authState.user.uid),
              );
              await Future.delayed(const Duration(milliseconds: 800));
            }
          },
          child: CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _TeacherHeader(
                  name: teacherName,
                  halaqaName: nextHalaqa?.name ?? '',
                ),
              ),

              // ── Stats Cards ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingM,
                    16,
                    AppSizes.paddingM,
                    0,
                  ),
                  child: _TeacherStatsGrid(state: state),
                ),
              ),

              // ── الجلسة الحالية ─────────────────────────────────
              if (nextHalaqa != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.paddingM,
                      16,
                      AppSizes.paddingM,
                      0,
                    ),
                    child: _CurrentSessionCard(
                      halaqaName: nextHalaqa.name,
                      studentsCount: nextHalaqa.studentIds.length,
                      meetingLink: nextHalaqa.meetingLink,
                      onStartTap: () {},
                    ),
                  ),
                ),

              // ── إعلان إداري (placeholder) ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.paddingM,
                    16,
                    AppSizes.paddingM,
                    0,
                  ),
                  child: _AdminAnnouncementCard(),
                ),
              ),

              // ── النشاطات الأخيرة ────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSizes.paddingM,
                    16,
                    AppSizes.paddingM,
                    8,
                  ),
                  child: SectionHeader(
                    title: 'النشاطات الأخيرة',
                    actionLabel: 'الكل',
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.paddingM,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _ActivityItem(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary,
                      title: 'تقييم أحمد محمد — ممتاز',
                      subtitle: 'سورة الملك، الآيات ١-١٠',
                      time: 'منذ ١٣ دقيقة',
                    ),
                    const _ActivityItem(
                      icon: Icons.event_note_rounded,
                      color: AppColors.secondary,
                      title: 'تسجيل الحضور — حلقة الفجر',
                      subtitle: '١٢ حاضر، ٢ غائب',
                      time: 'منذ ساعتين',
                    ),
                    const _ActivityItem(
                      icon: Icons.star_rounded,
                      color: AppColors.success,
                      title: 'منح شارة "المتفوق" لسارة علي',
                      subtitle: 'إنجاز حفظ جزء عم',
                      time: 'أمس',
                    ),
                  ]),
                ),
              ),

              // ── المساعد الذكي ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  child: _SmartAssistantCard(
                    onRaiseTap: () => context.push('/teacher/evaluations'),
                    onAssignTap: () => context.push('/teacher/assignment'),
                    onAtRiskTap: () => context.push('/teacher/at-risk'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                onPressed: () {},
              ),
              Row(
                children: [
                  // اسم + حلقة
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
                  // avatar
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
              NotificationBadge(
                count: 3,
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {},
                ),
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
// _TeacherStatsGrid - الأرقام الأربعة
// ══════════════════════════════════════════════════════════════════════════════

class _TeacherStatsGrid extends StatelessWidget {
  final TeacherState state;

  const _TeacherStatsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final totalStudents = state.halaqat.fold<int>(
      0,
      (sum, h) => sum + h.studentIds.length,
    );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatCard(
          value: '$totalStudents',
          label: 'إجمالي الطلاب',
          icon: Icons.person_outline_rounded,
          color: AppColors.primaryLight,
          iconColor: AppColors.primary,
        ),
        _StatCard(
          value: '${state.halaqat.length}',
          label: 'حصص اليوم',
          icon: Icons.calendar_today_outlined,
          color: const Color(0xFFE8F5E9),
          iconColor: AppColors.success,
        ),
        const _StatCard(
          value: '٨',
          label: 'رسائل جديدة',
          icon: Icons.chat_bubble_outline_rounded,
          color: Color(0xFFF3E5F5),
          iconColor: Color(0xFF9C27B0),
        ),
        const _StatCard(
          value: '٥',
          label: 'مهام معلقة',
          icon: Icons.assignment_outlined,
          color: AppColors.secondaryBg,
          iconColor: AppColors.secondary,
        ),
      ],
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
// _CurrentSessionCard - كارت الجلسة الحالية الداكن
// ══════════════════════════════════════════════════════════════════════════════

class _CurrentSessionCard extends StatelessWidget {
  final String halaqaName;
  final int studentsCount;
  final String meetingLink;
  final VoidCallback onStartTap;

  const _CurrentSessionCard({
    required this.halaqaName,
    required this.studentsCount,
    required this.meetingLink,
    required this.onStartTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time = '${now.hour}:${now.minute.toString().padLeft(2, '0')} مساءً';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Row(
        children: [
          // زرار ابدأ الجلسة
          GestureDetector(
            onTap: onStartTap,
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
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ابدأ الجلسة',
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

          // تفاصيل الجلسة
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'اليوم — $time',
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
// _AdminAnnouncementCard
// ══════════════════════════════════════════════════════════════════════════════

class _AdminAnnouncementCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'إعلان إداري',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Text(
            'تذكير: موعد رفع التقييمات الشهرية غداً قبل الساعة ١٢ ظهراً',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ActivityItem
// ══════════════════════════════════════════════════════════════════════════════

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // الوقت
          Text(time, style: AppTextStyles.labelSmall),
          const Spacer(),
          // التفاصيل
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // أيقونة
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SmartAssistantCard - المساعد الذكي (Image 4)
// ══════════════════════════════════════════════════════════════════════════════

class _SmartAssistantCard extends StatelessWidget {
  final VoidCallback onRaiseTap;
  final VoidCallback onAssignTap;
  final VoidCallback onAtRiskTap;

  const _SmartAssistantCard({
    required this.onRaiseTap,
    required this.onAssignTap,
    required this.onAtRiskTap,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'مساعد ذكي',
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ما الذي تريد إنجازه اليوم؟',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Text(
            'اقتراحات مخصصة بناءً على جدولك',
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
              _AssistantChip(label: 'طلابي في خطر', onTap: onAtRiskTap),
              _AssistantChip(label: 'إرسال مهمة', onTap: onAssignTap),
              _AssistantChip(label: 'رفع التقييمات', onTap: onRaiseTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AssistantChip({required this.label, required this.onTap});

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

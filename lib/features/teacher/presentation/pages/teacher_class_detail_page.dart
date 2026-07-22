import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/entities/halaqa_students_summary_entity.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';

class TeacherClassDetailPage extends StatefulWidget {
  final String halaqaId;

  const TeacherClassDetailPage({super.key, required this.halaqaId});

  @override
  State<TeacherClassDetailPage> createState() => _TeacherClassDetailPageState();
}

class _TeacherClassDetailPageState extends State<TeacherClassDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    context.read<TeacherBloc>().add(LoadHalaqaStudentsEvent(widget.halaqaId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherBloc, TeacherState>(
      builder: (context, state) {
        final halaqa = state.halaqat.isEmpty
            ? null
            : state.halaqat.firstWhere(
                (h) => h.id == widget.halaqaId,
                orElse: () => state.halaqat.first,
              );

        return Scaffold(
          backgroundColor: AppColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── Header التيل ──────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 140,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                title: Text(halaqa?.name ?? 'الحلقة'),
                flexibleSpace: FlexibleSpaceBar(
                  background: _HalaqaStatsHeader(state: state),
                ),
              ),

              // ── Tabs ─────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    tabAlignment: TabAlignment.start,
                    labelStyle: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'الطلاب'),
                      Tab(text: 'الحضور'),
                      Tab(text: 'التقييمات'),
                      Tab(text: 'المهام'),
                      Tab(text: 'المنشورات'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                // ── تاب الطلاب ─────────────────────────────────
                _StudentsTab(
                  state: state,
                  searchQuery: _searchQuery,
                  onSearch: (q) => setState(() => _searchQuery = q),
                  halaqaId: widget.halaqaId,
                ),
                // ── تاب الحضور ─────────────────────────────────
                Center(
                  child: AppButton(
                    label: 'فتح سجل الحضور',
                    onPressed: () =>
                        context.push('/teacher/attendance/${widget.halaqaId}'),
                    width: 200,
                  ),
                ),
                // Placeholders
                const Center(child: Text('التقييمات')),
                const Center(child: Text('المهام')),
                const Center(child: Text('المنشورات')),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HalaqaStatsHeader - الإحصائيات في الأعلى
// ══════════════════════════════════════════════════════════════════════════════

class _HalaqaStatsHeader extends StatelessWidget {
  final TeacherState state;

  const _HalaqaStatsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.paddingM,
          48,
          AppSizes.paddingM,
          AppSizes.paddingM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _HeaderStat(value: '%٨٧', label: 'متوسط الأداء'),
            const _HeaderStat(value: '%٩٢', label: 'نسبة الحضور'),
            _HeaderStat(value: '${state.students.length}', label: 'طالب'),
          ],
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeaderStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StudentsTab - قائمة الطلاب (Image 6)
// ══════════════════════════════════════════════════════════════════════════════

class _StudentsTab extends StatelessWidget {
  final TeacherState state;
  final String searchQuery;
  final void Function(String) onSearch;
  final String halaqaId;

  const _StudentsTab({
    required this.state,
    required this.searchQuery,
    required this.onSearch,
    required this.halaqaId,
  });

  @override
  Widget build(BuildContext context) {
    if (state.studentsStatus == SectionStatus.loading) {
      return const AppLoadingWidget();
    }

    final students = searchQuery.isEmpty
        ? state.students
        : state.students.where((s) => s.name.contains(searchQuery)).toList();

    return Column(
      children: [
        // بحث
        Padding(
          padding: const EdgeInsets.all(AppSizes.paddingM),
          child: AppTextField(
            hint: 'بحث في الطلاب...',
            onChanged: onSearch,
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textHint,
            ),
          ),
        ),

        // القائمة
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
            itemCount: students.length + 1, // +1 لزرار إضافة طالب
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == students.length) {
                return _AddStudentButton(halaqaId: halaqaId);
              }
              return _StudentCard(
                student: students[i],
                halaqaId: halaqaId,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _StudentCard - كارت الطالب مع أزراره
// ══════════════════════════════════════════════════════════════════════════════

class _StudentCard extends StatelessWidget {
  final HalaqaStudentSummaryEntity student;
  final String halaqaId;

  const _StudentCard({required this.student, required this.halaqaId});

  Color get _levelColor {
    if (student.attendancePercent >= 90) return AppColors.success;
    if (student.attendancePercent >= 70) return AppColors.secondary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              // الأزرار
              Row(
                children: [
                  if (student.isAtRisk)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: _TagChip(
                        label: 'في خطر',
                        color: Color(0xFFFFEBEE),
                        textColor: AppColors.error,
                      ),
                    ),
                  _OutlinedChip(
                    label: 'منح شارة',
                    onTap: () =>
                        context.push('/teacher/halaqa/$halaqaId/awards'),
                    icon: Icons.star_outline_rounded,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  _OutlinedChip(
                    label: 'تقييم',
                    onTap: () {},
                    icon: Icons.rate_review_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _OutlinedChip(
                    label: 'الملف الشخصي',
                    onTap: () =>
                        context.push('/teacher/student/${student.uid}'),
                    icon: Icons.person_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              const Spacer(),

              // الاسم + المستوى
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(student.name, style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${student.attendancePercent.toInt()}% حضور',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _levelColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _levelColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _TagChip(
                        label: 'المستوى ${student.level}',
                        color: AppColors.primaryLight,
                        textColor: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(width: 12),

              // Avatar
              UserAvatar(name: student.name),
            ],
          ),

          // آخر تقييم
          if (student.lastGradeLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'آخر تقييم: ${student.lastGradeLabel}',
                style: AppTextStyles.labelSmall.copyWith(
                  color: student.isAtRisk
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],

          // تقدم الحفظ
          if (student.attendancePercent > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              child: LinearProgressIndicator(
                value: student.attendancePercent / 100,
                minHeight: 4,
                backgroundColor: AppColors.surfaceGrey,
                valueColor: AlwaysStoppedAnimation(_levelColor),
              ),
            ),
          ],

          // زرار تواصل مع الأهل (للطلاب في خطر)
          if (student.isAtRisk) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.message_outlined,
                  size: 16,
                  color: AppColors.error,
                ),
                label: const Text(
                  'تواصل مع الأهل',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'NotoNaskhArabic',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _OutlinedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final Color color;

  const _OutlinedChip({
    required this.label,
    required this.onTap,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AddStudentButton extends StatelessWidget {
  final String halaqaId;

  const _AddStudentButton({required this.halaqaId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary.withOpacity(0.4),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'إضافة طالب',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TabBar Delegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(_, __, ___) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

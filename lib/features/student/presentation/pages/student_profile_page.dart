import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/presentation/bloc/teacher_bloc.dart';

class StudentProfilePage extends StatelessWidget {
  final String studentId;

  const StudentProfilePage({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final state = context.read<TeacherBloc>().state;
    final student = state.students.firstWhere(
      (s) => s.uid == studentId,
      orElse: () => state.students.isNotEmpty
          ? state.students.first
          : const HalaqaStudentSummaryEntity(uid: '', name: 'طالب'),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header التيل ──────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.access_time_rounded),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _StudentProfileHeader(student: student),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── الإحصائيات الثلاث ─────────────────────────
                Row(
                  children: [
                    const _StatBox(value: '٣٤٠', label: 'آية حفظ'),
                    const SizedBox(width: 12),
                    const _StatBox(value: '١٥', label: 'يوم متتالي'),
                    const SizedBox(width: 12),
                    _StatBox(
                      value: '${student.attendancePercent.toInt()}%',
                      label: 'الحضور',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── أزرار الإجراءات ────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final teacherState =
                              context.read<TeacherBloc>().state;
                          final halaqaId = teacherState.selectedHalaqaId ??
                              (teacherState.halaqat.isNotEmpty
                                  ? teacherState.halaqat.first.id
                                  : null);
                          if (halaqaId == null) {
                            AppSnackBar.showInfo(
                              context,
                              'لا توجد حلقة مسندة إليك',
                            );
                            return;
                          }
                          context.push('/teacher/halaqa/$halaqaId/awards');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          side: const BorderSide(color: AppColors.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.star_border_rounded, size: 18),
                        label: const Text(
                          'منح جائزة',
                          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text(
                          'تواصل مع الأهل',
                          style: TextStyle(fontFamily: 'NotoNaskhArabic'),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── معلومات الطالب ─────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'معلومات الطالب',
                            style: AppTextStyles.titleMedium,
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _InfoRow(label: 'الاسم الكامل', value: student.name),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'ولي الأمر',
                        value: 'خالد ${student.name}',
                      ),
                      const SizedBox(height: 10),
                      const _InfoRow(label: 'الهاتف', value: '٠٥١٢٣٤٥٦٧'),
                      const SizedBox(height: 10),
                      const _InfoRow(
                        label: 'الخطة الحالية',
                        value: 'جزء تبارك',
                      ),
                      const SizedBox(height: 10),
                      const _InfoRow(
                        label: 'تاريخ الانضمام',
                        value: 'سبتمبر ٢٠٢٤',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── تقدم الحفظ ─────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SectionHeader(
                        title: 'تقدم الحفظ',
                        actionLabel: 'التفاصيل',
                        onAction: () {},
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '٧٨%',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            '٤٣٦ / ٣٤٠ آية',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        child: const LinearProgressIndicator(
                          value: 0.78,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceGrey,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── آخر تقييم ──────────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SectionHeader(
                        title: 'آخر تقييم',
                        actionLabel: null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GradeChip(label: RecitationGrade.veryGood.label),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gradeExcellent,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusM,
                              ),
                            ),
                            child: const Text(
                              'ممتاز',
                              style: TextStyle(
                                fontFamily: 'NotoNaskhArabic',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _StudentProfileHeader extends StatelessWidget {
  final HalaqaStudentSummaryEntity student;

  const _StudentProfileHeader({required this.student});

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserAvatar(name: student.name, size: AppSizes.avatarXL),
            const SizedBox(height: 12),
            Text(
              student.name,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'المستوى ${student.level} · حلقة المتقدمين',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSmall),
          ],
        ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value, style: AppTextStyles.titleMedium),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

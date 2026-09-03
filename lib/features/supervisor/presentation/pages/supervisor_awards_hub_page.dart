import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/achievement_entity.dart';
import '../../../student/domain/usecases/get_achievements_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../supervisor_destinations.dart';
import '../widgets/supervisor_loading_skeletons.dart';

const kSupervisorAwardTypeExamples = ['star', 'badge', 'certificate'];

class _AwardTypeDef {
  final String typeKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;

  const _AwardTypeDef({
    required this.typeKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
  });
}

const _awardTypes = <_AwardTypeDef>[
  _AwardTypeDef(
    typeKey: 'star',
    title: 'نجوم الأداء',
    subtitle: 'تقدير الأداء المتميز',
    icon: Icons.star_rounded,
    color: AppColors.gradeGood,
    badge: 'أكثر استخداماً',
  ),
  _AwardTypeDef(
    typeKey: 'badge',
    title: 'شارة الإتمام',
    subtitle: 'إكمال مرحلة أو هدف',
    icon: Icons.verified_rounded,
    color: AppColors.gradeExcellent,
  ),
  _AwardTypeDef(
    typeKey: 'weekly',
    title: 'طالب الأسبوع',
    subtitle: 'تميز أسبوعي',
    icon: Icons.person_rounded,
    color: AppColors.primary,
  ),
  _AwardTypeDef(
    typeKey: 'certificate',
    title: 'شهادة تقدير',
    subtitle: 'شهادة رسمية',
    icon: Icons.workspace_premium_rounded,
    color: AppColors.awardWeekly,
  ),
];

class _RecentAward {
  final String studentId;
  final String studentName;
  final AchievementEntity achievement;

  const _RecentAward({
    required this.studentId,
    required this.studentName,
    required this.achievement,
  });
}

class SupervisorAwardsHubPage extends StatefulWidget {
  const SupervisorAwardsHubPage({super.key});

  @override
  State<SupervisorAwardsHubPage> createState() =>
      _SupervisorAwardsHubPageState();
}

class _SupervisorAwardsHubPageState extends State<SupervisorAwardsHubPage> {
  bool _loading = true;
  List<_RecentAward> _recent = const [];
  int _monthCount = 0;
  int _beneficiaryCount = 0;
  int _certificateCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    setState(() => _loading = true);

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    for (final h in halaqat) {
      final result = await sl<GetHalaqaStudentsUseCase>()(
        HalaqaStudentsParams(h.id),
      );
      if (!mounted) return;
      result.fold((_) {}, (list) => byHalaqa[h.id] = list);
    }

    final roster = SupervisorRoster.mergeSummaries(
      halaqat: halaqat,
      byHalaqaId: byHalaqa,
    );

    final recent = <_RecentAward>[];
    final beneficiaries = <String>{};
    var monthCount = 0;
    var certCount = 0;
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month);

    final sample = roster.take(20).toList();
    for (final row in sample) {
      final result = await sl<GetAchievementsUseCase>()(
        StudentUidParams(row.studentId),
      );
      if (!mounted) return;
      result.fold((_) {}, (list) {
        for (final a in list) {
          recent.add(
            _RecentAward(
              studentId: row.studentId,
              studentName: row.displayName,
              achievement: a,
            ),
          );
          beneficiaries.add(row.studentId);
          if (!a.date.isBefore(monthStart)) monthCount++;
          if (a.type == AchievementType.certificate) certCount++;
        }
      });
    }

    recent.sort((a, b) => b.achievement.date.compareTo(a.achievement.date));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _recent = recent.take(12).toList();
      _monthCount = monthCount;
      _beneficiaryCount = beneficiaries.length;
      _certificateCount = certCount;
    });
  }

  String _typeLabel(AchievementType type) => switch (type) {
    AchievementType.star => 'نجمة تميز',
    AchievementType.badge => 'شارة',
    AchievementType.certificate => 'شهادة',
    _ => type.name,
  };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'أنواع الجوائز',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _awardTypes.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.05,
                          ),
                      itemBuilder: (context, i) {
                        final t = _awardTypes[i];
                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () =>
                                SupervisorDestinations.grantAward(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (t.badge != null)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.gradeGood.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppSizes.radiusFull,
                                          ),
                                        ),
                                        child: Text(
                                          t.badge!,
                                          style: AppTextStyles.labelSmall
                                              .copyWith(
                                                color: AppColors.gradeGood,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 9,
                                              ),
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: t.color.withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(t.icon, color: t.color),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    t.title,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    t.subtitle,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'آخر الجوائز الممنوحة',
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              SupervisorDestinations.grantAward(context),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('منح جائزة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loading)
                      const SizedBox(
                        height: 220,
                        child: SupervisorListCardsSkeleton(itemCount: 3),
                      )
                    else if (_recent.isEmpty)
                      AppCard(
                        child: Text(
                          'لا توجد إنجازات حديثة — استخدم زر المنح للبدء',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      )
                    else
                      ..._recent.map(
                        (item) => _RecentAwardTile(
                          item: item,
                          typeLabel: _typeLabel(item.achievement.type),
                          onTap: () => SupervisorDestinations.grantAward(
                            context,
                            preselectedStudentId: item.studentId,
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      color: AppColors.dark,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 0),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => SupervisorDestinations.grantAward(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gradeGood,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'جائزة جديدة',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'الإنجازات والجوائز',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: _HeaderStatPill(
                    value: '$_monthCount',
                    label: 'جوائز هذا الشهر',
                    valueColor: AppColors.gradeGood,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderStatPill(
                    value: '$_beneficiaryCount',
                    label: 'طالب مستفيد',
                    valueColor: AppColors.gradeVeryGood,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeaderStatPill(
                    value: '$_certificateCount',
                    label: 'شهادة أُهديت',
                    valueColor: AppColors.gradeExcellent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _HeaderStatPill({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAwardTile extends StatelessWidget {
  final _RecentAward item;
  final String typeLabel;
  final VoidCallback onTap;

  const _RecentAwardTile({
    required this.item,
    required this.typeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = item.studentName.isNotEmpty ? item.studentName[0] : 'ط';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: AppColors.primary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.studentName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${item.achievement.title} · $typeLabel',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

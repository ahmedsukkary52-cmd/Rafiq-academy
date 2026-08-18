import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/achievement_entity.dart';
import '../../../student/domain/entities/recitation_record_entity.dart';
import '../../../student/domain/entities/student_profile_entity.dart';
import '../../../student/domain/student_profile_latest_evaluation.dart';
import '../../../student/domain/usecases/get_achievements_usecase.dart';
import '../../../student/domain/usecases/get_recitation_records_usecase.dart';
import '../../../student/domain/usecases/get_student_profile_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../../domain/parent_household.dart';
import '../../domain/parent_performance.dart';
import '../bloc/parent_bloc.dart';
import '../parent_destinations.dart';
import '../parent_display.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_user_avatar.dart';

class ParentChildProfilePage extends StatefulWidget {
  final String studentId;
  final String? studentName;

  const ParentChildProfilePage({
    super.key,
    required this.studentId,
    this.studentName,
  });

  @override
  State<ParentChildProfilePage> createState() => _ParentChildProfilePageState();
}

class _ParentChildProfilePageState extends State<ParentChildProfilePage> {
  bool _loading = true;
  String? _error;
  StudentProfileEntity? _profile;
  StudentProfileLatestEvaluation? _latest;
  double? _performance;
  List<AchievementEntity> _achievements = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = StudentUidParams(widget.studentId);
    final profileResult = await sl<GetStudentProfileUseCase>()(uid);
    final recitationsResult = await sl<GetRecitationRecordsUseCase>()(uid);
    final achievementsResult = await sl<GetAchievementsUseCase>()(uid);
    if (!mounted) return;

    profileResult.fold((f) {
      setState(() {
        _loading = false;
        _error = f.message;
      });
    }, (profile) {
      final records = recitationsResult.getOrElse(
        (_) => const <RecitationRecordEntity>[],
      );
      setState(() {
        _loading = false;
        _profile = profile;
        _latest = pickLatestStudentProfileEvaluation(records);
        _performance = ParentPerformance.averagePercent(records);
        _achievements = achievementsResult.getOrElse(
          (_) => const <AchievementEntity>[],
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<ParentBloc, ParentChildSnapshot?>(
      (bloc) => bloc.state.snapshotFor(widget.studentId),
    );
    final name = (_profile?.name.trim().isNotEmpty == true)
        ? _profile!.name.trim()
        : (snapshot?.displayName ??
              ((widget.studentName ?? '').trim().isEmpty
                  ? 'ملف الطالب'
                  : widget.studentName!.trim()));
    final halaqa = (_profile?.halaqaName.trim().isNotEmpty == true)
        ? _profile!.halaqaName.trim()
        : (snapshot?.halaqaName.trim() ?? '');
    final teacher = snapshot?.teacherName.trim() ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _loading
            ? const ParentDashboardSkeleton()
            : _error != null
            ? AppErrorWidget(message: _error!, onRetry: _load)
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'ملف الطالب',
                                    style: AppTextStyles.headlineMedium
                                        .copyWith(color: AppColors.onPrimary),
                                  ),
                                  const Spacer(),
                                  const SizedBox(width: 48),
                                ],
                              ),
                              ParentUserAvatar(
                                name: name,
                                imageUrl:
                                    _profile?.profileImageUrl ??
                                    snapshot?.profileImageUrl,
                                radius: 40,
                                backgroundColor: AppColors.onPrimary,
                                foregroundColor: AppColors.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                name,
                                style: AppTextStyles.headlineLarge.copyWith(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                              Text(
                                [
                                  if (halaqa.isNotEmpty) halaqa,
                                  if (teacher.isNotEmpty) 'المعلم: $teacher',
                                ].join(' · '),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.onPrimaryMuted,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusL,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                _Stat(
                                  value: _performance == null
                                      ? '—'
                                      : '${_performance!.round()}%',
                                  label: 'الأداء',
                                ),
                                _Stat(
                                  value:
                                      '${_profile?.totalVersesMemorized ?? snapshot?.totalVersesMemorized ?? 0}',
                                  label: 'آيات',
                                ),
                                _Stat(
                                  value: parentAttendanceLabel(
                                    snapshot?.todayAttendanceStatus,
                                  ),
                                  label: 'اليوم',
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => ParentDestinations.schedule(
                                  context,
                                  studentId: widget.studentId,
                                  studentName: name,
                                ),
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: const Text('الجدول'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => ParentDestinations.evaluations(
                                  context,
                                  studentId: widget.studentId,
                                  studentName: name,
                                ),
                                icon: const Icon(Icons.fact_check_outlined),
                                label: const Text('عرض التقييمات'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoCard(
                          title: 'تقدم الحفظ',
                          body: _profile == null
                              ? 'لا تتوفر بيانات ملف الطالب بعد.'
                              : 'نسبة السورة الحالية ${_profile!.overallProgressPercent.round()}٪ — ${_profile!.totalVersesMemorized} آية محفوظة.',
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: 'الملاحظات',
                          body: (_latest?.notes ?? '').trim().isEmpty
                              ? 'لا توجد ملاحظة من المعلم في آخر تقييم معتمد.'
                              : _latest!.notes!.trim(),
                        ),
                        const SizedBox(height: 12),
                        _InfoCard(
                          title: 'آخر النشاطات',
                          body: _achievements.isEmpty
                              ? 'لا توجد إنجازات ممنوحة من المعلم بعد.'
                              : _achievements
                                    .take(3)
                                    .map((a) => a.title)
                                    .join(' · '),
                          actionLabel: 'الكل',
                          onAction: () => ParentDestinations.achievements(
                            context,
                            studentId: widget.studentId,
                            studentName: name,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.titleLarge),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoCard({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (actionLabel != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              const Spacer(),
              Text(title, style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

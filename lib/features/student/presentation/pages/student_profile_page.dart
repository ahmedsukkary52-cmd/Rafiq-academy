import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../teacher/presentation/bloc/teacher_bloc.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/usecases/get_student_halaqa_usecase.dart';
import '../../domain/usecases/get_student_profile_usecase.dart';
import '../../domain/usecases/watch_latest_assignment_usecase.dart';

class StudentProfilePage extends StatefulWidget {
  final String studentId;

  const StudentProfilePage({super.key, required this.studentId});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  SectionStatus _status = SectionStatus.initial;
  StudentProfileEntity? _profile;
  String? _halaqaName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = SectionStatus.loading;
      _error = null;
    });

    final result = await sl<GetStudentProfileUseCase>()(
      StudentUidParams(widget.studentId),
    );

    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() {
          _status = SectionStatus.error;
          _error = failure.message;
          _profile = null;
          _halaqaName = null;
        });
      },
      (profile) async {
        String? halaqaName = profile.halaqaName.trim().isNotEmpty
            ? profile.halaqaName
            : null;

        final halaqaId = profile.halaqaId;
        if ((halaqaName == null || halaqaName.isEmpty) &&
            halaqaId != null &&
            halaqaId.isNotEmpty) {
          final halaqaResult = await sl<GetStudentHalaqaUseCase>()(
            HalaqaIdParams(halaqaId),
          );
          halaqaResult.fold((_) {}, (halaqa) => halaqaName = halaqa.name);
        }

        if (!mounted) return;
        setState(() {
          _status = SectionStatus.loaded;
          _profile = profile;
          _halaqaName = halaqaName;
          _error = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_status == SectionStatus.loading ||
        _status == SectionStatus.initial) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: AppLoadingWidget(),
      );
    }

    if (_status == SectionStatus.error || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('ملف الطالب')),
        body: AppErrorWidget(
          message: _error ?? 'تعذر تحميل بيانات الطالب',
          onRetry: _load,
        ),
      );
    }

    final profile = _profile!;
    final progress = (profile.overallProgressPercent / 100).clamp(0.0, 1.0);
    final planName = profile.currentPlanName
        .trim()
        .isEmpty
        ? 'لا توجد خطة حالية'
        : profile.currentPlanName.trim();
    final halaqaLabel = (_halaqaName == null || _halaqaName!.trim().isEmpty)
        ? 'لا توجد حلقة'
        : _halaqaName!.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _StudentProfileHeader(
                name: profile.name,
                level: profile.level,
                halaqaName: halaqaLabel,
                profileImageUrl: profile.profileImageUrl,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    _StatBox(
                      value: '${profile.totalVersesMemorized}',
                      label: 'آية حفظ',
                    ),
                    const SizedBox(width: 12),
                    _StatBox(
                      value: '${profile.streakDays}',
                      label: 'يوم متتالي',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final teacherState = context
                          .read<TeacherBloc>()
                          .state;
                      final halaqaId = teacherState.selectedHalaqaId ??
                          (teacherState.halaqat.isNotEmpty
                              ? teacherState.halaqat.first.id
                              : null) ??
                          profile.halaqaId;
                      if (halaqaId == null || halaqaId.isEmpty) {
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
                const SizedBox(height: 16),
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
                      _InfoRow(
                        label: 'الاسم الكامل',
                        value: profile.name
                            .trim()
                            .isEmpty
                            ? 'طالب'
                            : profile.name.trim(),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'الخطة الحالية', value: planName),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SectionHeader(title: 'تقدم الحفظ'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${profile.overallProgressPercent.toInt()}%',
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusFull,
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceGrey,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primary,
                          ),
                        ),
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

class _StudentProfileHeader extends StatelessWidget {
  final String name;
  final int level;
  final String halaqaName;
  final String? profileImageUrl;

  const _StudentProfileHeader({
    required this.name,
    required this.level,
    required this.halaqaName,
    this.profileImageUrl,
  });

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
            UserAvatar(
              name: name,
              imageUrl: profileImageUrl,
              size: AppSizes.avatarXL,
            ),
            const SizedBox(height: 12),
            Text(
              name.isNotEmpty ? name : 'طالب',
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'المستوى $level · $halaqaName',
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
            Text(
              value,
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
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
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.left,
          ),
        ),
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

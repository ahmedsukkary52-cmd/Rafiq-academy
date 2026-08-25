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
import '../widgets/supervisor_subpage_scaffold.dart';

/// Extensible example types — not a closed catalog.
const kSupervisorAwardTypeExamples = ['star', 'badge', 'certificate'];

class SupervisorAwardsHubPage extends StatefulWidget {
  const SupervisorAwardsHubPage({super.key});

  @override
  State<SupervisorAwardsHubPage> createState() =>
      _SupervisorAwardsHubPageState();
}

class _SupervisorAwardsHubPageState extends State<SupervisorAwardsHubPage> {
  bool _loading = true;
  String? _error;
  List<_RecentAward> _recent = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    setState(() {
      _loading = true;
      _error = null;
    });

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
    // Cap lookups to keep hub responsive.
    final sample = roster.take(12).toList();
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
        }
      });
    }

    recent.sort((a, b) => b.achievement.date.compareTo(a.achievement.date));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _recent = recent.take(20).toList();
    });
  }

  String _typeLabel(AchievementType type) {
    final key = switch (type) {
      AchievementType.star => 'star',
      AchievementType.badge => 'badge',
      AchievementType.certificate => 'certificate',
      _ => type.name,
    };
    return key;
  }

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'الجوائز',
      actions: [
        IconButton(
          tooltip: 'منح جائزة',
          onPressed: () => SupervisorDestinations.grantAward(context),
          icon: const Icon(Icons.add_rounded, color: AppColors.primary),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FilledButton.icon(
            onPressed: () => SupervisorDestinations.grantAward(context),
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('منح جائزة'),
          ),
          const SizedBox(height: 16),
          Text(
            'أمثلة أنواع (قابلة للتوسعة)',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in kSupervisorAwardTypeExamples)
                Chip(label: Text(t), backgroundColor: AppColors.surfaceGrey),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'أحدث الإنجازات',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            AppErrorWidget(message: _error!, onRetry: _load)
          else if (_recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
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
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.achievement.title),
                subtitle: Text(
                  '${item.studentName} · ${_typeLabel(item.achievement.type)}',
                ),
                onTap: () => SupervisorDestinations.grantAward(
                  context,
                  preselectedStudentId: item.studentId,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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

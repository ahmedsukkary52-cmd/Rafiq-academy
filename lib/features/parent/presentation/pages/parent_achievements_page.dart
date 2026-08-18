import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/domain/entities/achievement_entity.dart';
import '../../../student/domain/usecases/get_achievements_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../bloc/parent_bloc.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentAchievementsPage extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ParentAchievementsPage({super.key, this.studentId, this.studentName});

  @override
  State<ParentAchievementsPage> createState() => _ParentAchievementsPageState();
}

class _ParentAchievementsPageState extends State<ParentAchievementsPage> {
  String? _studentId;
  bool _loading = true;
  String? _error;
  List<AchievementEntity> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<ParentBloc>().state;
      final id =
          widget.studentId ??
          state.selectedChildId ??
          (state.childrenIds.isNotEmpty ? state.childrenIds.first : null);
      setState(() => _studentId = id);
      _load(id);
    });
  }

  Future<void> _load(String? studentId) async {
    if (studentId == null) {
      setState(() {
        _loading = false;
        _items = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetAchievementsUseCase>()(
      StudentUidParams(studentId),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (items) => setState(() {
        _loading = false;
        _items = items;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ParentBloc>().state;
    final name = widget.studentName?.trim().isNotEmpty == true
        ? widget.studentName!.trim()
        : (_studentId == null ? '' : state.childDisplayName(_studentId!));

    return ParentSubpageScaffold(
      title: 'إنجازات أبنائي',
      backgroundColor: AppColors.dark,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              name.isEmpty ? 'لا يوجد طالب محدد.' : name,
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.onPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: _loading
                  ? const ParentListCardsSkeleton()
                  : _error != null
                  ? AppErrorWidget(
                      message: _error!,
                      onRetry: () => _load(_studentId),
                    )
                  : _items.isEmpty
                  ? const ParentEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'لا توجد إنجازات بعد',
                      message:
                          'تظهر هنا الجوائز التي يمنحها المعلم فقط. الضغط على الإنجاز لا يفتح صفحة أخرى.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(item.title, style: AppTextStyles.titleLarge),
                              if ((item.description ?? '').trim().isNotEmpty)
                                Text(
                                  item.description!.trim(),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                formatDateDmy(item.date),
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textHint,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

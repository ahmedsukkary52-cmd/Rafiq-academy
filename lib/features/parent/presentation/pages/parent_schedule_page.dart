import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../schedule/domain/entities/class_session_entity.dart';
import '../../../schedule/domain/usecases/get_weekly_sessions_usecase.dart';
import '../../domain/parent_household.dart';
import '../bloc/parent_bloc.dart';
import '../widgets/parent_loading_skeletons.dart';
import '../widgets/parent_subpage_scaffold.dart';

class ParentSchedulePage extends StatefulWidget {
  final String? studentId;
  final String? studentName;

  const ParentSchedulePage({super.key, this.studentId, this.studentName});

  @override
  State<ParentSchedulePage> createState() => _ParentSchedulePageState();
}

class _ParentSchedulePageState extends State<ParentSchedulePage> {
  String? _studentId;
  bool _loading = true;
  String? _error;
  List<ClassSessionEntity> _sessions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final state = context.read<ParentBloc>().state;
    final id =
        widget.studentId ??
        state.selectedChildId ??
        (state.childrenIds.isNotEmpty ? state.childrenIds.first : null);
    setState(() => _studentId = id);
    await _load(id, state.snapshotFor(id ?? ''));
  }

  Future<void> _load(String? studentId, ParentChildSnapshot? snapshot) async {
    if (studentId == null) {
      setState(() {
        _loading = false;
        _sessions = const [];
      });
      return;
    }
    final halaqaId = snapshot?.halaqaId?.trim() ?? '';
    if (halaqaId.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _sessions = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<GetWeeklySessionsUseCase>()(
      WeeklySessionsParams(halaqaId),
    );
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _loading = false;
        _error = f.message;
      }),
      (sessions) => setState(() {
        _loading = false;
        _sessions = sessions;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ParentBloc>().state;
    final name = widget.studentName?.trim().isNotEmpty == true
        ? widget.studentName!.trim()
        : (_studentId == null ? '' : state.childDisplayName(_studentId!));
    final snapshot = _studentId == null ? null : state.snapshotFor(_studentId!);

    return ParentSubpageScaffold(
      title: 'الجدول الأسبوعي',
      body: _loading
          ? const ParentListCardsSkeleton()
          : _error != null
          ? AppErrorWidget(
              message: _error!,
              onRetry: () => _load(_studentId, snapshot),
            )
          : _sessions.isEmpty
          ? ParentEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'جدول الأسبوع الحالي',
              message: name.isEmpty
                  ? 'لا توجد جلسات من جدول الحلقة لهذا الأسبوع. لا انضمام ولا تذكير يدوي.'
                  : 'لا توجد جلسات لـ $name هذا الأسبوع. لا انضمام ولا تذكير يدوي.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final teacher = session.teacherName.trim().isNotEmpty
                    ? session.teacherName
                    : (snapshot?.teacherName ?? '');
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(session.title, style: AppTextStyles.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        '${formatDateDmy(session.startAt)} · ${formatTimeHm12Ar(session.startAt)} — ${formatTimeHm12Ar(session.endAt)}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (teacher.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          teacher,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

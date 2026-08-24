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
import '../parent_child_access.dart';
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

  static const _weekdays = [
    '',
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

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
    final parentState = context
        .read<ParentBloc>()
        .state;
    if (!ParentChildAccess.owns(state: parentState, studentId: studentId)) {
      setState(() {
        _loading = false;
        _error = ParentChildAccess.deniedMessage;
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
        _sessions =
        [...sessions]..sort((a, b) => a.startAt.compareTo(b.startAt));
      }),
    );
  }

  ClassSessionEntity? get _featured {
    final now = DateTime.now();
    for (final session in _sessions) {
      if (session.status == ClassSessionStatus.live) return session;
    }
    for (final session in _sessions) {
      if (session.startAt.isAfter(now) ||
          (session.startAt.year == now.year &&
              session.startAt.month == now.month &&
              session.startAt.day == now.day)) {
        return session;
      }
    }
    return _sessions.isEmpty ? null : _sessions.first;
  }

  String _dayLabel(DateTime date) {
    final name = _weekdays[date.weekday];
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month &&
        date.day == now.day) {
      return '$name — اليوم';
    }
    return name;
  }

  String _statusLabel(ClassSessionEntity session) {
    return switch (session.status) {
      ClassSessionStatus.live => 'جارية',
      ClassSessionStatus.upcoming => 'قادمة',
      ClassSessionStatus.ended => 'انتهت',
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ParentBloc>().state;
    final snapshot = _studentId == null ? null : state.snapshotFor(_studentId!);
    final featured = _featured;

    return ParentSubpageScaffold(
      title: 'الجدول الأسبوعي',
      body: _loading
          ? const ParentListCardsSkeleton()
          : _error != null
          ? AppErrorWidget(
              message: _error!,
              onRetry: () => _load(_studentId, snapshot),
            )
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (state.childrenIds.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final id in state.childrenIds) ...[
                    ParentFilterChip(
                      label: state.childDisplayName(id),
                      selected: _studentId == id,
                      onTap: () {
                        setState(() => _studentId = id);
                        _load(id, state.snapshotFor(id));
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          if (state.childrenIds.length > 1) const SizedBox(height: 12),
          if (_sessions.isEmpty)
            const SizedBox(
              height: 280,
              child: ParentEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'جدول الأسبوع الحالي',
                message: 'لا توجد جلسات من جدول الحلقة لهذا الأسبوع.',
              ),
            )
          else
            ...[
              if (featured != null) _TodayCard(
                  session: featured, snapshot: snapshot),
              const SizedBox(height: 12),
              for (final session in _sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionRow(
                    session: session,
                    dayLabel: _dayLabel(session.startAt),
                    statusLabel: _statusLabel(session),
                    teacher: session.teacherName
                        .trim()
                        .isNotEmpty
                        ? session.teacherName
                        : (snapshot?.teacherName ?? ''),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final ClassSessionEntity session;
  final ParentChildSnapshot? snapshot;

  const _TodayCard({required this.session, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final halaqa = snapshot?.halaqaName.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'الجلسة القادمة',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.onPrimaryMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatTimeHm12Ar(session.startAt),
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 32,
            ),
          ),
          Text(
            session.topic
                ?.trim()
                .isNotEmpty == true
                ? session.topic!.trim()
                : session.title,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          if (halaqa.isNotEmpty)
            Text(
              halaqa,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onPrimaryMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ClassSessionEntity session;
  final String dayLabel;
  final String statusLabel;
  final String teacher;

  const _SessionRow({
    required this.session,
    required this.dayLabel,
    required this.statusLabel,
    required this.teacher,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dayLabel,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textHint,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatTimeHm12Ar(session.startAt),
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (teacher.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                teacher,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

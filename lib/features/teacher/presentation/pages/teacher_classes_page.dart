import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../schedule/domain/entities/class_session_entity.dart';
import '../../../schedule/domain/mappers/halaqa_schedule_source_from_entity.dart';
import '../../../schedule/domain/mappers/halaqa_weekly_sessions_mapper.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../supervisor/domain/repositories/parent_repository.dart';
import '../../domain/read_models/teacher_day_agenda.dart';
import '../../domain/usecases/get_today_agenda_usecase.dart';
import '../bloc/teacher_bloc.dart';
import '../bloc/teacher_event.dart';
import '../bloc/teacher_state.dart';
import '../widgets/teacher_home_figma_cards.dart';
import '../widgets/teacher_loading_skeletons.dart';

/// Teacher «حلقاتي» — production list (search / filter / Firestore-backed cards).
class TeacherClassesPage extends StatefulWidget {
  const TeacherClassesPage({super.key});

  @override
  State<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

enum _ClassesFilter { all, active, today, dayOfWeek, nameAsc }

class _TeacherClassesPageState extends State<TeacherClassesPage> {
  static const _sessionsMapper = HalaqaWeeklySessionsMapper();

  final _searchController = TextEditingController();
  bool _searchOpen = false;
  String _query = '';
  _ClassesFilter _filter = _ClassesFilter.all;
  int? _weekdayFilter; // DateTime.monday…sunday when filter == dayOfWeek
  Map<String, String> _supervisorNames = {};
  bool _loadingNames = false;

  /// Halaqa id → Evaluation CTA enabled.
  /// Default false until resolved from W3 agenda + session status.
  Map<String, bool> _evaluationEnabledById = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = context.read<TeacherBloc>().state.halaqatStatus;
      if (status == SectionStatus.initial) {
        _loadHalaqat();
      } else if (status == SectionStatus.loaded) {
        final halaqat = context.read<TeacherBloc>().state.halaqat;
        _resolveSupervisorNames(halaqat);
        _resolveEvaluationEligibility(halaqat);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadHalaqat() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    context.read<TeacherBloc>().add(
      LoadTeacherHalaqatEvent(authState.user.uid),
    );
  }

  Future<void> _onRefresh() async {
    final bloc = context.read<TeacherBloc>();
    _loadHalaqat();
    final state = await bloc.stream.firstWhere(
      (s) =>
          s.halaqatStatus == SectionStatus.loaded ||
          s.halaqatStatus == SectionStatus.error,
    );
    if (state.halaqatStatus == SectionStatus.loaded) {
      await Future.wait([
        _resolveSupervisorNames(state.halaqat),
        _resolveEvaluationEligibility(state.halaqat),
      ]);
    }
  }

  Future<void> _resolveSupervisorNames(List<HalaqaEntity> halaqat) async {
    final ids = halaqat
        .map((h) => h.supervisorId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      if (mounted) setState(() => _supervisorNames = {});
      return;
    }
    setState(() => _loadingNames = true);
    final result = await sl<SupervisorRepository>().getUserDisplayNames(ids);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingNames = false),
      (names) => setState(() {
        _supervisorNames = names;
        _loadingNames = false;
      }),
    );
  }

  List<HalaqaEntity> _applyFilters(List<HalaqaEntity> source) {
    var list = List<HalaqaEntity>.from(source);

    final q = _query.trim();
    if (q.isNotEmpty) {
      list = list
          .where((h) => h.name.contains(q) || _supervisorMatch(h, q))
          .toList();
    }

    switch (_filter) {
      case _ClassesFilter.all:
        break;
      case _ClassesFilter.active:
        list = list.where((h) => h.isActive).toList();
        break;
      case _ClassesFilter.today:
        list = list.where(_meetsToday).toList();
        break;
      case _ClassesFilter.dayOfWeek:
        final day = _weekdayFilter;
        if (day != null) {
          list = list.where((h) => _meetsWeekday(h, day)).toList();
        }
        break;
      case _ClassesFilter.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    return list;
  }

  bool _supervisorMatch(HalaqaEntity h, String q) {
    final name = _supervisorNames[h.supervisorId]?.trim() ?? '';
    return name.contains(q);
  }

  bool _meetsToday(HalaqaEntity h) {
    final days = _sessionsMapper.mapTodayOperationalDays([
      halaqaScheduleSourceFromEntity(h),
    ]);
    return days.isNotEmpty;
  }

  bool _meetsWeekday(HalaqaEntity h, int weekday) {
    return h.schedule.any((s) => _weekdayFromLabel(s.day) == weekday);
  }

  /// Evaluation CTA — reuses W3 day agenda + schedule session status.
  ///
  /// Enabled only when:
  /// 1. this halaqa has a **today** operational session that has **ended**, and
  /// 2. readiness still has pending reviews (`TeacherAgendaAction.reviewRecitations`
  ///    from [GetTodayAgendaUseCase] / `HalaqaDayGapKind.reviewsPending`).
  ///
  /// Otherwise disabled (no session today, still upcoming/live, or nothing
  /// awaiting evaluation).
  Future<void> _resolveEvaluationEligibility(List<HalaqaEntity> halaqat) async {
    if (halaqat.isEmpty) {
      if (mounted) setState(() => _evaluationEnabledById = {});
      return;
    }

    final now = DateTime.now();
    final agendaEither = await sl<GetTodayAgendaUseCase>()(
      TodayAgendaParams(halaqat: halaqat, now: now),
    );
    if (!mounted) return;

    final awaitingReviewIds = agendaEither.fold<Set<String>>(
      (_) => <String>{},
      (agenda) => agenda.items
          .where(
            (item) => item.pendingActions.contains(
              TeacherAgendaAction.reviewRecitations,
            ),
          )
          .map((item) => item.halaqaId)
          .toSet(),
    );

    final enabled = <String, bool>{};
    for (final h in halaqat) {
      final days = _sessionsMapper.mapTodayOperationalDays(
        [halaqaScheduleSourceFromEntity(h)],
        now: now,
      );
      final sessionEnded = days.isNotEmpty &&
          days.first.session.status == ClassSessionStatus.ended;
      enabled[h.id] = sessionEnded && awaitingReviewIds.contains(h.id);
    }

    setState(() => _evaluationEnabledById = enabled);
  }

  bool _canEvaluate(HalaqaEntity h) =>
      _evaluationEnabledById[h.id] ?? false;

  String _evaluationDisabledMessage(HalaqaEntity h) {
    final days = _sessionsMapper.mapTodayOperationalDays([
      halaqaScheduleSourceFromEntity(h),
    ]);
    if (days.isEmpty ||
        days.first.session.status != ClassSessionStatus.ended) {
      return 'التقييم متاح بعد انتهاء جلسة اليوم';
    }
    return 'لا يوجد تسميع بانتظار التقييم';
  }

  Future<void> _openFilterSheet() async {
    final selected = await showModalBottomSheet<_ClassesFilterChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusL)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تصفية الحلقات',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _filterTile(
                    ctx,
                    label: 'الكل',
                    choice: const _ClassesFilterChoice(_ClassesFilter.all),
                    selected: _filter == _ClassesFilter.all,
                  ),
                  _filterTile(
                    ctx,
                    label: 'فعالة فقط',
                    choice: const _ClassesFilterChoice(_ClassesFilter.active),
                    selected: _filter == _ClassesFilter.active,
                  ),
                  _filterTile(
                    ctx,
                    label: 'حلقات اليوم',
                    choice: const _ClassesFilterChoice(_ClassesFilter.today),
                    selected: _filter == _ClassesFilter.today,
                  ),
                  _filterTile(
                    ctx,
                    label: 'ترتيب بالاسم',
                    choice: const _ClassesFilterChoice(_ClassesFilter.nameAsc),
                    selected: _filter == _ClassesFilter.nameAsc,
                  ),
                  const Divider(height: 24),
                  Text(
                    'حسب اليوم',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _weekdayOptions)
                        ChoiceChip(
                          label: Text(e.label),
                          selected: _filter == _ClassesFilter.dayOfWeek &&
                              _weekdayFilter == e.weekday,
                          selectedColor: AppColors.primaryLight,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: _filter == _ClassesFilter.dayOfWeek &&
                                    _weekdayFilter == e.weekday
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => Navigator.pop(
                            ctx,
                            _ClassesFilterChoice(
                              _ClassesFilter.dayOfWeek,
                              weekday: e.weekday,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _filter = selected.filter;
      _weekdayFilter = selected.weekday;
    });
  }

  Widget _filterTile(
    BuildContext ctx, {
    required String label,
    required _ClassesFilterChoice choice,
    required bool selected,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTextStyles.titleMedium.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: () => Navigator.pop(ctx, choice),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _ClassesHeader(
                searchOpen: _searchOpen,
                searchController: _searchController,
                onToggleSearch: () {
                  setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _searchController.clear();
                      _query = '';
                    }
                  });
                },
                onQueryChanged: (v) => setState(() => _query = v),
                onFilter: _openFilterSheet,
              ),
              if (_filter != _ClassesFilter.all)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InputChip(
                      label: Text(_filterChipLabel()),
                      onDeleted: () => setState(() {
                        _filter = _ClassesFilter.all;
                        _weekdayFilter = null;
                      }),
                      deleteIconColor: AppColors.primaryDark,
                      backgroundColor: AppColors.primaryLight,
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide.none,
                    ),
                  ),
                ),
              Expanded(
                child: BlocConsumer<TeacherBloc, TeacherState>(
                  listenWhen: (p, c) =>
                      p.halaqat != c.halaqat &&
                      c.halaqatStatus == SectionStatus.loaded,
                  listener: (context, state) {
                    _resolveSupervisorNames(state.halaqat);
                    _resolveEvaluationEligibility(state.halaqat);
                  },
                  buildWhen: (previous, current) =>
                      previous.halaqatStatus != current.halaqatStatus ||
                      previous.halaqat != current.halaqat ||
                      previous.halaqatError != current.halaqatError,
                  builder: (context, state) {
                    if (state.halaqatStatus == SectionStatus.loading ||
                        state.halaqatStatus == SectionStatus.initial) {
                      return const TeacherClassesListSkeleton();
                    }
                    if (state.halaqatStatus == SectionStatus.error) {
                      return AppErrorWidget(
                        message: state.halaqatError ?? 'حدث خطأ',
                        onRetry: _loadHalaqat,
                      );
                    }

                    final filtered = _applyFilters(state.halaqat);

                    if (state.halaqat.isEmpty) {
                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _onRefresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: const _EmptyHalaqat(),
                            ),
                          ],
                        ),
                      );
                    }

                    if (filtered.isEmpty) {
                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _onRefresh,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Text(
                                  'لا توجد حلقات مطابقة للبحث أو التصفية',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final halaqa = filtered[i];
                          final canEval = _canEvaluate(halaqa);
                          final vm = _ClassCardVm.fromHalaqa(
                            halaqa,
                            supervisorName:
                                _supervisorNames[halaqa.supervisorId],
                          );
                          return _ClassCard(
                            vm: vm,
                            evaluateEnabled: canEval,
                            onView: () {
                              context
                                  .read<TeacherBloc>()
                                  .add(SelectHalaqaEvent(halaqa.id));
                              context.push('/teacher/halaqa/${halaqa.id}');
                            },
                            onEvaluate: canEval
                                ? () => context.push(
                                      '/teacher/halaqa/${halaqa.id}/evaluations',
                                    )
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          _evaluationDisabledMessage(halaqa),
                                        ),
                                      ),
                                    );
                                  },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_loadingNames) const LinearProgressIndicator(minHeight: 2),
            ],
          ),
        ),
      ),
    );
  }

  String _filterChipLabel() => switch (_filter) {
    _ClassesFilter.active => 'فعالة فقط',
    _ClassesFilter.today => 'حلقات اليوم',
    _ClassesFilter.nameAsc => 'ترتيب بالاسم',
    _ClassesFilter.dayOfWeek =>
      _weekdayOptions
          .firstWhere(
            (e) => e.weekday == _weekdayFilter,
            orElse: () => (weekday: 0, label: 'يوم'),
          )
          .label,
    _ClassesFilter.all => 'الكل',
  };
}

class _ClassesFilterChoice {
  final _ClassesFilter filter;
  final int? weekday;

  const _ClassesFilterChoice(this.filter, {this.weekday});
}

const _weekdayOptions = <({int weekday, String label})>[
  (weekday: DateTime.sunday, label: 'الأحد'),
  (weekday: DateTime.monday, label: 'الاثنين'),
  (weekday: DateTime.tuesday, label: 'الثلاثاء'),
  (weekday: DateTime.wednesday, label: 'الأربعاء'),
  (weekday: DateTime.thursday, label: 'الخميس'),
  (weekday: DateTime.friday, label: 'الجمعة'),
  (weekday: DateTime.saturday, label: 'السبت'),
];

int? _weekdayFromLabel(String day) => switch (day.trim()) {
  'الأحد' || 'الاحد' => DateTime.sunday,
  'الاثنين' || 'الإثنين' => DateTime.monday,
  'الثلاثاء' => DateTime.tuesday,
  'الأربعاء' || 'الاربعاء' => DateTime.wednesday,
  'الخميس' => DateTime.thursday,
  'الجمعة' => DateTime.friday,
  'السبت' => DateTime.saturday,
  _ => null,
};

// ── Header ────────────────────────────────────────────────────────────────────

class _ClassesHeader extends StatelessWidget {
  final bool searchOpen;
  final TextEditingController searchController;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onFilter;

  const _ClassesHeader({
    required this.searchOpen,
    required this.searchController,
    required this.onToggleSearch,
    required this.onQueryChanged,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              _HeaderIconButton(
                icon: searchOpen ? Icons.close_rounded : Icons.search_rounded,
                onTap: onToggleSearch,
              ),
              Expanded(
                child: Text(
                  'حلقاتي',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HeaderIconButton(
                icon: Icons.tune_rounded,
                onTap: onFilter,
              ),
            ],
          ),
          if (searchOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              onChanged: onQueryChanged,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'بحث في الحلقات...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.softShadow,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: AppSizes.iconM, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ── Card VM ───────────────────────────────────────────────────────────────────

class _ClassCardVm {
  final String title;
  final String? supervisorLabel;
  final String daysLabel;
  final String timeLabel;
  final int studentCount;
  final bool isActive;
  final Color accent;
  final String statusLabel;

  const _ClassCardVm({
    required this.title,
    this.supervisorLabel,
    required this.daysLabel,
    required this.timeLabel,
    required this.studentCount,
    required this.isActive,
    required this.accent,
    required this.statusLabel,
  });

  factory _ClassCardVm.fromHalaqa(
    HalaqaEntity halaqa, {
    String? supervisorName,
  }) {
    final days = halaqa.schedule
        .map((s) => _dayShort(s.day))
        .where((d) => d.isNotEmpty)
        .toList();
    final daysLabel = days.isEmpty ? '—' : days.join('، ');
    final timeLabel = _firstStartTimeLabel(halaqa.schedule) ?? '—';
    final active = halaqa.isActive;
    final supervisor = supervisorName?.trim();
    final supervisorLabel = (supervisor == null || supervisor.isEmpty)
        ? null
        : 'المشرف: $supervisor';

    return _ClassCardVm(
      title: halaqa.name,
      supervisorLabel: supervisorLabel,
      daysLabel: daysLabel,
      timeLabel: timeLabel,
      studentCount: halaqa.studentIds.length,
      isActive: active,
      // Accent is visual identity only — no status/session semantics.
      accent: AppColors.primary,
      // Label maps existing `halaqat.status` (`active` ↔ isActive). No
      // suspended/archived vocabulary exists in the domain model.
      statusLabel: active ? 'فعالة' : 'غير فعالة',
    );
  }
}

String _dayShort(String day) => switch (day.trim()) {
  'الأحد' || 'الاحد' => 'أح',
  'الاثنين' || 'الإثنين' => 'إث',
  'الثلاثاء' => 'ثل',
  'الأربعاء' || 'الاربعاء' => 'أر',
  'الخميس' => 'خم',
  'الجمعة' => 'جم',
  'السبت' => 'سب',
  _ => day.trim().isEmpty ? '' : day.trim().substring(0, 1),
};

String? _firstStartTimeLabel(List<HalaqaScheduleEntity> schedule) {
  for (final slot in schedule) {
    final start = slot.startTime.trim();
    if (start.isEmpty) continue;
    return _formatClock(start);
  }
  return null;
}

String _formatClock(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return teacherHomeEasternDigits(hhmm);
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1].padLeft(2, '0');
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  final period = h < 12 ? 'ص' : 'م';
  return teacherHomeEasternDigits('$hour12:$m $period');
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final _ClassCardVm vm;
  final bool evaluateEnabled;
  final VoidCallback onView;
  final VoidCallback onEvaluate;

  const _ClassCard({
    required this.vm,
    required this.evaluateEnabled,
    required this.onView,
    required this.onEvaluate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: const [
          BoxShadow(
            color: AppColors.softShadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: vm.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            vm.title,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: vm.isActive
                                ? AppColors.primaryLight
                                : AppColors.surfaceGrey,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Text(
                            vm.statusLabel,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: vm.isActive
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (vm.supervisorLabel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              vm.supervisorLabel!,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${teacherHomeEasternDigits('${vm.studentCount}')} طالب',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${vm.daysLabel}  ·  ${vm.timeLabel}',
                            textAlign: TextAlign.left,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ClassActionButton(
                            label: 'عرض الحلقة',
                            background: AppColors.primary,
                            foreground: AppColors.onPrimary,
                            onTap: onView,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ClassActionButton(
                            label: 'تقييم',
                            background: evaluateEnabled
                                ? AppColors.secondaryBg
                                : AppColors.surfaceGrey,
                            foreground: evaluateEnabled
                                ? AppColors.secondary
                                : AppColors.textHint,
                            onTap: onEvaluate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassActionButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _ClassActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelMedium.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHalaqat extends StatelessWidget {
  const _EmptyHalaqat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_rounded,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد حلقات مسندة إليك',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

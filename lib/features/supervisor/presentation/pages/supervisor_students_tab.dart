import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';

enum _StudentFilter { all, atRisk, dual }

class SupervisorStudentsTab extends StatefulWidget {
  const SupervisorStudentsTab({super.key});

  @override
  State<SupervisorStudentsTab> createState() => _SupervisorStudentsTabState();
}

class _SupervisorStudentsTabState extends State<SupervisorStudentsTab> {
  final _searchCtrl = TextEditingController();
  _StudentFilter _filter = _StudentFilter.all;
  String _query = '';

  List<SupervisorStudentRow> _rows = const [];
  bool _loading = false;
  String? _error;
  int _loadGen = 0;
  String _halaqaKey = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q == _query) return;
      setState(() => _query = q);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncFromBloc(context.read<SupervisorBloc>().state);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reloadHalaqat() {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) return;
    context.read<SupervisorBloc>().add(
      LoadSupervisedHalaqatEvent(auth.user.uid),
    );
  }

  void _syncFromBloc(SupervisorState state) {
    if (state.halaqatStatus == SectionStatus.initial ||
        state.halaqatStatus == SectionStatus.loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
      return;
    }
    if (state.halaqatStatus == SectionStatus.error) {
      setState(() {
        _loading = false;
        _error = state.halaqatError ?? 'تعذر تحميل الحلقات';
        _rows = const [];
      });
      return;
    }
    final key = state.halaqat.map((h) => h.id).join('|');
    if (key == _halaqaKey && _rows.isNotEmpty) return;
    _halaqaKey = key;
    _loadSummaries(state);
  }

  Future<void> _loadSummaries(SupervisorState state) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (state.halaqat.isEmpty) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
      return;
    }

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    final getStudents = sl<GetHalaqaStudentsUseCase>();
    String? firstError;

    await Future.wait(
      state.halaqat.map((h) async {
        final result = await getStudents(HalaqaStudentsParams(h.id));
        result.fold(
          (f) => firstError ??= f.message,
          (list) => byHalaqa[h.id] = list,
        );
      }),
    );

    if (!mounted || gen != _loadGen) return;

    if (byHalaqa.isEmpty && firstError != null) {
      setState(() {
        _loading = false;
        _error = firstError;
        _rows = const [];
      });
      return;
    }

    setState(() {
      _rows = SupervisorRoster.mergeSummaries(
        halaqat: state.halaqat,
        byHalaqaId: byHalaqa,
      );
      _loading = false;
      _error = null;
    });
  }

  List<SupervisorStudentRow> get _visible {
    Iterable<SupervisorStudentRow> list = _rows;
    list = switch (_filter) {
      _StudentFilter.all => list,
      _StudentFilter.atRisk => list.where((r) => r.isAtRisk),
      _StudentFilter.dual => list.where((r) => r.isDualMember),
    };
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((r) {
        final hay = '${r.displayName} ${r.halaqaLabel}'.toLowerCase();
        return hay.contains(q);
      });
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.halaqatStatus != c.halaqatStatus || p.halaqat != c.halaqat,
      listener: (context, state) => _syncFromBloc(state),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => SupervisorDestinations.register(context),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('تسجيل طالب'),
          ),
          body: Column(
            children: [
              _Header(top: MediaQuery.paddingOf(context).top),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'بحث عن طالب...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    for (final (f, label) in const [
                      (_StudentFilter.all, 'الكل'),
                      (_StudentFilter.atRisk, 'في خطر'),
                      (_StudentFilter.dual, 'عضوية مزدوجة'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          selectedColor: AppColors.primaryLight,
                          labelStyle: AppTextStyles.labelMedium.copyWith(
                            color: _filter == f
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildList(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoadingWidget());
    }
    if (_error != null) {
      return AppErrorWidget(
        message: _error!,
        onRetry: () {
          final state = context.read<SupervisorBloc>().state;
          if (state.halaqatStatus == SectionStatus.error) {
            _reloadHalaqat();
          } else {
            _halaqaKey = '';
            _loadSummaries(state);
          }
        },
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'لا يوجد طلاب في حلقاتك بعد',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final items = _visible;
    if (items.isEmpty) {
      return Center(
        child: Text(
          'لا نتائج مطابقة',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _halaqaKey = '';
        await _loadSummaries(context.read<SupervisorBloc>().state);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final row = items[i];
          final halaqaId = row.halaqaIds.isNotEmpty
              ? row.halaqaIds.first
              : null;
          return _StudentTile(
            row: row,
            onTap: () => SupervisorDestinations.studentProfile(
              context,
              studentId: row.studentId,
              halaqaId: halaqaId,
            ),
            onGrantAward: () => SupervisorDestinations.grantAward(
              context,
              preselectedStudentId: row.studentId,
              preselectedHalaqaId: halaqaId,
            ),
            onTransfer: () => SupervisorDestinations.transfer(
              context,
              studentId: row.studentId,
              sourceHalaqaId: halaqaId,
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double top;

  const _Header({required this.top});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12),
      child: Text(
        'الطلاب',
        textAlign: TextAlign.center,
        style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final SupervisorStudentRow row;
  final VoidCallback onTap;
  final VoidCallback onGrantAward;
  final VoidCallback onTransfer;

  const _StudentTile({
    required this.row,
    required this.onTap,
    required this.onGrantAward,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            backgroundImage:
                row.profileImageUrl != null && row.profileImageUrl!.isNotEmpty
                ? NetworkImage(row.profileImageUrl!)
                : null,
            child: row.profileImageUrl == null || row.profileImageUrl!.isEmpty
                ? Text(
                    row.displayName.isNotEmpty ? row.displayName[0] : '؟',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (row.isAtRisk) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'في خطر',
                        bg: Color(0xFFFFE8EE),
                        fg: AppColors.error,
                      ),
                    ],
                    if (row.isDualMember) ...[
                      const SizedBox(width: 6),
                      const _Badge(
                        label: 'مزدوج',
                        bg: Color(0xFFE8F0FF),
                        fg: AppColors.info,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  row.halaqaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'award') onGrantAward();
              if (v == 'transfer') onTransfer();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'award', child: Text('منح جائزة')),
              PopupMenuItem(value: 'transfer', child: Text('نقل')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

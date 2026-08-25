import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../analytics/domain/usecases/analytics_usecases.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/entities/supervisor_report_entity.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';

class SupervisorReportsTab extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const SupervisorReportsTab({super.key, this.onSwitchTab});

  @override
  State<SupervisorReportsTab> createState() => _SupervisorReportsTabState();
}

class _HalaqaReportCard {
  final HalaqaEntity halaqa;
  final int studentCount;
  final int atRiskCount;
  final double? attendancePercent;

  const _HalaqaReportCard({
    required this.halaqa,
    required this.studentCount,
    required this.atRiskCount,
    this.attendancePercent,
  });
}

class _SupervisorReportsTabState extends State<SupervisorReportsTab> {
  List<_HalaqaReportCard> _cards = const [];
  bool _loading = false;
  String? _error;
  int _loadGen = 0;
  String _halaqaKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(context.read<SupervisorBloc>().state);
    });
  }

  void _sync(SupervisorState state) {
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
        _cards = const [];
      });
      return;
    }
    final key = state.halaqat.map((h) => h.id).join('|');
    if (key == _halaqaKey && _cards.isNotEmpty) return;
    _halaqaKey = key;
    _load(state.halaqat);
  }

  Future<void> _load(List<HalaqaEntity> halaqat) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });

    if (halaqat.isEmpty) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _cards = const [];
        _loading = false;
      });
      return;
    }

    final getStudents = sl<GetHalaqaStudentsUseCase>();
    final getAtRisk = sl<GetAtRiskStudentsUseCase>();
    final getAnalytics = sl<GetHalaqaAnalyticsUseCase>();
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    final atRiskByHalaqa = <String, int>{};
    final attendanceByHalaqa = <String, double>{};

    await Future.wait(
      halaqat.map((h) async {
        final summaries = await getStudents(HalaqaStudentsParams(h.id));
        summaries.fold((_) {}, (list) => byHalaqa[h.id] = list);

        final risk = await getAtRisk(HalaqaIdParams(h.id));
        risk.fold((_) {}, (list) => atRiskByHalaqa[h.id] = list.length);

        final analytics = await getAnalytics(
          HalaqaAnalyticsParams(halaqaId: h.id, from: from, to: now),
        );
        analytics.fold(
          (_) {},
          (a) => attendanceByHalaqa[h.id] = a.attendancePercent,
        );
      }),
    );

    if (!mounted || gen != _loadGen) return;

    final merged = SupervisorRoster.mergeSummaries(
      halaqat: halaqat,
      byHalaqaId: byHalaqa,
    );

    final cards = halaqat.map((h) {
      final fromRoster = merged
          .where((r) => r.halaqaIds.contains(h.id) && r.isAtRisk)
          .length;
      final atRisk = atRiskByHalaqa[h.id] ?? fromRoster;
      return _HalaqaReportCard(
        halaqa: h,
        studentCount: h.studentIds.length,
        atRiskCount: atRisk,
        attendancePercent: attendanceByHalaqa[h.id],
      );
    }).toList();

    setState(() {
      _cards = cards;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _composeReport(BuildContext context) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تقرير مشرف'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: 'اكتب محتوى التقرير...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (content == null || content.isEmpty || !context.mounted) return;

    context.read<SupervisorBloc>().add(
      SubmitSupervisorReportEvent(
        SupervisorReportEntity(
          id: '',
          supervisorId: auth.user.uid,
          type: 'periodic',
          content: content,
          date: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) =>
          p.halaqatStatus != c.halaqatStatus || p.halaqat != c.halaqat,
      listener: (context, state) => _sync(state),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 12,
                  16,
                  12,
                ),
                child: Text(
                  'التقارير',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoadingWidget());
    }
    if (_error != null) {
      return AppErrorWidget(
        message: _error!,
        onRetry: () {
          final state = context.read<SupervisorBloc>().state;
          if (state.halaqatStatus == SectionStatus.error) {
            final auth = context.read<AuthBloc>().state;
            if (auth is AuthAuthenticated) {
              context.read<SupervisorBloc>().add(
                LoadSupervisedHalaqatEvent(auth.user.uid),
              );
            }
          } else {
            _halaqaKey = '';
            _load(state.halaqat);
          }
        },
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _halaqaKey = '';
        await _load(context.read<SupervisorBloc>().state.halaqat);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _composeReport(context),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('كتابة تقرير'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => SupervisorDestinations.awardsHub(context),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('الجوائز'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ملخص الحلقات',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_cards.isEmpty)
            AppCard(
              child: Text(
                'لا توجد حلقات لعرض تقاريرها',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            )
          else
            ..._cards.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => SupervisorDestinations.halaqaDetail(
                    context,
                    halaqaId: c.halaqa.id,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        c.halaqa.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatChip(label: 'طلاب', value: '${c.studentCount}'),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'في خطر',
                            value: '${c.atRiskCount}',
                            accent: c.atRiskCount > 0 ? AppColors.error : null,
                          ),
                          if (c.attendancePercent != null) ...[
                            const SizedBox(width: 8),
                            _StatChip(
                              label: 'حضور',
                              value:
                                  '${c.attendancePercent!.toStringAsFixed(0)}%',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _StatChip({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        '$label: $value',
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

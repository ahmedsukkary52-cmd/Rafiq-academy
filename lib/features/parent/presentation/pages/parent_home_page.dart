import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../notifications/presentation/bloc/notifications_bloc.dart';
import '../../../notifications/presentation/bloc/notifications_event.dart';
import '../../../notifications/presentation/bloc/notifications_state.dart';
import '../../../../shared/widgets/confirm_logout.dart';
import '../../domain/entities/parent_entities.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';

/// Parent home — children list + weekly report (Sprint 1 + 2).
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    _loadChildren();
    _watchNotifications();
  }

  void _loadChildren() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    context.read<ParentBloc>().add(LoadChildrenEvent(authState.user.uid));
  }

  void _watchNotifications() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    sl<NotificationsBloc>().add(
      StartWatchingNotificationsEvent(
        uid: authState.user.uid,
        role: AppRoles.parent,
      ),
    );
  }

  void _selectChild(String studentId) {
    context.read<ParentBloc>().add(SelectChildEvent(studentId));
  }

  void _retryReport() {
    final selectedId = context.read<ParentBloc>().state.selectedChildId;
    if (selectedId == null) return;
    _selectChild(selectedId);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final parentName = authState is AuthAuthenticated
        ? authState.user.name
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('نافذة ولي الأمر'),
        actions: [
          BlocSelector<NotificationsBloc, NotificationsState, int>(
            bloc: sl<NotificationsBloc>(),
            selector: (state) => state.unreadCount,
            builder: (context, unreadCount) {
              return Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: NotificationBadge(
                  count: unreadCount,
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'الإشعارات',
                    onPressed: () => context.push(AppRoutes.parentNotifs),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'تسجيل الخروج',
            onPressed: () => confirmAndLogout(context),
          ),
        ],
      ),
      body: BlocConsumer<ParentBloc, ParentState>(
        listenWhen: (prev, curr) =>
            prev.childrenStatus != curr.childrenStatus ||
            prev.childrenIds != curr.childrenIds ||
            prev.selectedChildId != curr.selectedChildId,
        listener: (context, state) {
          // After children load, load the current-week report for the
          // auto-selected child via the existing SelectChildEvent flow.
          if (state.childrenStatus == SectionStatus.loaded &&
              state.selectedChildId != null &&
              state.reportStatus == SectionStatus.initial) {
            _selectChild(state.selectedChildId!);
          }
        },
        builder: (context, state) {
          if (state.childrenStatus == SectionStatus.initial ||
              state.childrenStatus == SectionStatus.loading) {
            return const AppLoadingWidget();
          }

          if (state.childrenStatus == SectionStatus.error) {
            return AppErrorWidget(
              message: state.childrenError ?? 'حدث خطأ',
              onRetry: _loadChildren,
            );
          }

          if (state.childrenIds.isEmpty) {
            return const _EmptyChildren();
          }

          return ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              Text(
                parentName.isEmpty ? 'ولي الأمر' : parentName,
                style: AppTextStyles.headlineLarge,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 4),
              Text(
                'الأبناء المرتبطون: ${state.childrenIds.length}',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: AppSizes.paddingM),
              ...state.childrenIds.map((id) {
                final isSelected = id == state.selectedChildId;
                final name =
                    (isSelected &&
                        state.weeklyReport != null &&
                        state.weeklyReport!.studentId == id &&
                        state.weeklyReport!.studentName.trim().isNotEmpty)
                    ? state.weeklyReport!.studentName.trim()
                    : 'طالب';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ChildCard(
                    name: name,
                    isSelected: isSelected,
                    onTap: () => _selectChild(id),
                  ),
                );
              }),
              const SizedBox(height: AppSizes.paddingM),
              AppCard(
                onTap: () => context.push(AppRoutes.parentAbsence),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.primary,
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'طلبات الاستئذان',
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'تقديم ومتابعة طلباتك',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: const Icon(
                        Icons.event_busy_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingM),
              Text(
                'التقرير الأسبوعي',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 8),
              _WeeklyReportSection(state: state, onRetry: _retryReport),
            ],
          );
        },
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChildCard({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: isSelected ? AppColors.primary : AppColors.textHint,
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(name, style: AppTextStyles.titleLarge),
              const SizedBox(height: 2),
              Text(
                'طالب',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyReportSection extends StatelessWidget {
  final ParentState state;
  final VoidCallback onRetry;

  const _WeeklyReportSection({required this.state, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (state.reportStatus == SectionStatus.initial ||
        state.reportStatus == SectionStatus.loading) {
      return const SizedBox(height: 160, child: AppLoadingWidget());
    }

    if (state.reportStatus == SectionStatus.error) {
      return AppErrorWidget(
        message: state.reportError ?? 'تعذر تحميل التقرير',
        onRetry: onRetry,
      );
    }

    final report = state.weeklyReport;
    if (report == null) {
      return const _EmptyWeeklyReport();
    }

    final hasData =
        report.totalSessions > 0 ||
        report.totalVersesMemorized > 0 ||
        report.teacherNotes.trim().isNotEmpty;

    if (!hasData) {
      return const _EmptyWeeklyReport();
    }

    return _WeeklyReportCard(report: report);
  }
}

class _WeeklyReportCard extends StatelessWidget {
  final WeeklyReportEntity report;

  const _WeeklyReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final name = report.studentName.trim().isEmpty
        ? 'طالب'
        : report.studentName.trim();
    final attendanceLabel = report.totalSessions == 0
        ? '—'
        : '${report.attendedSessions} / ${report.totalSessions}';
    final percentLabel = report.totalSessions == 0
        ? '—'
        : '${report.attendancePercent.round()}%';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name,
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            'أسبوع يبدأ ${_formatDate(report.weekStart)}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: AppSizes.paddingM),
          Row(
            children: [
              Expanded(
                child: _MetricTile(label: 'الحضور', value: attendanceLabel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(label: 'نسبة الحضور', value: percentLabel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  label: 'تقييمات',
                  value: '${report.totalVersesMemorized}',
                ),
              ),
            ],
          ),
          if (report.totalSessions > 0) ...[
            const SizedBox(height: 8),
            Text(
              'يشمل الحضور والتأخر — الغياب فقط لا يُحسب',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.right,
            ),
          ],
          if (report.teacherNotes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingM),
            Text(
              'ملاحظات المعلم',
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 4),
            Text(
              report.teacherNotes.trim(),
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) => formatDateDmy(date);
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyWeeklyReport extends StatelessWidget {
  const _EmptyWeeklyReport();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 40,
            color: AppColors.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد بيانات لهذا الأسبوع بعد',
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'سيظهر الحضور والتقييمات المعتمدة هنا.\nالتسميعات بانتظار مراجعة المعلم لا تُحتسب.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد طلاب مرتبطون بهذا الحساب بعد',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'عند ربط أبنائك بحسابك من قِبل الأكاديمية ستظهر أسماؤهم هنا.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

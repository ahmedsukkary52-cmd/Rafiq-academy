import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../domain/analytics_cta_navigation.dart';
import '../../domain/entities/analytics_entities.dart';
import '../bloc/analytics_bloc.dart';
import '../bloc/analytics_event.dart';
import '../bloc/analytics_state.dart';

/// Teacher Analytics dashboard — Figma `11_analytics` / `1:1500`.
///
/// Re-entered in Analytics Phase 2 (was H6 A-H8 orphan quarantine).
/// Performance metrics use Phase 1 honesty (reviewed + non-null grade);
/// distribution remains event-weighted; weekly = rolling 7 calendar days.
class AnalyticsDashboardPage extends StatefulWidget {
  final String halaqaId;

  const AnalyticsDashboardPage({super.key, required this.halaqaId});

  @override
  State<AnalyticsDashboardPage> createState() => _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  late final AnalyticsBloc _bloc;
  bool _contactBusy = false;

  @override
  void initState() {
    super.initState();
    _bloc = sl<AnalyticsBloc>();
    _load();
  }

  void _load() {
    final now = DateTime.now();
    final oneMonth = now.subtract(const Duration(days: 30));
    _bloc.add(
      LoadHalaqaAnalyticsDashboardEvent(
        halaqaId: widget.halaqaId,
        from: oneMonth,
        to: now,
      ),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _openEvaluations(AtRiskStudentEntity student) {
    context.push(
      AnalyticsCtaNavigation.evaluationsPath(
        halaqaId: widget.halaqaId,
        studentId: student.studentId,
      ),
    );
  }

  Future<void> _openStudentChat(AtRiskStudentEntity student) async {
    if (_contactBusy) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() => _contactBusy = true);
    try {
      final peerEither = await sl<GetChatParticipantUseCase>()(
        ChatUidParams(student.studentId),
      );
      if (!mounted) return;

      final peer = peerEither.fold<ChatParticipantEntity?>((f) {
        AppSnackBar.showInfo(context, f.message);
        return null;
      }, (p) => p);
      if (peer == null) return;

      if (!AnalyticsCtaNavigation.allowsStudentContact(
        teacherRole: auth.user.role,
        peerRole: peer.role,
      )) {
        AppSnackBar.showInfo(
          context,
          'التواصل متاح مع الطلاب فقط من هذه الشاشة',
        );
        return;
      }

      final currentUser = ChatParticipantEntity(
        uid: auth.user.uid,
        name: auth.user.name,
        role: auth.user.role,
        profileImageUrl: auth.user.profileImageUrl,
      );

      final chatBloc = sl<ChatConversationsBloc>();
      chatBloc.add(const ResetStartConversationEvent());
      chatBloc.add(
        StartConversationEvent(currentUser: currentUser, otherUser: peer),
      );

      final startState = await chatBloc.stream.firstWhere(
        (s) =>
            s.startConversationStatus == SubmissionStatus.success ||
            s.startConversationStatus == SubmissionStatus.error,
      );
      if (!mounted) return;

      if (startState.startConversationStatus == SubmissionStatus.error ||
          startState.startedConversation == null) {
        AppSnackBar.showInfo(
          context,
          startState.startConversationError ?? 'تعذر فتح المحادثة',
        );
        chatBloc.add(const ResetStartConversationEvent());
        return;
      }

      final conversation = startState.startedConversation!;
      chatBloc.add(const ResetStartConversationEvent());
      if (!mounted) return;
      context.push(
        AppRoutes.teacherChat.replaceFirst(':conversationId', conversation.id),
        extra: <String, String?>{
          'name': peer.name,
          'image': peer.profileImageUrl,
        },
      );
    } finally {
      if (mounted) setState(() => _contactBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider.value(
        value: _bloc,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
            buildWhen: (previous, current) =>
                previous.analytics != current.analytics ||
                previous.analyticsStatus != current.analyticsStatus ||
                previous.analyticsError != current.analyticsError ||
                previous.atRiskStudents != current.atRiskStudents ||
                previous.atRiskStatus != current.atRiskStatus ||
                previous.atRiskError != current.atRiskError ||
                previous.topStudents != current.topStudents ||
                previous.topStudentsStatus != current.topStudentsStatus ||
                previous.topStudentsError != current.topStudentsError,
            builder: (context, state) {
              return RefreshIndicator(
                onRefresh: () async {
                  _bloc.add(RefreshAnalyticsEvent(widget.halaqaId));
                  await _bloc.stream.firstWhere(
                    (s) =>
                        s.analyticsStatus != SectionStatus.loading &&
                        s.atRiskStatus != SectionStatus.loading &&
                        s.topStudentsStatus != SectionStatus.loading,
                  );
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 188,
                      backgroundColor: AppColors.dark,
                      foregroundColor: Colors.white,
                      title: Text(
                        'لوحة التحليلات',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: _AnalyticsHeader(
                          analytics: state.analytics,
                          loading:
                              state.analyticsStatus == SectionStatus.loading ||
                              state.analyticsStatus == SectionStatus.initial,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _AnalyticsSection(
                            status: state.analyticsStatus,
                            error: state.analyticsError,
                            onRetry: _load,
                            loadingChild: const _SectionSkeleton(height: 220),
                            child: state.analytics == null
                                ? const SizedBox.shrink()
                                : _PerformanceDistributionCard(
                                    analytics: state.analytics!,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsSection(
                            status: state.analyticsStatus,
                            error: state.analyticsError,
                            onRetry: _load,
                            loadingChild: const _SectionSkeleton(height: 160),
                            child: state.analytics == null
                                ? const SizedBox.shrink()
                                : _WeeklyAttendanceCard(
                                    weeklyData:
                                        state.analytics!.weeklyAttendance,
                                  ),
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsSection(
                            status: state.atRiskStatus,
                            error: state.atRiskError,
                            onRetry: _load,
                            loadingChild: const _SectionSkeleton(height: 140),
                            empty:
                                state.atRiskStatus == SectionStatus.loaded &&
                                state.atRiskStudents.isEmpty,
                            emptyChild: const _SectionEmptyCard(
                              title: 'طلاب يحتاجون متابعة عاجلة',
                              message: 'لا يوجد طلاب بحاجة لمتابعة حالياً',
                            ),
                            child: _AtRiskCard(
                              students: state.atRiskStudents,
                              contactBusy: _contactBusy,
                              onEvaluate: _openEvaluations,
                              onContact: _openStudentChat,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsSection(
                            status: state.topStudentsStatus,
                            error: state.topStudentsError,
                            onRetry: _load,
                            loadingChild: const _SectionSkeleton(height: 140),
                            child: _TopStudentsCard(
                              students: state.topStudents,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  final SectionStatus status;
  final String? error;
  final VoidCallback onRetry;
  final Widget loadingChild;
  final Widget child;
  final bool empty;
  final Widget? emptyChild;

  const _AnalyticsSection({
    required this.status,
    required this.error,
    required this.onRetry,
    required this.loadingChild,
    required this.child,
    this.empty = false,
    this.emptyChild,
  });

  @override
  Widget build(BuildContext context) {
    if (status == SectionStatus.loading || status == SectionStatus.initial) {
      return loadingChild;
    }
    if (status == SectionStatus.error) {
      return AppCard(
        child: AppErrorWidget(
          message: error ?? 'تعذر تحميل البيانات',
          onRetry: onRetry,
        ),
      );
    }
    if (empty && emptyChild != null) return emptyChild!;
    return child;
  }
}

class _SectionEmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _SectionEmptyCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          Text(
            message,
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

class _SectionSkeleton extends StatelessWidget {
  final double height;

  const _SectionSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: height,
        child: Center(
          child: Container(
            width: double.infinity,
            height: height - 32,
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  final HalaqaAnalyticsEntity? analytics;
  final bool loading;

  const _AnalyticsHeader({required this.analytics, required this.loading});

  @override
  Widget build(BuildContext context) {
    // Figma 1:1500 — each stat in its own translucent pill; colors map to
    // donut segments: students→teal, attendance→gold, performance→green.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
        child: loading
            ? const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white70,
            ),
          ),
        )
        // RTL Row: first child sits on the right (Figma order).
            : Row(
          children: [
            Expanded(
              child: _HeaderStatPill(
                value: '${analytics?.totalStudents ?? 0}',
                label: 'إجمالي الطلاب',
                valueColor: AppColors.gradeExcellent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeaderStatPill(
                value: '${analytics?.attendancePercent.toInt() ?? 0}%',
                label: 'نسبة الحضور',
                valueColor: AppColors.gradeGood,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HeaderStatPill(
                value:
                '${analytics?.averagePerformancePercent.toInt() ?? 0}%',
                label: 'متوسط الأداء',
                valueColor: AppColors.gradeVeryGood,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _HeaderStatPill({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1.1,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceDistributionCard extends StatelessWidget {
  final HalaqaAnalyticsEntity analytics;

  const _PerformanceDistributionCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final dist = analytics.performanceDistribution;
    final total = dist.values.fold<int>(0, (a, b) => a + b);

    final colors = {
      'ممتاز': AppColors.gradeExcellent,
      'جيد جداً': AppColors.gradeVeryGood,
      'جيد': AppColors.gradeGood,
      'يحتاج تحسين': AppColors.gradeNeedsWork,
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('توزيع مستويات الأداء', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'لا توجد بيانات كافية بعد',
                style: AppTextStyles.bodyMedium,
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _DistributionDonutPainter(
                      dist: dist,
                      colors: colors,
                      total: total,
                    ),
                  ),
                  // Event-weighted count (not unique students) — Phase 2 lock.
                  Text(
                    '$total\nتقييم',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: dist.entries.map((e) {
                final percent = total > 0 ? (e.value / total * 100).toInt() : 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$percent% ${e.key}', style: AppTextStyles.labelSmall),
                    const SizedBox(width: 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors[e.key] ?? AppColors.textHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DistributionDonutPainter extends CustomPainter {
  final Map<String, int> dist;
  final Map<String, Color> colors;
  final int total;

  _DistributionDonutPainter({
    required this.dist,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeW = 22.0;

    double startAngle = -math.pi / 2;

    for (final entry in dist.entries) {
      if (entry.value == 0) continue;
      final sweep = (entry.value / total) * 2 * math.pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = colors[entry.key] ?? AppColors.textHint
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DistributionDonutPainter old) => true;
}

class _WeeklyAttendanceCard extends StatelessWidget {
  final Map<String, double> weeklyData;

  const _WeeklyAttendanceCard({required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    // Figma RTL day order (right → left visually in Row with RTL).
    const dayOrder = ['سب', 'جم', 'خم', 'أر', 'ثل', 'إث', 'أح'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('الحضور الأسبوعي', style: AppTextStyles.titleLarge),
          const SizedBox(height: 20),
          SizedBox(
            height: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dayOrder.map((day) {
                final value = weeklyData[day] ?? 0;
                final barHeight = (value / 100) * 96;
                final color = _barColor(value);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: double.infinity,
                          height: value <= 0 ? 4 : barHeight.clamp(8, 96),
                          decoration: BoxDecoration(
                            color: color,
                            // Figma: rounded top, flatter base feel.
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                              bottom: Radius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          day,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Figma: high → dark teal, mid → gold, low → faded teal.
  Color _barColor(double value) {
    if (value >= 70) return AppColors.primaryDark;
    if (value >= 40) return AppColors.gradeGood;
    return AppColors.primary.withValues(alpha: 0.35);
  }
}

class _AtRiskCard extends StatelessWidget {
  final List<AtRiskStudentEntity> students;
  final bool contactBusy;
  final void Function(AtRiskStudentEntity) onEvaluate;
  final void Function(AtRiskStudentEntity) onContact;

  const _AtRiskCard({
    required this.students,
    required this.contactBusy,
    required this.onEvaluate,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    // Figma: light pink panel + red border; each student in a white mini-card.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'طلاب يحتاجون متابعة عاجلة',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...students.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AtRiskStudentRow(
                student: s,
                contactBusy: contactBusy,
                onEvaluate: onEvaluate,
                onContact: onContact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AtRiskStudentRow extends StatelessWidget {
  final AtRiskStudentEntity student;
  final bool contactBusy;
  final void Function(AtRiskStudentEntity) onEvaluate;
  final void Function(AtRiskStudentEntity) onContact;

  const _AtRiskStudentRow({
    required this.student,
    required this.contactBusy,
    required this.onEvaluate,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Figma: one primary action by risk reason (not both).
          _AtRiskReasonAction(
            student: student,
            enabled: !contactBusy,
            onEvaluate: onEvaluate,
            onContact: onContact,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  student.studentName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  student.detail,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          UserAvatar(
            name: student.studentName,
            imageUrl: student.profileImageUrl,
            size: 40,
          ),
        ],
      ),
    );
  }
}

class _AtRiskReasonAction extends StatelessWidget {
  final AtRiskStudentEntity student;
  final bool enabled;
  final void Function(AtRiskStudentEntity) onEvaluate;
  final void Function(AtRiskStudentEntity) onContact;

  const _AtRiskReasonAction({
    required this.student,
    required this.enabled,
    required this.onEvaluate,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    // One primary CTA from entity reason (datasource picks one signal).
    final isEvaluate =
    AnalyticsCtaNavigation.atRiskActionIsEvaluate(student.reason);
    return _AtRiskOutlineLink(
      label: AnalyticsCtaNavigation.atRiskActionLabel(student.reason),
      color: isEvaluate ? AppColors.gradeGood : AppColors.error,
      onTap: !enabled
          ? null
          : isEvaluate
          ? () => onEvaluate(student)
          : () => onContact(student),
    );
  }
}

/// Figma: compact outlined text action (not a filled button).
class _AtRiskOutlineLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AtRiskOutlineLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.85), width: 1),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStudentsCard extends StatelessWidget {
  final List<TopStudentEntity> students;

  const _TopStudentsCard({required this.students});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('المتفوقون', style: AppTextStyles.titleLarge),
              const SizedBox(width: 6),
              const Icon(
                Icons.star_rounded,
                color: AppColors.secondary,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (students.isEmpty)
            Text(
              'لا توجد بيانات كافية بعد',
              style: AppTextStyles.bodyMedium,
            )
          else
            ...students.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '${s.performancePercent.toInt()}%',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(s.studentName, style: AppTextStyles.titleMedium),
                    const SizedBox(width: 10),
                    UserAvatar(name: s.studentName, size: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

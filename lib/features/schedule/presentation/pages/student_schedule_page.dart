import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../student/presentation/bloc/student_bloc.dart';
import '../../domain/entities/class_session_entity.dart';
import '../bloc/schedule_bloc.dart';

String _formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'ص' : 'م';
  return '$hour:$minute $period';
}

String _dayLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'غداً';
  if (diff == -1) return 'أمس';
  const names = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  return names[dt.weekday - 1];
}

class StudentSchedulePage extends StatelessWidget {
  const StudentSchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final halaqaId =
        context.read<StudentBloc>().state.profile?.halaqaId?.trim() ?? '';

    return BlocProvider(
      create: (_) => sl<ScheduleBloc>()..add(LoadWeeklySessionsEvent(halaqaId)),
      child: _ScheduleView(halaqaId: halaqaId),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  final String halaqaId;

  const _ScheduleView({required this.halaqaId});

  void _retry(BuildContext context) {
    final id =
        context.read<StudentBloc>().state.profile?.halaqaId?.trim() ?? halaqaId;
    context.read<ScheduleBloc>().add(LoadWeeklySessionsEvent(id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
        ),
        title: const Text(
          'حصصي 🕌',
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, state) {
          if (state.status == SectionStatus.loading ||
              state.status == SectionStatus.initial) {
            return const AppLoadingWidget();
          }

          if (state.status == SectionStatus.error) {
            return AppErrorWidget(
              message: state.errorMessage ?? 'تعذر تحميل جدول الحصص',
              onRetry: () => _retry(context),
            );
          }

          if (halaqaId.isEmpty &&
              (context.read<StudentBloc>().state.profile?.halaqaId?.trim() ??
                      '')
                  .isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لم يتم ربطك بحلقة بعد\nسيظهر جدول الحصص هنا بعد انضمامك لحلقة',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (state.sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'لا توجد مواعيد في جدول الحلقة حالياً',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'إعادة المحاولة',
                      width: 160,
                      height: 44,
                      onPressed: () => _retry(context),
                    ),
                  ],
                ),
              ),
            );
          }

          final featured = state.featuredSession;

          return ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              if (featured != null) ...[
                _FeaturedSessionCard(
                  session: featured,
                  onJoin: () => _joinSession(context, featured),
                ),
                const SizedBox(height: 16),
                if ((featured.topic ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '📖 موضوع اليوم: ${featured.topic}',
                      style: AppTextStyles.titleMedium,
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
              const Align(
                alignment: Alignment.centerRight,
                child: Text('جدول الأسبوع', style: AppTextStyles.labelMedium),
              ),
              const SizedBox(height: 10),
              ...state.sessions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionListTile(session: s),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _joinSession(
    BuildContext context,
    ClassSessionEntity session,
  ) async {
    final link = session.meetingLink.trim();
    if (link.isEmpty || session.status != ClassSessionStatus.live) {
      AppSnackBar.showInfo(
        context,
        'رابط الحصة لسه مش متاح — الحصة لسه ما بدأتش',
      );
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) {
      AppSnackBar.showError(context, 'رابط الحصة غير صالح');
      return;
    }
    final ok =
        await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackBar.showError(context, 'تعذر فتح رابط الحصة');
    }
  }
}

class _FeaturedSessionCard extends StatelessWidget {
  final ClassSessionEntity session;
  final VoidCallback onJoin;

  const _FeaturedSessionCard({required this.session, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        '${_dayLabel(session.startAt)} — ${_formatTime(session.startAt)} إلى ${_formatTime(session.endAt)}';

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    session.status == ClassSessionStatus.live
                        ? 'مباشر الآن'
                        : session.status == ClassSessionStatus.upcoming
                        ? 'قادمة'
                        : 'انتهت',
                    style: const TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            timeLabel,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white60),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 6),
          Text(
            session.title,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.right,
          ),
          if (session.teacherName.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  session.teacherName,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('👳', style: TextStyle(fontSize: 16)),
              ],
            ),
          ],
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onJoin,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'انضم للحصة الآن',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionListTile extends StatelessWidget {
  final ClassSessionEntity session;

  const _SessionListTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final (badgeBg, badgeFg, badgeLabel) = switch (session.status) {
      ClassSessionStatus.live => (
        const Color(0xFFFFEBEE),
        AppColors.error,
        'مباشر',
      ),
      ClassSessionStatus.upcoming => (
        AppColors.primaryLight,
        AppColors.primaryDark,
        'قادمة',
      ),
      ClassSessionStatus.ended => (
        AppColors.surfaceGrey,
        AppColors.textSecondary,
        'انتهت',
      ),
    };

    final dayLabel = _dayLabel(session.startAt);
    final subtitle = session.teacherName.trim().isEmpty
        ? dayLabel
        : '${session.teacherName} - $dayLabel';

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(session.title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            alignment: Alignment.center,
            child: Text(
              _formatTime(session.startAt).replaceFirst(' ', '\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

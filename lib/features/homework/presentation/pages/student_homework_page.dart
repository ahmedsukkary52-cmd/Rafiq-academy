import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/contact_info_policy.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../shared/widgets/student_page_skeletons.dart';
import '../../domain/entities/homework_entity.dart';
import '../bloc/homework_bloc.dart';

class StudentHomeworkPage extends StatelessWidget {
  const StudentHomeworkPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.uid : '';

    return BlocProvider(
      create: (_) => sl<HomeworkBloc>()..add(LoadHomeworkEvent(uid)),
      child: const _HomeworkView(),
    );
  }
}

class _HomeworkView extends StatelessWidget {
  const _HomeworkView();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeworkBloc, HomeworkState>(
          listenWhen: (p, c) =>
              p.submissionStatus != c.submissionStatus &&
              c.submissionStatus == SubmissionStatus.success,
          listener: (context, state) {
            final points = state.lastEarnedPoints ?? 0;
            showModalBottomSheet<void>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'أحسنت! تم إنهاء الواجب',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      points > 0
                          ? 'ربحت $points عملة'
                          : 'تم احتساب مكافأة هذا الواجب مسبقاً',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<HomeworkBloc>().add(
                            const ClearHomeworkMessageEvent(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                          ),
                        ),
                        child: const Text('حسناً'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        BlocListener<HomeworkBloc, HomeworkState>(
          listenWhen: (p, c) {
            final msg = c.errorMessage;
            if (msg == null || msg.isEmpty) return false;
            if (msg == p.errorMessage) return false;
            // Load failures are shown inline via AppErrorWidget.
            if (c.status == SectionStatus.error) return false;
            return true;
          },
          listener: (context, state) {
            AppSnackBar.showError(
              context,
              state.errorMessage ?? 'حدث خطأ غير متوقع',
            );
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          leading: AppBackButton(
            onPressed: () => context.pop(),
            color: AppColors.textPrimary,
          ),
          title: const Text(
            'واجباتي 📝',
            style: TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: BlocBuilder<HomeworkBloc, HomeworkState>(
          buildWhen: (previous, current) =>
              previous.status != current.status ||
              previous.homework != current.homework ||
              previous.errorMessage != current.errorMessage ||
              previous.studentId != current.studentId ||
              previous.submissionStatus != current.submissionStatus ||
              previous.lastEarnedPoints != current.lastEarnedPoints,
          builder: (context, state) {
            if (state.status == SectionStatus.loading ||
                state.status == SectionStatus.initial) {
              return const StudentListPageSkeleton();
            }

            if (state.status == SectionStatus.error) {
              final auth = context.read<AuthBloc>().state;
              final uid =
                  state.studentId ??
                  (auth is AuthAuthenticated ? auth.user.uid : '');
              return AppErrorWidget(
                message: state.errorMessage ?? 'تعذر تحميل الواجب',
                onRetry: uid.isEmpty
                    ? null
                    : () => context.read<HomeworkBloc>().add(
                        LoadHomeworkEvent(uid),
                      ),
              );
            }

            final hw = state.homework;
            if (hw == null) {
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  final auth = context.read<AuthBloc>().state;
                  final uid =
                      state.studentId ??
                      (auth is AuthAuthenticated ? auth.user.uid : '');
                  if (uid.isEmpty) return;
                  context.read<HomeworkBloc>().add(LoadHomeworkEvent(uid));
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    AppEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'لا يوجد واجب حالياً',
                      message:
                          'سيظهر هنا نفس تكليف «درس اليوم» من المعلم عند إرساله.',
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      final auth = context.read<AuthBloc>().state;
                      final uid =
                          state.studentId ??
                          (auth is AuthAuthenticated ? auth.user.uid : '');
                      if (uid.isEmpty) return;
                      context.read<HomeworkBloc>().add(LoadHomeworkEvent(uid));
                      await Future<void>.delayed(
                        const Duration(milliseconds: 600),
                      );
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSizes.paddingM),
                      children: [
                        _HomeworkHeroCard(homework: hw),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'المهام',
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...hw.tasks.map(
                          (task) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TaskTile(
                              task: task,
                              readOnly: hw.isSubmitted,
                              subtitle: task.isDeferredRecitation
                                  ? 'غير مطلوب لإنهاء الواجب'
                                  : null,
                              deferred: task.isDeferredRecitation,
                              onToggle:
                                  hw.isSubmitted ||
                                      task.kind == HomeworkTaskKind.recitation
                                  ? null
                                  : () => context.read<HomeworkBloc>().add(
                                      ToggleTaskEvent(task.id),
                                    ),
                            ),
                          ),
                        ),
                        if (hw.teacherVoiceNote != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'ملاحظة صوتية من المعلم',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _TeacherVoiceNoteCard(note: hw.teacherVoiceNote!),
                        ],
                        if (hw.attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'مرفقات',
                              style: AppTextStyles.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...hw.attachments.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AttachmentTile(attachment: a),
                            ),
                          ),
                        ],
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            hw.isSubmitted ||
                                !hw.allCompleted ||
                                state.submissionStatus ==
                                    SubmissionStatus.submitting
                            ? null
                            : () => context.read<HomeworkBloc>().add(
                                const FinishHomeworkEvent(),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hw.isSubmitted
                              ? AppColors.success
                              : AppColors.primary,
                          disabledBackgroundColor: hw.isSubmitted
                              ? AppColors.success
                              : AppColors.border,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusL,
                            ),
                          ),
                        ),
                        child: Text(
                          hw.isSubmitted
                              ? 'تم الإنهاء ✅'
                              : state.submissionStatus ==
                                    SubmissionStatus.submitting
                              ? 'جاري الإنهاء...'
                              : '✅ إنهاء الواجب',
                          style: const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _HomeworkHeroCard extends StatelessWidget {
  final HomeworkEntity homework;

  const _HomeworkHeroCard({required this.homework});

  @override
  Widget build(BuildContext context) {
    final remaining = homework.dueAt.difference(DateTime.now());
    final isOverdue = !homework.isSubmitted && remaining.isNegative;
    final hours = remaining.inHours.clamp(0, 99);
    final dueLabel = homework.isSubmitted
        ? '✅ تم إنهاء الواجب'
        : isOverdue
        ? '⏰ متأخر — كان موعد التسليم ${formatTimeHm12Ar(homework.dueAt)}'
        : '🕒 ينتهي الساعة ${formatTimeHm12Ar(homework.dueAt)} — متبقي $hours ساعات';

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: homework.isSubmitted ? AppColors.primaryDark : AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            homework.isSubmitted ? '📚 واجب مكتمل' : '📚 واجب اليوم',
            style: AppTextStyles.labelMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            homework.title,
            style: const TextStyle(
              fontFamily: 'NotoNaskhArabic',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dueLabel,
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: homework.isSubmitted ? 1 : homework.progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final HomeworkTaskEntity task;
  final VoidCallback? onToggle;
  final bool readOnly;
  final bool deferred;
  final String? subtitle;

  const _TaskTile({
    required this.task,
    required this.onToggle,
    this.readOnly = false,
    this.deferred = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final muted = readOnly || deferred;
    return Opacity(
      opacity: muted ? 0.72 : 1,
      child: AppCard(
        onTap: onToggle,
        color: muted ? AppColors.surfaceGrey : null,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: muted ? AppColors.border : AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                deferred ? 'تسميع' : '${task.points}+',
                style: AppTextStyles.labelSmall.copyWith(
                  color: muted ? AppColors.textSecondary : AppColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    task.title,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: task.isCompleted || muted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: task.isCompleted && !deferred
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: deferred
                            ? AppColors.textSecondary
                            : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: task.isCompleted && !deferred
                    ? AppColors.success
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted && !deferred
                      ? AppColors.success
                      : AppColors.textHint,
                  width: 2,
                ),
              ),
              child: task.isCompleted && !deferred
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherVoiceNoteCard extends StatefulWidget {
  final TeacherVoiceNoteEntity note;

  const _TeacherVoiceNoteCard({required this.note});

  @override
  State<_TeacherVoiceNoteCard> createState() => _TeacherVoiceNoteCardState();
}

class _TeacherVoiceNoteCardState extends State<_TeacherVoiceNoteCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  StreamSubscription<PlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    try {
      if (_player.audioSource == null) {
        await _player.setUrl(widget.note.audioUrl);
      }
      await _player.play();
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, 'تعذر تشغيل الملاحظة الصوتية');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final secs = widget.note.duration.inSeconds;
    final label = formatSecondsMmSs(secs);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            widget.note.teacherName,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(label, style: AppTextStyles.labelSmall),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  child: CustomPaint(painter: _WavePainter()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _toggle,
                icon: Icon(
                  _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const bars = 28;
    for (var i = 0; i < bars; i++) {
      final x = (i + 0.5) * (size.width / bars);
      final h = 4.0 + (i % 5) * 3.0;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AttachmentTile extends StatelessWidget {
  final HomeworkAttachmentEntity attachment;

  const _AttachmentTile({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (!isAllowedExternalLink(attachment.url)) return;
              await launchUrl(
                Uri.parse(attachment.url.trim()),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(
              Icons.download_rounded,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(attachment.name, style: AppTextStyles.titleMedium),
                Text(attachment.sizeLabel, style: AppTextStyles.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: const Icon(Icons.picture_as_pdf, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/presentation/halaqa_activities/activity_thread_widgets.dart';
import '../../../../shared/presentation/halaqa_activities/halaqa_activity_ui_models.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../halaqa_activity/domain/usecases/halaqa_activity_usecases.dart';
import '../../../halaqa_activity/presentation/halaqa_activity_ui_mapper.dart';

class StudentActivitiesPage extends StatefulWidget {
  final String halaqaId;

  const StudentActivitiesPage({super.key, required this.halaqaId});

  @override
  State<StudentActivitiesPage> createState() => _StudentActivitiesPageState();
}

class _StudentActivitiesPageState extends State<StudentActivitiesPage> {
  var _status = ActivityListLoadState.loading;
  String? _error;
  List<HalaqaActivityUi> _activities = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _status = ActivityListLoadState.loading;
      _error = null;
    });
    final result = await sl<ListHalaqaActivitiesUseCase>()(
      HalaqaActivityHalaqaParams(widget.halaqaId),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _status = ActivityListLoadState.error;
        _error = failure.message;
        _activities = const [];
      }),
      (items) => setState(() {
        _status = ActivityListLoadState.loaded;
        _activities = items.map(HalaqaActivityUiMapper.toUi).toList();
      }),
    );
  }

  String get _studentId {
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) return auth.user.uid;
    } catch (_) {}
    return '';
  }

  void _openDetail(HalaqaActivityUi activity) {
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => StudentActivityDetailPage(
          halaqaId: widget.halaqaId,
          activityId: activity.id,
        ),
      ),
    )
        .then((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentId = _studentId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('أنشطة الحلقة')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: switch (_status) {
          ActivityListLoadState.loading => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160, child: AppLoadingWidget()),
              ],
            ),
          ActivityListLoadState.error => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppErrorWidget(
                  message: _error ?? 'حدث خطأ',
                  onRetry: _reload,
                ),
              ],
            ),
          ActivityListLoadState.loaded => _activities.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    _StudentActivitiesEmpty(),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  itemCount: _activities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final a = _activities[i];
                    final reply = a.hasStudentResponded(studentId)
                        ? StudentActivityReplyState.replied
                        : StudentActivityReplyState.notReplied;
                    return _StudentActivityCard(
                      activity: a,
                      replyState: reply,
                      onTap: () => _openDetail(a),
                    );
                  },
                ),
        },
      ),
    );
  }
}

class _StudentActivitiesEmpty extends StatelessWidget {
  const _StudentActivitiesEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: AppCard(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text('لا توجد أنشطة حالياً', style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            Text(
              'عندما يرسل معلم الحلقة مهمة خفيفة ستظهر هنا.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentActivityCard extends StatelessWidget {
  final HalaqaActivityUi activity;
  final StudentActivityReplyState replyState;
  final VoidCallback onTap;

  const _StudentActivityCard({
    required this.activity,
    required this.replyState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final replied = replyState == StudentActivityReplyState.replied;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (replied ? AppColors.success : AppColors.gradeGood)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusS),
                ),
                child: Text(
                  replied ? 'تم الرد' : 'لم تُرسل بعد',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: replied ? AppColors.success : AppColors.gradeGood,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activity.prompt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              formatDateDmy(activity.createdAt),
              if (activity.deadline != null)
                'موعد: ${formatDateDmy(activity.deadline!)}',
            ].join(' · '),
            textAlign: TextAlign.right,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class StudentActivityDetailPage extends StatefulWidget {
  final String halaqaId;
  final String activityId;

  const StudentActivityDetailPage({
    super.key,
    required this.halaqaId,
    required this.activityId,
  });

  @override
  State<StudentActivityDetailPage> createState() =>
      _StudentActivityDetailPageState();
}

class _StudentActivityDetailPageState extends State<StudentActivityDetailPage> {
  final _textCtrl = TextEditingController();
  var _status = ActivityListLoadState.loading;
  String? _error;
  HalaqaActivityUi? _activity;

  File? _pendingImageFile;
  File? _pendingAudioFile;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = ActivityListLoadState.loading;
      _error = null;
    });
    final result = await sl<GetHalaqaActivityUseCase>()(
      GetHalaqaActivityParams(
        halaqaId: widget.halaqaId,
        activityId: widget.activityId,
        includeThread: true,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _status = ActivityListLoadState.error;
        _error = failure.message;
      }),
      (entity) => setState(() {
        _activity = HalaqaActivityUiMapper.toUi(entity);
        _status = ActivityListLoadState.loaded;
      }),
    );
  }

  String get _studentId {
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) return auth.user.uid;
    } catch (_) {}
    return '';
  }

  String get _studentName {
    try {
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated && auth.user.name.trim().isNotEmpty) {
        return auth.user.name.trim();
      }
    } catch (_) {}
    return 'طالب';
  }

  bool get _canSend {
    final a = _activity;
    if (a == null || _sending) return false;
    final textOk =
        a.allowedResponseTypes.contains(ActivityResponseTypeUi.text) &&
            _textCtrl.text.trim().isNotEmpty;
    final imageOk =
        a.allowedResponseTypes.contains(ActivityResponseTypeUi.image) &&
            _pendingImageFile != null;
    final audioOk =
        a.allowedResponseTypes.contains(ActivityResponseTypeUi.audio) &&
            _pendingAudioFile != null;
    return textOk || imageOk || audioOk;
  }

  Future<void> _pickImage() async {
    if (!_activity!.allowedResponseTypes
        .contains(ActivityResponseTypeUi.image)) {
      AppSnackBar.showInfo(context, 'هذه المهمة لا تقبل صورة');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _pendingImageFile = File(path));
  }

  Future<void> _pickAudio() async {
    if (!_activity!.allowedResponseTypes
        .contains(ActivityResponseTypeUi.audio)) {
      AppSnackBar.showInfo(context, 'هذه المهمة لا تقبل صوتاً');
      return;
    }
    if (!AppCapabilities.audioUploadsEnabled) {
      AppSnackBar.showError(
        context,
        'رفع الصوت غير مفعّل حالياً',
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _pendingAudioFile = File(path));
  }

  Future<void> _send() async {
    final a = _activity;
    if (a == null || !_canSend) return;
    final studentId = _studentId;
    if (studentId.isEmpty) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول لإرسال الرد');
      return;
    }

    setState(() => _sending = true);
    final result = await sl<SubmitHalaqaActivityResponseUseCase>()(
      SubmitHalaqaActivityResponseParams(
        activityId: widget.activityId,
        halaqaId: widget.halaqaId,
        studentId: studentId,
        studentName: _studentName,
        text: a.allowedResponseTypes.contains(ActivityResponseTypeUi.text)
            ? _textCtrl.text
            : null,
        imageFile: _pendingImageFile,
        audioFile: _pendingAudioFile,
      ),
    );
    if (!mounted) return;

    await result.fold(
      (failure) async {
        setState(() => _sending = false);
        AppSnackBar.showError(context, failure.message);
      },
      (_) async {
        _textCtrl.clear();
        _pendingImageFile = null;
        _pendingAudioFile = null;
        setState(() => _sending = false);
        AppSnackBar.showSuccess(context, 'تم إرسال ردك');
        await _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('المهمة')),
      body: switch (_status) {
        ActivityListLoadState.loading => const AppLoadingWidget(),
        ActivityListLoadState.error => AppErrorWidget(
            message: _error ?? 'حدث خطأ',
            onRetry: _load,
          ),
        ActivityListLoadState.loaded => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.paddingM),
                  children: [
                    _PromptHeader(activity: _activity!),
                    const SizedBox(height: AppSizes.paddingM),
                    Text(
                      'المحادثة',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_activity!.thread.isEmpty)
                      AppCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.paddingM,
                          ),
                          child: Text(
                            'كن أول من يرد على هذه المهمة.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._activity!.thread.map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ActivityThreadBubble(message: m),
                        ),
                      ),
                  ],
                ),
              ),
              _ComposerBar(
                activity: _activity!,
                textController: _textCtrl,
                pendingImage: _pendingImageFile != null,
                pendingAudio: _pendingAudioFile != null,
                sending: _sending,
                canSend: _canSend,
                onTextChanged: (_) => setState(() {}),
                onToggleImage: () {
                  if (_pendingImageFile != null) {
                    setState(() => _pendingImageFile = null);
                    return;
                  }
                  _pickImage();
                },
                onToggleAudio: () {
                  if (_pendingAudioFile != null) {
                    setState(() => _pendingAudioFile = null);
                    return;
                  }
                  _pickAudio();
                },
                onSend: _send,
              ),
            ],
          ),
      },
    );
  }
}

class _PromptHeader extends StatelessWidget {
  final HalaqaActivityUi activity;

  const _PromptHeader({required this.activity});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    activity.teacherName,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    formatDateDmy(activity.createdAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              UserAvatar(name: activity.teacherName, size: AppSizes.avatarM),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            activity.prompt,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
          ),
          if (activity.deadline != null) ...[
            const SizedBox(height: 10),
            Text(
              'موعد اختياري: ${formatDateDmy(activity.deadline!)}',
              textAlign: TextAlign.right,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.gradeGood,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: activity.allowedResponseTypes
                .map(
                  (t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSizes.radiusS),
                    ),
                    child: Text(
                      t.labelAr,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final HalaqaActivityUi activity;
  final TextEditingController textController;
  final bool pendingImage;
  final bool pendingAudio;
  final bool sending;
  final bool canSend;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onToggleImage;
  final VoidCallback onToggleAudio;
  final VoidCallback onSend;

  const _ComposerBar({
    required this.activity,
    required this.textController,
    required this.pendingImage,
    required this.pendingAudio,
    required this.sending,
    required this.canSend,
    required this.onTextChanged,
    required this.onToggleImage,
    required this.onToggleAudio,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final allowText =
        activity.allowedResponseTypes.contains(ActivityResponseTypeUi.text);
    final allowImage =
        activity.allowedResponseTypes.contains(ActivityResponseTypeUi.image);
    final allowAudio =
        activity.allowedResponseTypes.contains(ActivityResponseTypeUi.audio);

    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingImage || pendingAudio)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      if (pendingImage)
                        Expanded(
                          child: _PendingChip(
                            icon: Icons.image_outlined,
                            label: 'صورة جاهزة للإرسال',
                            onClear: onToggleImage,
                          ),
                        ),
                      if (pendingImage && pendingAudio)
                        const SizedBox(width: 8),
                      if (pendingAudio)
                        Expanded(
                          child: _PendingChip(
                            icon: Icons.mic_none_rounded,
                            label: 'تسجيل جاهز للإرسال',
                            onClear: onToggleAudio,
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'إرسال',
                    onPressed: canSend ? onSend : null,
                    icon: sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                  ),
                  if (allowAudio)
                    IconButton(
                      tooltip: AppCapabilities.audioUploadsEnabled
                          ? 'صوت'
                          : 'صوت (غير مفعّل)',
                      onPressed: onToggleAudio,
                      icon: Icon(
                        Icons.mic_none_rounded,
                        color: pendingAudio
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  if (allowImage)
                    IconButton(
                      tooltip: 'صورة',
                      onPressed: onToggleImage,
                      icon: Icon(
                        Icons.image_outlined,
                        color: pendingImage
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      enabled: allowText,
                      minLines: 1,
                      maxLines: 4,
                      textAlign: TextAlign.right,
                      onChanged: onTextChanged,
                      decoration: InputDecoration(
                        hintText: allowText
                            ? 'اكتب ردك…'
                            : 'النص غير مسموح في هذه المهمة',
                        filled: true,
                        fillColor: AppColors.background,
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
  }
}

class _PendingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onClear;

  const _PendingChip({
    required this.icon,
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(icon, size: 18, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// Home entry card — opens [StudentActivitiesPage] via Navigator (no new route).
class StudentActivitiesHomeEntry extends StatefulWidget {
  final String? halaqaId;

  const StudentActivitiesHomeEntry({super.key, required this.halaqaId});

  @override
  State<StudentActivitiesHomeEntry> createState() =>
      _StudentActivitiesHomeEntryState();
}

class _StudentActivitiesHomeEntryState
    extends State<StudentActivitiesHomeEntry> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCount());
  }

  Future<void> _loadCount() async {
    final id = widget.halaqaId?.trim() ?? '';
    if (id.isEmpty) return;
    final result = await sl<ListHalaqaActivitiesUseCase>()(
      HalaqaActivityHalaqaParams(id),
    );
    if (!mounted) return;
    result.fold(
      (_) {},
      (items) => setState(() => _count = items.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.halaqaId?.trim() ?? '';
    if (id.isEmpty) return const SizedBox.shrink();

    return AppCard(
      onTap: () {
        Navigator.of(context)
            .push(
          MaterialPageRoute<void>(
            builder: (_) => StudentActivitiesPage(halaqaId: id),
          ),
        )
            .then((_) {
          if (mounted) _loadCount();
        });
      },
      child: Row(
        children: [
          const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'أنشطة الحلقة',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _count == 0
                    ? 'مهام خفيفة من المعلم'
                    : '$_count مهمة — اضغط للعرض والرد',
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
              Icons.tips_and_updates_outlined,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../domain/entities/chat_entities.dart';
import '../media/chat_media_loader.dart';

/// `1.2 ميجابايت` / `340 كيلوبايت`.
String formatChatFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes بايت';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} كيلوبايت';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.right)),
    );
}

// ── Image ────────────────────────────────────────────────────────────────────

class ChatImageView extends StatefulWidget {
  final ChatMediaEntity media;
  final ChatMediaLoader loader;

  const ChatImageView({super.key, required this.media, required this.loader});

  static const double maxWidth = 240;
  static const double maxHeight = 280;

  @override
  State<ChatImageView> createState() => _ChatImageViewState();
}

class _ChatImageViewState extends State<ChatImageView> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final result = await widget.loader.imageBytes(widget.media);
    if (!mounted) return;
    setState(() {
      result.fold((f) => _error = f.message, (b) => _bytes = b);
    });
  }

  void _openFullScreen() {
    final bytes = _bytes;
    if (bytes == null) {
      _load();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullScreenImage(bytes: bytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final Widget child;
    if (bytes != null) {
      child = Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _MediaPlaceholder(
          icon: Icons.broken_image_outlined,
          label: 'تعذر عرض الصورة',
        ),
      );
    } else if (_error != null) {
      child = _MediaPlaceholder(
        icon: Icons.refresh_rounded,
        label: _error!,
        onTap: _load,
      );
    } else {
      child = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Semantics(
      image: true,
      label: 'صورة — اضغط للعرض',
      button: true,
      child: GestureDetector(
        onTap: _openFullScreen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ChatImageView.maxWidth,
              maxHeight: ChatImageView.maxHeight,
              minWidth: 120,
              minHeight: 120,
            ),
            child: ColoredBox(
              color: AppColors.border.withValues(alpha: 0.25),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final Uint8List bytes;

  const _FullScreenImage({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'إغلاق',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MediaPlaceholder({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Voice ────────────────────────────────────────────────────────────────────

class ChatVoiceView extends StatefulWidget {
  final ChatMediaEntity media;
  final ChatMediaLoader loader;
  final bool isMine;

  const ChatVoiceView({
    super.key,
    required this.media,
    required this.loader,
    required this.isMine,
  });

  @override
  State<ChatVoiceView> createState() => _ChatVoiceViewState();
}

class _ChatVoiceViewState extends State<ChatVoiceView> {
  AudioPlayer? _player;
  final List<StreamSubscription<Object?>> _subs = [];
  bool _loading = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    final ms = widget.media.durationMs;
    if (ms != null) _duration = Duration(milliseconds: ms);
  }

  Future<void> _toggle() async {
    final existing = _player;
    if (existing != null) {
      if (_playing) {
        await existing.pause();
      } else {
        if (_duration != null && _position >= _duration!) {
          await existing.seek(Duration.zero);
        }
        unawaited(existing.play());
      }
      return;
    }

    setState(() => _loading = true);
    final file = await widget.loader.localFile(widget.media);
    if (!mounted) return;
    await file.fold(
      (failure) async {
        setState(() => _loading = false);
        _showSnack(context, failure.message);
      },
      (f) async {
        final player = AudioPlayer();
        _player = player;
        _subs
          ..add(
            player.playerStateStream.listen((s) {
              if (!mounted) return;
              final done = s.processingState == ProcessingState.completed;
              setState(() => _playing = s.playing && !done);
              if (done) {
                unawaited(player.pause());
                unawaited(player.seek(Duration.zero));
              }
            }),
          )
          ..add(
            player.positionStream.listen((p) {
              if (mounted) setState(() => _position = p);
            }),
          )
          ..add(
            player.durationStream.listen((d) {
              if (mounted && d != null) setState(() => _duration = d);
            }),
          );
        try {
          await player.setFilePath(f.path);
          if (!mounted) return;
          setState(() => _loading = false);
          unawaited(player.play());
        } on Object {
          if (!mounted) return;
          setState(() => _loading = false);
          _showSnack(context, 'تعذر تشغيل الرسالة الصوتية');
        }
      },
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? AppColors.onPrimary : AppColors.primaryDark;
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final shown = _playing || _position > Duration.zero ? _position : total;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: _playing ? 'إيقاف مؤقت' : 'تشغيل',
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: fg,
                      size: 28,
                    ),
                    onPressed: _toggle,
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: fg,
                backgroundColor: fg.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatDurationMmSs(shown),
            style: AppTextStyles.labelSmall.copyWith(color: fg, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── File ─────────────────────────────────────────────────────────────────────

class ChatFileView extends StatefulWidget {
  final ChatMediaEntity media;
  final ChatMediaLoader loader;
  final bool isMine;

  const ChatFileView({
    super.key,
    required this.media,
    required this.loader,
    required this.isMine,
  });

  @override
  State<ChatFileView> createState() => _ChatFileViewState();
}

class _ChatFileViewState extends State<ChatFileView> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final result = await widget.loader.localFile(widget.media);
    if (!mounted) return;
    setState(() => _opening = false);
    await result.fold((failure) async => _showSnack(context, failure.message), (
      file,
    ) async {
      final opened = await OpenFilex.open(file.path);
      if (!mounted) return;
      if (opened.type != ResultType.done) {
        _showSnack(context, 'لا يوجد تطبيق على الجهاز لفتح هذا الملف');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? AppColors.onPrimary : AppColors.textPrimary;
    final isPdf = widget.media.contentType == 'application/pdf';
    final size = formatChatFileSize(widget.media.sizeBytes);
    return Semantics(
      button: true,
      label: 'فتح الملف ${widget.media.fileName}',
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 220,
          child: Row(
            children: [
              Icon(
                isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.description_rounded,
                color: fg,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.media.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (size.isNotEmpty)
                      Text(
                        size,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: fg.withValues(alpha: 0.75),
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 22,
                height: 22,
                child: _opening
                    ? CircularProgressIndicator(strokeWidth: 2, color: fg)
                    : Icon(Icons.download_rounded, color: fg, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

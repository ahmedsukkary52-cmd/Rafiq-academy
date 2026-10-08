import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
import '../media/chat_voice_recorder.dart';

typedef ChatAttachmentPicker =
    Future<ChatAttachmentDraft?> Function(ChatMessageType type);

/// Default picker: images through the gallery picker (iOS converts to JPEG
/// via compression), documents restricted to PDF / Word.
Future<ChatAttachmentDraft?> pickChatAttachment(ChatMessageType type) async {
  final result = type == ChatMessageType.image
      ? await FilePicker.platform.pickFiles(
          type: FileType.image,
          compressionQuality: 80,
        )
      : await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ChatMediaPolicy.documentExtensions,
        );
  final file = result?.files.singleOrNull;
  if (file == null) return null;
  final path = file.path;
  if (path == null) throw const FileSystemException('no path');
  return ChatAttachmentDraft(
    type: type,
    localPath: path,
    fileName: file.name,
    contentType: ChatMediaPolicy.contentTypeFor(type, file.name) ?? '',
    sizeBytes: file.size,
  );
}

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSendText;
  final ValueChanged<ChatAttachmentDraft> onAttachment;
  final ChatVoiceRecorder Function() recorderFactory;
  final ChatAttachmentPicker pickAttachment;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSendText,
    required this.onAttachment,
    required this.recorderFactory,
    this.pickAttachment = pickChatAttachment,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  ChatVoiceRecorder? _recorder;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  bool _recording = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _ticker?.cancel();
    final recorder = _recorder;
    if (recorder != null) {
      if (_recording) unawaited(recorder.cancel());
      unawaited(recorder.dispose());
    }
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message, textAlign: TextAlign.right)),
      );
  }

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    widget.controller.clear();
    widget.onSendText(text);
  }

  Future<void> _pick(ChatMessageType type) async {
    try {
      final draft = await widget.pickAttachment(type);
      if (draft != null) widget.onAttachment(draft);
    } on Object {
      _snack('تعذر قراءة الملف المحدد');
    }
  }

  Future<void> _openAttachSheet() async {
    final type = await showModalBottomSheet<ChatMessageType>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('صورة'),
                subtitle: const Text('JPG أو PNG أو WEBP • حتى 10 ميجابايت'),
                onTap: () => Navigator.pop(ctx, ChatMessageType.image),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('ملف'),
                subtitle: const Text('PDF أو Word • حتى 10 ميجابايت'),
                onTap: () => Navigator.pop(ctx, ChatMessageType.file),
              ),
            ],
          ),
        ),
      ),
    );
    if (type != null) await _pick(type);
  }

  Future<void> _startRecording() async {
    if (_busy || _recording) return;
    _busy = true;
    final recorder = _recorder ??= widget.recorderFactory();
    try {
      final allowed = await recorder.hasPermission();
      if (!mounted) return;
      if (!allowed) {
        _snack('يلزم السماح بالوصول إلى الميكروفون لتسجيل رسالة صوتية');
        return;
      }
      await recorder.start();
      if (!mounted) return;
      _stopwatch
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_stopwatch.elapsed >= ChatMediaPolicy.voiceMaxDuration) {
          unawaited(_finishRecording());
        } else if (mounted) {
          setState(() {});
        }
      });
      setState(() => _recording = true);
    } on Object {
      if (mounted) _snack('تعذر بدء التسجيل');
    } finally {
      _busy = false;
    }
  }

  void _stopClock() {
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.stop();
  }

  Future<void> _finishRecording() async {
    if (!_recording) return;
    _stopClock();
    final durationMs = min(
      _stopwatch.elapsedMilliseconds,
      ChatMediaPolicy.voiceMaxDuration.inMilliseconds,
    );
    setState(() => _recording = false);

    String? path;
    try {
      path = await _recorder?.stop();
    } on Object {
      path = null;
    }
    if (!mounted) return;
    if (path == null) {
      _snack('تعذر حفظ التسجيل');
      return;
    }
    final file = File(path);
    if (durationMs < 1000) {
      unawaited(file.delete().then((_) {}, onError: (_) {}));
      _snack('التسجيل قصير جداً');
      return;
    }
    final size = await file.length();
    widget.onAttachment(
      ChatAttachmentDraft(
        type: ChatMessageType.voice,
        localPath: path,
        fileName: 'voice.${ChatMediaPolicy.voiceExtension}',
        contentType: ChatMediaPolicy.voiceContentType,
        sizeBytes: size,
        durationMs: durationMs,
      ),
    );
  }

  Future<void> _cancelRecording() async {
    if (!_recording) return;
    _stopClock();
    setState(() => _recording = false);
    try {
      await _recorder?.cancel();
    } on Object {
      // Nothing was sent; a leftover temp file is OS-managed.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: Color(0xFFE8EEF0), width: 0.8)),
        ),
        child: _recording ? _buildRecordingBar() : _buildInputRow(),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'إلغاء التسجيل',
          onPressed: _cancelRecording,
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'جارٍ التسجيل ${formatDurationMmSs(_stopwatch.elapsed)}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _RoundAction(
          icon: Icons.send_rounded,
          tooltip: 'إرسال التسجيل',
          onTap: _finishRecording,
        ),
      ],
    );
  }

  Widget _buildInputRow() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'إرفاق',
          onPressed: _openAttachSheet,
          icon: const Icon(
            Icons.attach_file_rounded,
            color: AppColors.primaryDark,
          ),
        ),
        Expanded(
          child: TextField(
            controller: widget.controller,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: 5,
            minLines: 1,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            inputFormatters: [
              LengthLimitingTextInputFormatter(ChatMediaPolicy.textMaxChars),
            ],
            style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'اكتب رسالة...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Color(0xFFE8EEF0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        hasText
            ? _RoundAction(
                icon: Icons.send_rounded,
                tooltip: 'إرسال',
                onTap: _send,
              )
            : _RoundAction(
                icon: Icons.mic_rounded,
                tooltip: 'تسجيل رسالة صوتية',
                onTap: _startRecording,
              ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppColors.onPrimary, size: 20),
          ),
        ),
      ),
    );
  }
}

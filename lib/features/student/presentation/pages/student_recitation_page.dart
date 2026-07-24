import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/utils/time_format.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../homework/domain/repositories/homework_repository.dart';
import '../../../homework/domain/usecases/homework_usecases.dart';

/// سياق إرسال التسميع لواجب حقيقي (Firebase Storage + recitationRecords).
class HomeworkRecitationContext {
  final String studentId;
  final String studentName;
  final String teacherId;
  final String halaqaId;
  final String assignmentId;
  final String taskId;
  final String versesRange;

  const HomeworkRecitationContext({
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.halaqaId,
    required this.assignmentId,
    required this.taskId,
    required this.versesRange,
  });
}

class Recording {
  final String path;
  final String surahName;
  final int pageNumber;
  final int durationSeconds;
  final DateTime dateTime;

  Recording({
    required this.path,
    required this.surahName,
    required this.pageNumber,
    required this.durationSeconds,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'surahName': surahName,
      'pageNumber': pageNumber,
      'durationSeconds': durationSeconds,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      path: json['path'] as String,
      surahName: json['surahName'] as String,
      pageNumber: json['pageNumber'] as int,
      durationSeconds: json['durationSeconds'] as int,
      dateTime: DateTime.parse(json['dateTime'] as String),
    );
  }
}

class StudentRecitationPage extends StatefulWidget {
  final String surahName;
  final int pageNumber;
  final int startAyah;
  final int endAyah;

  /// لو موجود → رفع حقيقي للمعلم بدل snackbar وهمي
  final HomeworkRecitationContext? homeworkContext;

  const StudentRecitationPage({
    super.key,
    required this.surahName,
    required this.pageNumber,
    this.startAyah = 1,
    this.endAyah = 10,
    this.homeworkContext,
  });

  @override
  State<StudentRecitationPage> createState() => _StudentRecitationPageState();
}

class _StudentRecitationPageState extends State<StudentRecitationPage> {
  // Recording
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;
  int _recordDurationSeconds = 0;
  Timer? _recordTimer;
  bool _hasRecorded = false;

  // Playback
  final AudioPlayer _recordingPlayer = AudioPlayer();
  bool _isPlayingRecording = false;
  StreamSubscription<PlayerState>? _playerStateSub;

  // Saved recordings
  List<Recording> _savedRecordings = [];

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
    _loadSavedRecordings();
  }

  Future<void> _loadSavedRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('savedRecordings');
    if (jsonList != null) {
      setState(() {
        _savedRecordings = jsonList
            .map(
              (jsonStr) => Recording.fromJson(
                jsonDecode(jsonStr) as Map<String, dynamic>,
              ),
            )
            .toList();
      });
    }
  }

  Future<void> _saveRecording(Recording recording) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedRecordings.insert(0, recording);
    });
    final jsonList = _savedRecordings
        .map((r) => jsonEncode(r.toJson()))
        .toList();
    await prefs.setStringList('savedRecordings', jsonList);
  }

  void _setupAudioListeners() {
    _playerStateSub = _recordingPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlayingRecording = state.playing);
    });
  }

  String _toArabicDigits(int n) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => digits[int.parse(c)]).join();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final path =
            '${appDir.path}/recitation_${DateTime.now().millisecondsSinceEpoch}.m4a';

        setState(() {
          _recordedFilePath = path;
          _isRecording = true;
          _recordDurationSeconds = 0;
        });

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordDurationSeconds++);
          }
        });
      }
    } catch (e) {
      debugPrint('Recording start error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'فشل بدء تسجيل الصوت');
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
      _hasRecorded = path != null;
    });
    if (path != null) {
      // حفظ محلي اختياري فقط لمسار المصحف — واجب التسميع يعتمد على الرفع السحابي
      if (widget.homeworkContext == null) {
        final newRecording = Recording(
          path: path,
          surahName: widget.surahName,
          pageNumber: widget.pageNumber,
          durationSeconds: _recordDurationSeconds,
          dateTime: DateTime.now(),
        );
        await _saveRecording(newRecording);
      }
      await _recordingPlayer.setFilePath(path);
    }
  }

  void _togglePlayRecording() {
    if (_isPlayingRecording) {
      _recordingPlayer.pause();
    } else {
      _recordingPlayer.play();
    }
  }

  void _submitRecitation() {
    if (_recordedFilePath == null) return;
    final isHomework = widget.homeworkContext != null;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isHomework ? 'إرسال التسميع' : 'حفظ التسجيل',
          textAlign: TextAlign.right,
        ),
        content: Text(
          isHomework
              ? 'سيتم رفع التسجيل للمعلم عبر الإنترنت. هل تريد المتابعة؟'
              : 'سيتم حفظ التسجيل على جهازك فقط. رفع التسجيل للمعلم غير متاح حالياً.',
          textAlign: TextAlign.right,
          style: const TextStyle(fontFamily: 'NotoNaskhArabic'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _performSubmit();
            },
            child: Text(
              isHomework ? 'إرسال' : 'حفظ',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performSubmit() async {
    final path = _recordedFilePath;
    if (path == null) return;

    final ctx = widget.homeworkContext;
    if (ctx == null) {
      // مسار المصحف القديم: بدون رفع سحابي بعد
      if (mounted) {
        AppSnackBar.showSuccess(context, 'تم حفظ التسجيل محلياً');
        setState(() {
          _hasRecorded = false;
          _recordedFilePath = null;
        });
      }
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'جاري رفع التسجيل للمعلم...',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'NotoNaskhArabic'),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await sl<SubmitHomeworkRecitationUseCase>()(
      SubmitRecitationParams(
        localFilePath: path,
        studentId: ctx.studentId,
        studentName: ctx.studentName,
        teacherId: ctx.teacherId,
        halaqaId: ctx.halaqaId,
        assignmentId: ctx.assignmentId,
        taskId: ctx.taskId,
        versesRange: ctx.versesRange,
        durationSeconds: _recordDurationSeconds,
      ),
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close progress

    final failure = result.fold((f) => f, (_) => null);
    if (failure != null) {
      // المهمة تبقى غير مكتملة — الملف المحلي يبقى لإعادة المحاولة
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'فشل الرفع',
            textAlign: TextAlign.right,
            style: TextStyle(fontFamily: 'NotoNaskhArabic'),
          ),
          content: Text(
            failure.message.isNotEmpty
                ? failure.message
                : 'فشل الرفع، حاول تاني',
            textAlign: TextAlign.right,
            style: const TextStyle(fontFamily: 'NotoNaskhArabic'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('إعادة محاولة'),
            ),
          ],
        ),
      );
      if (retry == true && mounted) {
        await _performSubmit();
      }
      return;
    }

    // احذف الملف المحلي بعد نجاح الرفع — مش نخزنه في SharedPreferences
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    AppSnackBar.showSuccess(
      context,
      'تم إرسال التسجيل للمعلم — في انتظار المراجعة 🎉',
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _recordingPlayer.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'تسميع بالصوت',
                          style: GoogleFonts.amiri(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سورة ${widget.surahName} • صفحة ${_toArabicDigits(widget.pageNumber)}',
                          style: GoogleFonts.amiri(
                            fontSize: 14,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Required to Recite Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'المطلوب تسميعه 📖',
                            style: GoogleFonts.amiri(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF006064),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سورة ${widget.surahName} — من آية ${_toArabicDigits(widget.startAyah)} إلى ${_toArabicDigits(widget.endAyah)}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Mic Button Area
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated Rings
                        if (_isRecording) ...[
                          for (int i = 3; i >= 1; i--)
                            TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 800 + i * 200),
                              tween: Tween(begin: 0.6, end: 1.4),
                              curve: Curves.easeOut,
                              builder: (context, scale, child) {
                                return Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: 1.0 - (i * 0.3),
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                width: 180 + i * 30,
                                height: 180 + i * 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00ACC1,
                                    ).withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        // Main Mic Button
                        GestureDetector(
                          onTap: _isRecording
                              ? _stopRecording
                              : _startRecording,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isRecording
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFF00ACC1),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (_isRecording
                                              ? const Color(0xFFE53935)
                                              : const Color(0xFF00ACC1))
                                          .withOpacity(0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRecording
                                  ? Icons.stop
                                  : Icons.mic_none_rounded,
                              size: 70,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Timer
                    Text(
                      formatSecondsMmSs(_recordDurationSeconds),
                      style: GoogleFonts.amiri(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recording indicator
                    if (_isRecording)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'جاري التسجيل...',
                          style: TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00ACC1),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    // Action Buttons (Check and X)
                    if (_hasRecorded)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _hasRecorded = false;
                                _recordedFilePath = null;
                                _recordDurationSeconds = 0;
                              });
                            },
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFCDD2),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 36,
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                          GestureDetector(
                            onTap: _togglePlayRecording,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFE0F7FA),
                              ),
                              child: Icon(
                                _isPlayingRecording
                                    ? Icons.pause_rounded
                                    : Icons.check_rounded,
                                size: 36,
                                color: const Color(0xFF00ACC1),
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 40),

                    // Send Button
                    if (_hasRecorded)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          onPressed: _submitRecitation,
                          child: Text(
                            widget.homeworkContext != null
                                ? 'إرسال التسميع للمعلمة'
                                : 'حفظ التسجيل محلياً',
                            style: GoogleFonts.amiri(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Saved recordings
                    if (_savedRecordings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تسجيلاتي السابقة',
                              style: GoogleFonts.amiri(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 150,
                              child: ListView.builder(
                                scrollDirection: Axis.vertical,
                                itemCount: _savedRecordings.length,
                                itemBuilder: (context, index) {
                                  final rec = _savedRecordings[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F9FA),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.play_circle_outline,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'سورة ${rec.surahName}',
                                                    style: GoogleFonts.amiri(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${formatDurationMmSs(Duration(seconds: rec.durationSeconds))} • ${rec.dateTime.day}/${rec.dateTime.month}',
                                                    style: GoogleFonts.amiri(
                                                      fontSize: 12,
                                                      color: Colors.black
                                                          .withOpacity(0.6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              if (_recordedFilePath ==
                                                      rec.path &&
                                                  _isPlayingRecording) {
                                                await _recordingPlayer.pause();
                                              } else {
                                                await _recordingPlayer
                                                    .setFilePath(rec.path);
                                                await _recordingPlayer.play();
                                              }
                                            },
                                            icon: Icon(
                                              (_recordedFilePath == rec.path &&
                                                      _isPlayingRecording)
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
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

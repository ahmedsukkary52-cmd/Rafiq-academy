import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/policies/chat_media_policy.dart';

/// Recorder port so the composer can be tested without platform channels.
abstract class ChatVoiceRecorder {
  Future<bool> hasPermission();

  /// Starts recording AAC-LC (`audio/mp4`, `.m4a`) to a new temp file.
  Future<void> start();

  /// Stops and returns the recorded file path (null if nothing recorded).
  Future<String?> stop();

  /// Stops and deletes the current recording.
  Future<void> cancel();

  Future<void> dispose();
}

class RecordChatVoiceRecorder implements ChatVoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}'
        'chat_voice_${DateTime.now().millisecondsSinceEpoch}'
        '.${ChatMediaPolicy.voiceExtension}';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

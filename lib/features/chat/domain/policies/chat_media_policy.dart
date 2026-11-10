import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../../../shared/domain/storage_paths_contract.dart';
import '../entities/chat_entities.dart';

/// A locally picked / recorded file waiting to be uploaded and sent.
class ChatAttachmentDraft extends Equatable {
  final ChatMessageType type;
  final String localPath;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final int? durationMs;

  const ChatAttachmentDraft({
    required this.type,
    required this.localPath,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.durationMs,
  });

  @override
  List<Object?> get props => [
    type,
    localPath,
    fileName,
    contentType,
    sizeBytes,
    durationMs,
  ];
}

/// Payload for `sendChatMessage` once the object is in Storage.
class ChatSendMedia extends Equatable {
  final String storagePath;
  final String fileName;
  final int? durationMs;

  const ChatSendMedia({
    required this.storagePath,
    required this.fileName,
    this.durationMs,
  });

  @override
  List<Object?> get props => [storagePath, fileName, durationMs];
}

/// Client mirror of `functions/src/chat/chatMessageContract.ts`. UX only —
/// `sendChatMessage` and storage.rules are authoritative.
class ChatMediaPolicy {
  const ChatMediaPolicy._();

  static const int textMaxChars = 4000;
  static const int fileNameMaxChars = 120;
  static const Duration voiceMaxDuration = Duration(minutes: 10);
  static const Duration editWindow = Duration(minutes: 15);
  static const Duration deleteWindow = Duration(minutes: 60);

  static const int imageMaxBytes = 10 * 1024 * 1024;
  static const int voiceMaxBytes = 20 * 1024 * 1024;
  static const int fileMaxBytes = 10 * 1024 * 1024;

  static const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> documentExtensions = ['pdf', 'doc', 'docx'];

  /// Recorder output (AAC-LC in an MPEG-4 container).
  static const String voiceContentType = 'audio/mp4';
  static const String voiceExtension = 'm4a';

  static const Map<String, String> _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'm4a': 'audio/mp4',
  };

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// Content type for an allowed extension of [type], or null if refused.
  static String? contentTypeFor(ChatMessageType type, String fileName) {
    final ext = extensionOf(fileName);
    final allowed = switch (type) {
      ChatMessageType.image => imageExtensions,
      ChatMessageType.file => documentExtensions,
      ChatMessageType.voice => const [voiceExtension],
      ChatMessageType.text => const <String>[],
    };
    return allowed.contains(ext) ? _contentTypes[ext] : null;
  }

  static int maxBytesFor(ChatMessageType type) => switch (type) {
    ChatMessageType.image => imageMaxBytes,
    ChatMessageType.voice => voiceMaxBytes,
    ChatMessageType.file => fileMaxBytes,
    ChatMessageType.text => 0,
  };

  /// Arabic validation message, or null when the draft may be uploaded.
  static String? validate(ChatAttachmentDraft draft) {
    if (draft.type == ChatMessageType.text) return 'نوع الرسالة غير صالح';
    if (contentTypeFor(draft.type, draft.fileName) != draft.contentType) {
      return switch (draft.type) {
        ChatMessageType.image =>
          'صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WEBP',
        ChatMessageType.file => 'نوع الملف غير مدعوم. المسموح: PDF أو Word',
        _ => 'صيغة التسجيل غير مدعومة',
      };
    }
    if (draft.sizeBytes <= 0) return 'الملف فارغ';
    if (draft.sizeBytes >= maxBytesFor(draft.type)) {
      final mb = maxBytesFor(draft.type) ~/ (1024 * 1024);
      return 'حجم الملف أكبر من المسموح ($mb ميجابايت)';
    }
    if (draft.type == ChatMessageType.voice) {
      final d = draft.durationMs ?? 0;
      if (d <= 0) return 'التسجيل قصير جداً';
      if (d > voiceMaxDuration.inMilliseconds) return 'التسجيل أطول من المسموح';
    }
    return null;
  }

  /// Display name sent to the server (no path separators / control chars).
  static String displayFileName(String original) {
    var name = original
        .replaceAll(RegExp(r'[\\/\u0000-\u001f\u007f]'), '_')
        .trim();
    if (name.isEmpty || name == '.' || name == '..') name = 'file';
    if (name.length <= fileNameMaxChars) return name;
    final ext = extensionOf(name);
    final keep = fileNameMaxChars - (ext.isEmpty ? 0 : ext.length + 1);
    return ext.isEmpty
        ? name.substring(0, keep)
        : '${name.substring(0, keep)}.$ext';
  }

  /// ASCII object name inside the message folder (display name is separate).
  static String storageFileName(ChatAttachmentDraft draft) {
    final ext = extensionOf(draft.fileName);
    final base = switch (draft.type) {
      ChatMessageType.image => 'image',
      ChatMessageType.voice => 'voice',
      _ => 'file',
    };
    return ext.isEmpty ? base : '$base.$ext';
  }

  static String storagePath({
    required String conversationId,
    required String messageId,
    required ChatAttachmentDraft draft,
  }) {
    final fileName = storageFileName(draft);
    return switch (draft.type) {
      ChatMessageType.image => StoragePathsContract.chatMedia(
        conversationId: conversationId,
        messageId: messageId,
        fileName: fileName,
      ),
      ChatMessageType.voice => StoragePathsContract.chatVoice(
        conversationId: conversationId,
        messageId: messageId,
        fileName: fileName,
      ),
      _ => StoragePathsContract.chatAttachment(
        conversationId: conversationId,
        messageId: messageId,
        fileName: fileName,
      ),
    };
  }

  static bool canEdit(MessageEntity message, String uid, {DateTime? now}) {
    if (message.deleted || message.senderId != uid) return false;
    if (message.type != ChatMessageType.text) return false;
    final at = now ?? DateTime.now();
    return at.difference(message.sentAt) <= editWindow;
  }

  /// Mirrors `canSoftDeleteMessage`: senders within [deleteWindow], Admin
  /// (moderation) at any time.
  static bool canDelete(
    MessageEntity message,
    String uid, {
    required bool isAdmin,
    DateTime? now,
  }) {
    if (message.deleted) return false;
    if (isAdmin) return true;
    if (message.senderId != uid) return false;
    final at = now ?? DateTime.now();
    return at.difference(message.sentAt) <= deleteWindow;
  }
}

/// Client-generated, retry-stable message ids (`^[A-Za-z0-9_-]{10,40}$`).
class ChatMessageIds {
  const ChatMessageIds._();

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final _pattern = RegExp(r'^[A-Za-z0-9_-]{10,40}$');

  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      20,
      (_) => _alphabet[r.nextInt(_alphabet.length)],
    ).join();
  }

  static bool isValid(String id) => _pattern.hasMatch(id);
}

import 'entities/content_file_entity.dart';

/// Halaqa shared content (P0 §8): PDF, audio, images and documents only.
///
/// Mirrors `storage.rules` `content_library/{halaqaId}/{uploadedBy}/{file}`
/// (allowed content types + size cap). The size cap is an engineering default
/// until a paid-plan storage-limit contract exists.
class ContentUploadPolicy {
  const ContentUploadPolicy._();

  static const int maxBytes = 50 * 1024 * 1024;

  static const Map<String, String> _mimeByExtension = {
    'pdf': 'application/pdf',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'wav': 'audio/wav',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  static List<String> get allowedExtensions => _mimeByExtension.keys.toList();

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// MIME type for [fileName], or `null` when the type is not allowed.
  static String? contentTypeFor(String fileName) =>
      _mimeByExtension[extensionOf(fileName)];

  static ContentFileType fileTypeFor(String fileName) {
    final mime = contentTypeFor(fileName) ?? '';
    if (mime == 'application/pdf') return ContentFileType.pdf;
    if (mime.startsWith('audio/')) return ContentFileType.audio;
    if (mime.startsWith('image/')) return ContentFileType.image;
    return ContentFileType.document;
  }

  /// Storage object path; [halaqaId] and [uploadedBy] must be non-empty.
  static String storagePath({
    required String halaqaId,
    required String uploadedBy,
    required String fileName,
    required int timestampMs,
  }) {
    final ext = extensionOf(fileName);
    return 'content_library/${halaqaId.trim()}/${uploadedBy.trim()}/'
        '$timestampMs${ext.isEmpty ? '' : '.$ext'}';
  }
}

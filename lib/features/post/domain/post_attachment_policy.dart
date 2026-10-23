import '../../../shared/domain/storage_paths_contract.dart';
import '../../../shared/domain/upload_file_policy.dart';
import 'entities/posts_entities.dart';

/// Post attachment formats, limits and Storage layout. Mirrors the
/// `posts/{halaqaId}/{postId}/{fileName}` block in `storage.rules`.
class PostAttachmentPolicy {
  const PostAttachmentPolicy._();

  static const int maxAttachments = 10;

  static const int pdfMaxBytes = 20 * UploadFilePolicy.mb;
  static const int audioMaxBytes = 20 * UploadFilePolicy.mb;
  static const int videoMaxBytes = 50 * UploadFilePolicy.mb;

  static const List<UploadFormat> formats = [
    UploadFormat('pdf', 'application/pdf', pdfMaxBytes),
    UploadFilePolicy.jpg,
    UploadFilePolicy.jpeg,
    UploadFilePolicy.png,
    UploadFormat('mp3', 'audio/mpeg', audioMaxBytes),
    UploadFormat('wav', 'audio/wav', audioMaxBytes),
    UploadFormat('mp4', 'video/mp4', videoMaxBytes),
  ];

  static List<String> get allowedExtensions =>
      UploadFilePolicy.extensionsOf(formats);

  /// Firestore auto-ids; the client pre-generates the post id before upload.
  static final RegExp _postId = RegExp(r'^[A-Za-z0-9]{20}$');
  static final RegExp _objectName = RegExp(
    r'^att_[0-9]{1,2}\.(pdf|jpg|jpeg|png|mp3|wav|mp4)$',
  );

  static UploadFormat? formatFor(String fileName) =>
      UploadFilePolicy.formatFor(fileName, formats);

  static AttachmentType typeFor(UploadFormat format) =>
      switch (format.contentType) {
        'application/pdf' => AttachmentType.pdf,
        'video/mp4' => AttachmentType.video,
        final t when t.startsWith('audio/') => AttachmentType.audio,
        _ => AttachmentType.image,
      };

  static String storageFileName(int index, UploadFormat format) {
    if (index < 0 || index >= maxAttachments) {
      throw RangeError.range(index, 0, maxAttachments - 1, 'index');
    }
    return 'att_$index.${format.extension}';
  }

  static String storagePath({
    required String halaqaId,
    required String postId,
    required int index,
    required UploadFormat format,
  }) {
    if (!_postId.hasMatch(postId)) {
      throw ArgumentError.value(postId, 'postId', 'not a Firestore auto-id');
    }
    return StoragePathsContract.postAttachment(
      halaqaId: halaqaId,
      postId: postId,
      fileName: storageFileName(index, format),
    );
  }

  /// True only for an object inside this post's own folder.
  static bool isTrustedStoragePath(
    String? path, {
    required String halaqaId,
    required String postId,
  }) {
    final p = path?.trim() ?? '';
    if (p.isEmpty || halaqaId.trim().isEmpty || postId.trim().isEmpty) {
      return false;
    }
    final parts = p.split('/');
    return parts.length == 4 &&
        parts[0] == StoragePathsContract.postsPrefix &&
        parts[1] == halaqaId.trim() &&
        parts[2] == postId.trim() &&
        _objectName.hasMatch(parts[3]);
  }

  /// Download ceiling for a trusted path (its format's upload limit).
  static int maxBytesForPath(String path) =>
      formatFor(path)?.maxBytes ?? UploadFilePolicy.imageMaxBytes;

  /// Pre-hardening attachments stored only a Firebase download URL for
  /// `posts/{authorId}/{file}`. Accept it only when it points at this
  /// project's bucket and that author's legacy folder; anything else (an
  /// arbitrary external link) is never opened.
  static bool isLegacyDownloadUrl(
    String? url, {
    required String bucket,
    required String authorId,
  }) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty || bucket.trim().isEmpty || authorId.trim().isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'firebasestorage.googleapis.com' ||
        uri.hasPort && uri.port != 443 ||
        uri.queryParameters['alt'] != 'media') {
      return false;
    }
    final segments = uri.pathSegments;
    if (segments.length != 5 ||
        segments[0] != 'v0' ||
        segments[1] != 'b' ||
        segments[2] != bucket.trim() ||
        segments[3] != 'o') {
      return false;
    }
    final object = segments[4].split('/');
    return object.length == 3 &&
        object[0] == StoragePathsContract.postsPrefix &&
        object[1] == authorId.trim() &&
        object[2].isNotEmpty &&
        object[2] != '.' &&
        object[2] != '..';
  }
}

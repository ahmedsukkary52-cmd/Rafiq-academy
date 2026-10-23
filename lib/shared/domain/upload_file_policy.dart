import 'dart:io';
import 'dart:typed_data';

/// One accepted upload format: a lowercase extension, the exact MIME type
/// written to Storage metadata, and its size ceiling (exclusive).
class UploadFormat {
  final String extension;
  final String contentType;
  final int maxBytes;

  const UploadFormat(this.extension, this.contentType, this.maxBytes);
}

/// Result of [UploadFilePolicy.checkFile]: the accepted format, or an Arabic
/// error message.
class UploadCheck {
  final UploadFormat? format;
  final String? error;

  const UploadCheck._(this.format, this.error);

  const UploadCheck.ok(UploadFormat format) : this._(format, null);

  const UploadCheck.rejected(String error) : this._(null, error);

  bool get isOk => format != null;
}

/// Client-side upload validation shared by every Storage upload flow.
///
/// Mirrors `storage.rules`, which stay authoritative for type and size. The
/// signature check reads the first bytes of the file to catch renamed files;
/// it is a client-side integrity check, not server-side content validation —
/// Storage Rules can only see the declared content type and size.
class UploadFilePolicy {
  const UploadFilePolicy._();

  static const int mb = 1024 * 1024;

  /// Shared image ceiling for payment proofs, award images and activity
  /// images (matches the 10 MB already enforced for proofs and awards).
  static const int imageMaxBytes = 10 * mb;

  static const UploadFormat jpg = UploadFormat(
    'jpg',
    'image/jpeg',
    imageMaxBytes,
  );
  static const UploadFormat jpeg = UploadFormat(
    'jpeg',
    'image/jpeg',
    imageMaxBytes,
  );
  static const UploadFormat png = UploadFormat(
    'png',
    'image/png',
    imageMaxBytes,
  );
  static const UploadFormat webp = UploadFormat(
    'webp',
    'image/webp',
    imageMaxBytes,
  );

  /// Proofs, award images and activity images: JPEG / PNG / WebP only.
  static const List<UploadFormat> imageFormats = [jpg, jpeg, png, webp];

  static List<String> extensionsOf(List<UploadFormat> formats) =>
      formats.map((f) => f.extension).toList(growable: false);

  /// Lowercase extension after the last dot, or '' when there is none.
  static String extensionOf(String fileName) {
    final name = fileName.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static UploadFormat? formatFor(String fileName, List<UploadFormat> formats) {
    final ext = extensionOf(fileName);
    if (ext.isEmpty) return null;
    for (final format in formats) {
      if (format.extension == ext) return format;
    }
    return null;
  }

  /// Extension + size check without touching the file system.
  static UploadCheck check({
    required String fileName,
    required int sizeBytes,
    required List<UploadFormat> formats,
  }) {
    final format = formatFor(fileName, formats);
    if (format == null) {
      final allowed = extensionsOf(formats).map((e) => e.toUpperCase());
      return UploadCheck.rejected(
        'نوع الملف غير مدعوم. المسموح: ${allowed.join('، ')}',
      );
    }
    if (sizeBytes <= 0) return const UploadCheck.rejected('الملف فارغ');
    if (sizeBytes >= format.maxBytes) {
      return UploadCheck.rejected(
        'حجم الملف أكبر من المسموح (${format.maxBytes ~/ mb} ميجابايت)',
      );
    }
    return UploadCheck.ok(format);
  }

  /// [check] plus a signature check on the file's first bytes.
  static Future<UploadCheck> checkFile(
    File file, {
    required List<UploadFormat> formats,
    String? displayName,
  }) async {
    if (!await file.exists()) {
      return const UploadCheck.rejected('الملف غير موجود');
    }
    final result = check(
      fileName: displayName ?? file.path,
      sizeBytes: await file.length(),
      formats: formats,
    );
    final format = result.format;
    if (format == null) return result;
    final header = await _readHeader(file);
    if (!matchesSignature(header, format.contentType)) {
      return const UploadCheck.rejected(
        'محتوى الملف لا يطابق امتداده. اختر ملفاً سليماً',
      );
    }
    return result;
  }

  static Future<Uint8List> _readHeader(File file) async {
    final raf = await file.open();
    try {
      return await raf.read(16);
    } finally {
      await raf.close();
    }
  }

  /// Magic-byte check for every MIME type the app uploads.
  static bool matchesSignature(List<int> b, String contentType) {
    bool at(int offset, List<int> bytes) {
      if (b.length < offset + bytes.length) return false;
      for (var i = 0; i < bytes.length; i++) {
        if (b[offset + i] != bytes[i]) return false;
      }
      return true;
    }

    const riff = [0x52, 0x49, 0x46, 0x46];
    return switch (contentType) {
      'image/jpeg' => at(0, const [0xFF, 0xD8, 0xFF]),
      'image/png' => at(0, const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]),
      'image/webp' => at(0, riff) && at(8, const [0x57, 0x45, 0x42, 0x50]),
      'application/pdf' => at(0, const [0x25, 0x50, 0x44, 0x46, 0x2D]),
      'audio/mpeg' =>
        at(0, const [0x49, 0x44, 0x33]) ||
            (b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0),
      'audio/wav' => at(0, riff) && at(8, const [0x57, 0x41, 0x56, 0x45]),
      'video/mp4' => at(4, const [0x66, 0x74, 0x79, 0x70]),
      _ => false,
    };
  }
}

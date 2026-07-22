import 'package:equatable/equatable.dart';

/// نوع الملف - بيحدد الأيقونة واللون في التصميم
enum ContentFileType { pdf, audio, video, image, document }

extension ContentFileTypeLabel on ContentFileType {
  String get label => switch (this) {
    ContentFileType.pdf => 'PDF',
    ContentFileType.audio => 'صوتيات',
    ContentFileType.video => 'فيديو',
    ContentFileType.image => 'صور',
    ContentFileType.document => 'مستندات',
  };
}

class ContentFileEntity extends Equatable {
  final String id;
  final String title;
  final ContentFileType type;
  final String downloadUrl;
  final String storagePath; // المسار في Firebase Storage للحذف لاحقاً
  final double fileSizeMb;
  final String uploadedBy;
  final String uploaderName;
  final DateTime uploadedAt;

  /// الحلقة اللي الملف خاص بيها (null = كل الحلقات)
  final String? halaqaId;

  const ContentFileEntity({
    required this.id,
    required this.title,
    required this.type,
    required this.downloadUrl,
    required this.storagePath,
    required this.fileSizeMb,
    required this.uploadedBy,
    required this.uploaderName,
    required this.uploadedAt,
    this.halaqaId,
  });

  String get sizeLabel {
    if (fileSizeMb < 1) {
      return '${(fileSizeMb * 1024).toStringAsFixed(0)} كيلوبايت';
    }
    return '${fileSizeMb.toStringAsFixed(1)} ميجا';
  }

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    downloadUrl,
    storagePath,
    fileSizeMb,
    uploadedBy,
    uploaderName,
    uploadedAt,
    halaqaId,
  ];
}

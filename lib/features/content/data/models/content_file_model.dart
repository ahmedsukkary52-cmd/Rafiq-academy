import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/content_file_entity.dart';

class ContentFileModel extends ContentFileEntity {
  const ContentFileModel({
    required super.id,
    required super.title,
    required super.type,
    required super.downloadUrl,
    required super.storagePath,
    required super.fileSizeMb,
    required super.uploadedBy,
    required super.uploaderName,
    required super.uploadedAt,
    super.halaqaId,
  });

  factory ContentFileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentFileModel(
      id: doc.id,
      title: data['title'] ?? '',
      type: typeFromString(data['type'] ?? ''),
      downloadUrl: data['downloadUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      fileSizeMb: (data['fileSizeMb'] ?? 0).toDouble(),
      uploadedBy: data['uploadedBy'] ?? '',
      uploaderName: data['uploaderName'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      halaqaId: data['halaqaId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'type': typeToString(type),
    'downloadUrl': downloadUrl,
    'storagePath': storagePath,
    'fileSizeMb': fileSizeMb,
    'uploadedBy': uploadedBy,
    'uploaderName': uploaderName,
    'uploadedAt': FieldValue.serverTimestamp(),
    if (halaqaId != null) 'halaqaId': halaqaId,
  };

  static ContentFileType typeFromString(String v) => switch (v) {
    'pdf' => ContentFileType.pdf,
    'audio' => ContentFileType.audio,
    'video' => ContentFileType.video,
    'image' => ContentFileType.image,
    'document' => ContentFileType.document,
    _ => ContentFileType.document,
  };

  static String typeToString(ContentFileType t) => switch (t) {
    ContentFileType.pdf => 'pdf',
    ContentFileType.audio => 'audio',
    ContentFileType.video => 'video',
    ContentFileType.image => 'image',
    ContentFileType.document => 'document',
  };
}

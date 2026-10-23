import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/posts_entities.dart';

class PostAttachmentModel extends PostAttachmentEntity {
  const PostAttachmentModel({
    super.url,
    super.storagePath,
    super.contentType,
    required super.type,
    required super.fileName,
    super.fileSizeMb,
    super.audioDurationSeconds,
  });

  factory PostAttachmentModel.fromMap(Map<String, dynamic> map) {
    String text(Object? raw) => raw is String ? raw.trim() : '';
    return PostAttachmentModel(
      url: text(map['url']),
      storagePath: text(map['storagePath']),
      contentType: text(map['contentType']),
      type: _typeFromString(text(map['type'])),
      fileName: text(map['fileName']),
      fileSizeMb: (map['fileSizeMb'] as num?)?.toDouble(),
      audioDurationSeconds: map['audioDurationSeconds'] as int?,
    );
  }

  PostAttachmentModel withoutLegacyUrl() => PostAttachmentModel(
    storagePath: storagePath,
    contentType: contentType,
    type: type,
    fileName: fileName,
    fileSizeMb: fileSizeMb,
    audioDurationSeconds: audioDurationSeconds,
  );

  /// New attachments persist the Storage path only — never a download URL.
  Map<String, dynamic> toMap() => {
    'storagePath': storagePath,
    'contentType': contentType,
    'type': _typeToString(type),
    'fileName': fileName,
    if (fileSizeMb != null) 'fileSizeMb': fileSizeMb,
    if (audioDurationSeconds != null)
      'audioDurationSeconds': audioDurationSeconds,
  };

  static AttachmentType _typeFromString(String v) => switch (v) {
    'pdf' => AttachmentType.pdf,
    'audio' => AttachmentType.audio,
    'image' => AttachmentType.image,
    'video' => AttachmentType.video,
    _ => AttachmentType.pdf,
  };

  static String _typeToString(AttachmentType t) => switch (t) {
    AttachmentType.pdf => 'pdf',
    AttachmentType.audio => 'audio',
    AttachmentType.image => 'image',
    AttachmentType.video => 'video',
  };
}

class PostModel extends PostEntity {
  const PostModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    super.authorImageUrl,
    required super.content,
    super.attachments,
    super.halaqaId,
    required super.audience,
    required super.createdAt,
    super.isPinned,
    super.likedBy,
    super.commentsCount,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    return PostModel.fromData(
      id: doc.id,
      data: doc.data() as Map<String, dynamic>,
    );
  }

  /// Map-based parse for tests / shared with [fromFirestore].
  ///
  /// [createdAt] may be null on the first local snapshot after a write that
  /// used [FieldValue.serverTimestamp] — do not cast to [Timestamp] blindly.
  factory PostModel.fromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final attachmentsRaw = data['attachments'] as List<dynamic>? ?? [];
    final attachments = attachmentsRaw
        .map((a) => PostAttachmentModel.fromMap(a as Map<String, dynamic>))
        .toList();

    return PostModel(
      id: id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorImageUrl: data['authorImageUrl'] as String?,
      content: data['content'] ?? '',
      attachments: attachments,
      halaqaId: data['halaqaId'] as String?,
      audience: data['audience'] == 'allHalaqat'
          ? PostAudience.allHalaqat
          : PostAudience.specificHalaqa,
      createdAt: _readCreatedAt(data['createdAt']),
      isPinned: data['isPinned'] as bool? ?? false,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: (data['commentsCount'] ?? 0) as int,
    );
  }

  PostModel withAttachments(List<PostAttachmentModel> next) => PostModel(
    id: id,
    authorId: authorId,
    authorName: authorName,
    authorImageUrl: authorImageUrl,
    content: content,
    attachments: next,
    halaqaId: halaqaId,
    audience: audience,
    createdAt: createdAt,
    isPinned: isPinned,
    likedBy: likedBy,
    commentsCount: commentsCount,
  );
}

class CommentModel extends CommentEntity {
  const CommentModel({
    required super.id,
    required super.postId,
    required super.authorId,
    required super.authorName,
    super.authorImageUrl,
    required super.content,
    required super.createdAt,
  });

  factory CommentModel.fromFirestore(
    DocumentSnapshot doc, {
    required String postId,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      postId: postId,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorImageUrl: data['authorImageUrl'] as String?,
      content: data['content'] ?? '',
      createdAt: _readCreatedAt(data['createdAt']),
    );
  }
}

/// Handles null [createdAt] on the initial local snapshot after
/// `FieldValue.serverTimestamp()` writes.
DateTime _readCreatedAt(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  return DateTime.now();
}

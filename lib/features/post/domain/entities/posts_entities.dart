import 'package:equatable/equatable.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PostAttachment - مرفق المنشور (PDF، صوت)
// ══════════════════════════════════════════════════════════════════════════════

enum AttachmentType { pdf, audio, image, video }

class PostAttachmentEntity extends Equatable {
  final String url;
  final AttachmentType type;
  final String fileName;
  final double? fileSizeMb;
  final int? audioDurationSeconds; // مدة الصوت بالثواني - لعرض "١:٣٤" في الـ UI

  const PostAttachmentEntity({
    required this.url,
    required this.type,
    required this.fileName,
    this.fileSizeMb,
    this.audioDurationSeconds,
  });

  @override
  List<Object?> get props => [
    url,
    type,
    fileName,
    fileSizeMb,
    audioDurationSeconds,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// PostEntity - المنشور الرئيسي
// ══════════════════════════════════════════════════════════════════════════════

/// مدى رؤية المنشور - لحلقة معيّنة أو لكل الحلقات
enum PostAudience { specificHalaqa, allHalaqat }

class PostEntity extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;

  /// النص الرئيسي للمنشور
  final String content;

  /// المرفقات (PDF، صوتيات...)
  final List<PostAttachmentEntity> attachments;

  /// معرّف الحلقة لو المنشور مخصص لحلقة معيّنة
  final String? halaqaId;
  final PostAudience audience;

  final DateTime createdAt;
  final bool isPinned;

  /// قائمة الـ uids اللي عملوا إعجاب
  final List<String> likedBy;

  /// عدد التعليقات - denormalized لتجنب قراءة كل التعليقات عشان نعرض العدد
  final int commentsCount;

  const PostEntity({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    this.attachments = const [],
    this.halaqaId,
    required this.audience,
    required this.createdAt,
    this.isPinned = false,
    this.likedBy = const [],
    this.commentsCount = 0,
  });

  int get likesCount => likedBy.length;

  bool isLikedBy(String uid) => likedBy.contains(uid);

  @override
  List<Object?> get props => [
    id,
    authorId,
    authorName,
    authorImageUrl,
    content,
    attachments,
    halaqaId,
    audience,
    createdAt,
    isPinned,
    likedBy,
    commentsCount,
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// CommentEntity - التعليق على المنشور
// ══════════════════════════════════════════════════════════════════════════════

class CommentEntity extends Equatable {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String content;
  final DateTime createdAt;

  const CommentEntity({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    required this.content,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
    id,
    postId,
    authorId,
    authorName,
    authorImageUrl,
    content,
    createdAt,
  ];
}

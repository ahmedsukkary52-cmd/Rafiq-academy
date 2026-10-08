/// C10 / WA-12 — frozen Firebase Storage path contracts.
///
/// Rules in `storage.rules` are authoritative. These helpers exist so Dart
/// never invents alternate path shapes for approved categories.
class StoragePathsContract {
  const StoragePathsContract._();

  static const String paymentProofsPrefix = 'payment_proofs';
  static const String profileImagesPrefix = 'profile_images';
  static const String chatMediaPrefix = 'chat_media';
  static const String chatVoicePrefix = 'chat_voice';
  static const String chatAttachmentsPrefix = 'chat_attachments';
  static const String recitationsPrefix = 'recitations';
  static const String awardsPrefix = 'awards';
  static const String postsPrefix = 'posts';
  static const String contentPrefix = 'content';
  static const String halaqaActivitiesPrefix = 'halaqa_activities';

  /// `payment_proofs/{parentId}/{paymentId}/{fileName}`
  static String paymentProof({
    required String parentId,
    required String paymentId,
    required String fileName,
  }) {
    final p = parentId.trim();
    final pay = paymentId.trim();
    final f = fileName.trim();
    if (p.isEmpty || pay.isEmpty || f.isEmpty) {
      throw ArgumentError('payment proof path segments must be non-empty');
    }
    return '$paymentProofsPrefix/$p/$pay/$f';
  }

  /// `profile_images/{uid}/{fileName}`
  static String profileImage({
    required String uid,
    required String fileName,
  }) {
    final u = uid.trim();
    final f = fileName.trim();
    if (u.isEmpty || f.isEmpty) {
      throw ArgumentError('profile image path segments must be non-empty');
    }
    return '$profileImagesPrefix/$u/$f';
  }

  /// `chat_media/{conversationId}/{messageId}/{fileName}`
  static String chatMedia({
    required String conversationId,
    required String messageId,
    required String fileName,
  }) {
    final c = conversationId.trim();
    final m = messageId.trim();
    final f = fileName.trim();
    if (c.isEmpty || m.isEmpty || f.isEmpty) {
      throw ArgumentError('chat media path segments must be non-empty');
    }
    return '$chatMediaPrefix/$c/$m/$f';
  }

  /// `chat_voice/{conversationId}/{messageId}/{fileName}`
  static String chatVoice({
    required String conversationId,
    required String messageId,
    required String fileName,
  }) {
    final c = conversationId.trim();
    final m = messageId.trim();
    final f = fileName.trim();
    if (c.isEmpty || m.isEmpty || f.isEmpty) {
      throw ArgumentError('chat voice path segments must be non-empty');
    }
    return '$chatVoicePrefix/$c/$m/$f';
  }

  /// `chat_attachments/{conversationId}/{messageId}/{fileName}`
  static String chatAttachment({
    required String conversationId,
    required String messageId,
    required String fileName,
  }) {
    final c = conversationId.trim();
    final m = messageId.trim();
    final f = fileName.trim();
    if (c.isEmpty || m.isEmpty || f.isEmpty) {
      throw ArgumentError('chat attachment path segments must be non-empty');
    }
    return '$chatAttachmentsPrefix/$c/$m/$f';
  }

  /// `posts/{authorId}/{fileName}`
  static String postAttachment({
    required String authorId,
    required String fileName,
  }) {
    final a = authorId.trim();
    final f = fileName.trim();
    if (a.isEmpty || f.isEmpty) {
      throw ArgumentError('post attachment path segments must be non-empty');
    }
    return '$postsPrefix/$a/$f';
  }

  /// `content/{uploadedBy}/{fileName}`
  static String contentFile({
    required String uploadedBy,
    required String fileName,
  }) {
    final u = uploadedBy.trim();
    final f = fileName.trim();
    if (u.isEmpty || f.isEmpty) {
      throw ArgumentError('content path segments must be non-empty');
    }
    return '$contentPrefix/$u/$f';
  }

  /// `halaqa_activities/{activityId}/{studentId}/{folder}/{fileName}`
  static String halaqaActivityMedia({
    required String activityId,
    required String studentId,
    required String folder,
    required String fileName,
  }) {
    final a = activityId.trim();
    final s = studentId.trim();
    final folderName = folder.trim();
    final f = fileName.trim();
    if (a.isEmpty || s.isEmpty || folderName.isEmpty || f.isEmpty) {
      throw ArgumentError('halaqa activity media path segments must be non-empty');
    }
    return '$halaqaActivitiesPrefix/$a/$s/$folderName/$f';
  }

  /// Recitation uploads remain product-gated OFF (`audioUploadsEnabled`).
  static String recitation({
    required String studentId,
    required String assignmentId,
    required String fileName,
  }) {
    final s = studentId.trim();
    final a = assignmentId.trim();
    final f = fileName.trim();
    if (s.isEmpty || a.isEmpty || f.isEmpty) {
      throw ArgumentError('recitation path segments must be non-empty');
    }
    return '$recitationsPrefix/$s/$a/$f';
  }

  static bool isApprovedPrefix(String path) {
    final p = path.trim();
    return p.startsWith('$paymentProofsPrefix/')
        || p.startsWith('$profileImagesPrefix/')
        || p.startsWith('$chatMediaPrefix/')
        || p.startsWith('$chatVoicePrefix/')
        || p.startsWith('$chatAttachmentsPrefix/')
        || p.startsWith('$recitationsPrefix/')
        || p.startsWith('$awardsPrefix/')
        || p.startsWith('$postsPrefix/')
        || p.startsWith('$contentPrefix/')
        || p.startsWith('$halaqaActivitiesPrefix/');
  }
}

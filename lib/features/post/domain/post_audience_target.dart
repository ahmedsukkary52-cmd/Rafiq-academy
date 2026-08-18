import 'entities/posts_entities.dart';

/// Resolves Firestore `audienceTarget` used by [watchPosts] (`whereIn`).
///
/// - [PostAudience.allHalaqat] → `'all'`
/// - [PostAudience.specificHalaqa] → trimmed [halaqaId]
///
/// Returns `null` when a specific-halaqa post has no usable id (caller must reject).
String? resolvePostAudienceTarget({
  required PostAudience audience,
  required String? halaqaId,
}) {
  if (audience == PostAudience.allHalaqat) return 'all';
  final id = halaqaId?.trim() ?? '';
  return id.isEmpty ? null : id;
}

/// Normalizes the halaqa id used for watching posts. Blank → `null`.
String? normalizePostsWatchHalaqaId(String? halaqaId) {
  final id = halaqaId?.trim() ?? '';
  return id.isEmpty ? null : id;
}

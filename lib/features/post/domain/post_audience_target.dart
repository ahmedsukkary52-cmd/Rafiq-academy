import 'entities/posts_entities.dart';

/// Resolves Firestore `audienceTarget` used by [watchPosts] (`isEqualTo`).
///
/// Posts are Halaqa-scoped (P0 §7): the target is always the trimmed
/// [halaqaId]. There is no academy-wide feed, so [PostAudience.allHalaqat]
/// (kept only to parse legacy documents) resolves to `null`.
///
/// Returns `null` when the post cannot be scoped (caller must reject).
String? resolvePostAudienceTarget({
  required PostAudience audience,
  required String? halaqaId,
}) {
  if (audience == PostAudience.allHalaqat) return null;
  final id = halaqaId?.trim() ?? '';
  return id.isEmpty ? null : id;
}

/// Normalizes the halaqa id used for watching posts. Blank → `null`.
String? normalizePostsWatchHalaqaId(String? halaqaId) {
  final id = halaqaId?.trim() ?? '';
  return id.isEmpty ? null : id;
}

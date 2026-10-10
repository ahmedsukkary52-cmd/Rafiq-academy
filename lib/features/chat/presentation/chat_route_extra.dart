/// Typed extras for [ChatRoomPage] routes.
///
/// GoRouter's `state.extra` is `Object?`. A map literal whose values are all
/// non-null infers `Map<String, String>`, which is **not** a subtype of
/// `Map<String, String?>` (Dart maps are invariant). Casting with
/// `as Map<String, String?>?` therefore throws and the chat route errorBuilder
/// shows "الصفحة غير موجودة".
class ChatRouteExtra {
  const ChatRouteExtra._();

  static const nameKey = 'name';
  static const imageKey = 'image';
  static const imageUrlKey = 'imageUrl';
  /// When true, Admin (or any) viewer is read-only — no send, no join.
  static const readOnlyKey = 'readOnly';

  static Map<String, String?> parse(Object? extra) {
    if (extra is! Map) return const {};
    String? read(Object key) {
      final value = extra[key];
      if (value == null) return null;
      return value.toString();
    }

    return {
      nameKey: read(nameKey),
      imageKey: read(imageKey) ?? read(imageUrlKey),
      readOnlyKey: read(readOnlyKey),
    };
  }

  static bool isReadOnly(Object? extra) {
    final v = parse(extra)[readOnlyKey]?.toLowerCase();
    return v == 'true' || v == '1';
  }
}

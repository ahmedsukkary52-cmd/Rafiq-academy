/// Strict readers for saved award payloads: a missing or mistyped field
/// throws [FormatException] instead of being defaulted.
extension AwardPayloadJson on Map<String, Object?> {
  String requireString(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('award payload: $key');
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value == null || value is String) return value as String?;
    throw FormatException('award payload: $key');
  }

  int requireInt(String key) {
    final value = this[key];
    if (value is int) return value;
    throw FormatException('award payload: $key');
  }

  bool requireBool(String key) {
    final value = this[key];
    if (value is bool) return value;
    throw FormatException('award payload: $key');
  }

  List<String> requireStringList(String key) {
    final value = this[key];
    if (value is List && value.every((e) => e is String)) {
      return List<String>.unmodifiable(value.cast<String>());
    }
    throw FormatException('award payload: $key');
  }

  T requireEnum<T extends Enum>(String key, List<T> values) {
    final name = requireString(key);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('award payload: $key');
  }
}

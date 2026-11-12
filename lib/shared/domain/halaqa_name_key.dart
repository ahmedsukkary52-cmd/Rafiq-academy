import 'arabic_search_normalizer.dart';

/// Mirror of `functions/src/halaqa/halaqaNameKey.ts` (the server is the
/// authority). Two names are the same halaqa when their keys match: frozen
/// Arabic search normalization, Eastern digits → ASCII, punctuation and
/// symbols removed.
String halaqaNameKey(String? raw) {
  final normalized = ArabicSearchNormalizer.normalize(raw).replaceAllMapped(
    _easternDigits,
    (m) {
      final code = m[0]!.codeUnitAt(0);
      return '${code >= 0x06F0 ? code - 0x06F0 : code - 0x0660}';
    },
  );
  return normalized
      .replaceAll(_punctuation, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final _easternDigits = RegExp('[\u0660-\u0669\u06F0-\u06F9]');
final _punctuation = RegExp(r'[\p{P}\p{S}]', unicode: true);

/// Client pre-check against the loaded directory; returns the clashing name.
String? duplicateHalaqaName(String candidate, Iterable<String> existingNames) {
  final key = halaqaNameKey(candidate);
  if (key.isEmpty) return null;
  for (final name in existingNames) {
    if (halaqaNameKey(name) == key) return name;
  }
  return null;
}

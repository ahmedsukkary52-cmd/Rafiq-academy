/// Arabic-Indic digits for presentation labels.
library;

/// Replaces ASCII digits 0-9 with Arabic-Indic digits; every other
/// character (including digits that are already Arabic-Indic) is kept.
String teacherHomeEasternDigits(String input) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final code in input.runes) {
    final ch = String.fromCharCode(code);
    final i = western.indexOf(ch);
    buffer.write(i >= 0 ? eastern[i] : ch);
  }
  return buffer.toString();
}

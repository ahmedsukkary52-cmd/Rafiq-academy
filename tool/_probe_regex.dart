void main() {
  final raw = RegExp(r"^[\x21-\x7e]+$");
  final normal = RegExp("^[\x21-\x7e]+\$");
  const u = "https://meet.google.com/xed-aobs-zkz";
  print("rawPattern=${raw.pattern}");
  print("normalPattern=${normal.pattern}");
  print("raw.hasMatch -> ${raw.hasMatch(u)}");
  print("normal.hasMatch -> ${normal.hasMatch(u)}");
}

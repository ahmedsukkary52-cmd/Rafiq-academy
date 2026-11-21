import "package:rafiq_academy/shared/domain/meeting_link_policy.dart";
void main() {
  const u = "https://meet.google.com/xed-aobs-zkz";
  print("issue=${meetingLinkIssue(u)}");
  print("err=${meetingLinkErrorText(u)}");
  print("join=${joinableMeetingUri(u)}");
  final re = RegExp(r"^[\x21-\x7e]+\$");
  print("rawMatch=${re.hasMatch(u)}");
  final re2 = RegExp("^[\x21-\x7e]+\$");
  print("normalMatch=${re2.hasMatch(u)}");
  for (final c in u.runes) {
    if (!re2.hasMatch(String.fromCharCode(c))) print("bad ${c.toRadixString(16)}");
  }
}

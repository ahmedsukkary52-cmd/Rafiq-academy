import "package:rafiq_academy/shared/domain/meeting_link_policy.dart";
void main() {
  final samples = <String>[
    "https://meet.google.com/xed-aobs-zkz",
    "https://meet.google.com/xed\u2013aobs\u2013zkz", // en-dash
    "https://meet.google.com/xed\u2011aobs\u2011zkz", // non-breaking hyphen
    "\u200ehttps://meet.google.com/xed-aobs-zkz",
    "https://meet.google.com/xed-aobs-zkz\u00a0",
    "https://meet.google.com/xed-aobs-zkz ",
  ];
  for (final s in samples) {
    print("---");
    print("codes=${s.runes.map((c)=>c.toRadixString(16)).join(",")}");
    print("issue=${meetingLinkIssue(s)} msg=${meetingLinkErrorText(s)}");
    print("norm=${normalizeMeetingLinkInput(s)}");
  }
}

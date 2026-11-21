import "package:rafiq_academy/shared/domain/meeting_link_policy.dart";

void main() {
  const link = "https://meet.google.com/xed-aobs-zkz";
  print("issue=${meetingLinkIssue(link)}");
  print("error=${meetingLinkErrorText(link)}");
  print("join=${joinableMeetingUri(link)}");
  print("norm=${normalizeMeetingLinkInput(link)}");
}

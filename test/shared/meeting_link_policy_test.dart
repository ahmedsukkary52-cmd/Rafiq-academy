import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/meeting_link_policy.dart';

void main() {
  group('B14 meeting link policy (client mirror)', () {
    test('accepts https links from any provider without rewriting', () {
      for (final link in [
        'https://meet.google.com/abc-defg-hij',
        'https://us02web.zoom.us/j/11111111111?pwd=AbCd',
        'https://teams.microsoft.com/l/meetup-join/19%3ameeting',
        'HTTPS://Meet.Example.org:8443/room#x',
        'https://123456789012.example.net/r',
        '  https://meet.example.com/trimmed  ',
      ]) {
        expect(meetingLinkIssue(link), isNull, reason: link);
      }
      expect(
        joinableMeetingUri(' https://meet.example.com/a ').toString(),
        'https://meet.example.com/a',
      );
    });

    test('rejects each invalid shape with a specific reason', () {
      final cases = <String, MeetingLinkIssue>{
        '': MeetingLinkIssue.empty,
        '   ': MeetingLinkIssue.empty,
        'https://meet.example.com/${'a' * kMaxMeetingLinkLength}':
            MeetingLinkIssue.tooLong,
        'https://meet.example.com/a b': MeetingLinkIssue.whitespace,
        'https://meet.example.com/a\tb': MeetingLinkIssue.whitespace,
        'https://meet.example.com/\u200b': MeetingLinkIssue.whitespace,
        'https://meet.example.com/\u202e': MeetingLinkIssue.whitespace,
        'https://مثال.com/room': MeetingLinkIssue.unsupportedCharacters,
        'http://meet.example.com/abc': MeetingLinkIssue.notHttps,
        'meet.example.com/abc': MeetingLinkIssue.notHttps,
        'javascript:alert(1)': MeetingLinkIssue.notHttps,
        'https://user:pw@meet.example.com/x': MeetingLinkIssue.credentials,
        'https://user@meet.example.com': MeetingLinkIssue.credentials,
        'https://localhost/room': MeetingLinkIssue.invalidHost,
        'https:///room': MeetingLinkIssue.invalidHost,
        'https://-bad.example.com': MeetingLinkIssue.invalidHost,
        'https://meet.example.com:0/x': MeetingLinkIssue.invalidHost,
        'https://meet.example.com:70000/x': MeetingLinkIssue.invalidHost,
        r'https://meet.example.com\@evil.com': MeetingLinkIssue.malformed,
      };
      cases.forEach((link, issue) {
        expect(meetingLinkIssue(link), issue, reason: link);
        expect(joinableMeetingUri(link), isNull, reason: link);
      });
    });

    test('form messages never echo the submitted link', () {
      const link = 'http://secret-room.example.com/xyz';
      final message = meetingLinkErrorText(link);
      expect(message, isNotNull);
      expect(message, isNot(contains('secret-room')));
      expect(meetingLinkErrorText('https://meet.example.com/x'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/meeting_link_policy.dart';

void main() {
  group('B14 meeting link policy (client mirror)', () {
    test('accepts https links from any provider without rewriting', () {
      for (final link in [
        'https://meet.google.com/abc-defg-hij',
        'https://us02web.zoom.us/j/11111111111?pwd=AbCd',
        'https://us05web.zoom.us/j/01123456789?pwd=xYz',
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

    test('normalizes Zoom/Google paste shapes', () {
      expect(
        normalizeMeetingLinkInput('meet.google.com/abc-defg-hij'),
        'https://meet.google.com/abc-defg-hij',
      );
      expect(
        normalizeMeetingLinkInput(
          'Join Zoom Meeting\nhttps://us02web.zoom.us/j/83012345678?pwd=Ab',
        ),
        'https://us02web.zoom.us/j/83012345678?pwd=Ab',
      );
      expect(
        meetingLinkIssue('http://meet.google.com/abc-defg-hij'),
        isNull,
      );
      expect(
        meetingLinkIssue('us05web.zoom.us/j/01123456789'),
        isNull,
      );
    });

    test('accepts Google Meet xed-aobs-zkz (clean, RTL, NBSP, en-dash)', () {
      const meet = 'https://meet.google.com/xed-aobs-zkz';
      expect(meetingLinkIssue(meet), isNull);
      expect(meetingLinkErrorText(meet), isNull);
      expect(joinableMeetingUri(meet)?.toString(), meet);

      expect(meetingLinkIssue('\u202a$meet\u200b'), isNull);
      expect(normalizeMeetingLinkInput('\u202a$meet\u200b'), meet);

      // NBSP / thin space from rich paste — stripped, not rejected.
      expect(
        meetingLinkIssue('https://meet.google.com/xed\u00a0aobs-zkz'),
        isNull,
      );
      expect(
        normalizeMeetingLinkInput('https://meet.google.com/xed\u00a0aobs-zkz'),
        meet,
      );
      expect(
        meetingLinkIssue('https://meet.google.com/xed\u2009aobs-zkz'),
        isNull,
      );

      // Unicode en-dashes from WhatsApp/Office → ASCII hyphen.
      expect(
        normalizeMeetingLinkInput(
          'https://meet.google.com/xed\u2013aobs\u2013zkz',
        ),
        meet,
      );
      expect(
        meetingLinkIssue('https://meet.google.com/xed\u2013aobs\u2013zkz'),
        isNull,
      );
    });

    test('rejects each invalid shape with a specific reason', () {
      final cases = <String, MeetingLinkIssue>{
        '': MeetingLinkIssue.empty,
        '   ': MeetingLinkIssue.empty,
        'https://meet.example.com/${'a' * kMaxMeetingLinkLength}':
            MeetingLinkIssue.tooLong,
        // Accidental spaces are stripped in normalize; NUL still rejected.
        'https://meet.example.com/a\u0000b': MeetingLinkIssue.whitespace,
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

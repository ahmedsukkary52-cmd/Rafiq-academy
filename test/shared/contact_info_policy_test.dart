import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/contact_info_policy.dart';

void main() {
  group('detectContactInfo flags phone numbers', () {
    for (final text in [
      '0501234567',
      'رقمي 0501234567 كلمني',
      '050 123 4567',
      '050-123-4567',
      '(050) 123-4567',
      '+966 50 123 4567',
      '+966501234567',
      '00966501234567',
      '966501234567',
      '01012345678',
      'رقم ولي الأمر 0111 234 5678',
      '+20 101 234 5678',
      '201512345678',
      '+44 20 7946 0958',
      '٠٥٠١٢٣٤٥٦٧',
      '۰۵۰۱۲۳۴۵۶۷',
      'call 0501234567 2026',
    ]) {
      test(text, () {
        expect(detectContactInfo(text), ContactInfoFinding.phoneNumber);
      });
    }
  });

  test('detectContactInfo flags WhatsApp and telephone links', () {
    expect(
      detectContactInfo('https://wa.me/966501234567'),
      ContactInfoFinding.whatsappLink,
    );
    expect(
      detectContactInfo('راسلني wa.me/qr/ABC'),
      ContactInfoFinding.whatsappLink,
    );
    expect(
      detectContactInfo('https://chat.whatsapp.com/AbCdEf'),
      ContactInfoFinding.whatsappLink,
    );
    expect(
      detectContactInfo('whatsapp://send?text=hi'),
      ContactInfoFinding.whatsappLink,
    );
    expect(
      detectContactInfo('https://wa.link/abc123'),
      ContactInfoFinding.whatsappLink,
    );
    expect(detectContactInfo('tel:123'), ContactInfoFinding.phoneLink);
    expect(detectContactInfo('اتصل sms:5551234'), ContactInfoFinding.phoneLink);
    expect(
      detectContactInfo("<a href='TEL:+1'>x</a>"),
      ContactInfoFinding.phoneLink,
    );
  });

  group('detectContactInfo accepts legitimate academic content', () {
    for (final text in [
      '',
      'أحسنت! الدرجة 95/100',
      'الدرجة 18 من 20',
      'احفظ الآيات 1-10 من سورة البقرة',
      'آية الكرسي 2:255',
      'سورة البقرة 2:1-5 ثم 2:6-20',
      'الواجب يوم 2026-10-15',
      'الموعد 15/10/2026 الساعة 4:30',
      '15.10.2026',
      'تمرين 3.2 صفحة 45',
      'الصفحات 12 13 14 15',
      'حل التمارين 1 2 3 4 5 6 7 8 9 10',
      'رسوم الشهر 1,500 جنيه',
      'المبلغ 1500.00',
      'الجزء 30 الحزب 60',
      'عدد الطلاب 120 والحلقات 12',
      'https://example.edu/lesson/2026/10',
      'https://youtube.com/watch?v=abc123',
      'telescope telegraph hotel: lesson',
      'whatsapp group is not allowed',
      'ISBN 978-3-16-148410-0',
    ]) {
      test(text.isEmpty ? '(empty)' : text, () {
        expect(detectContactInfo(text), isNull);
        expect(contactInfoViolation(text), isNull);
      });
    }
  });

  test('contactInfoViolation returns the Arabic rejection message', () {
    expect(contactInfoViolation('0501234567'), contactInfoRejectionMessage);
    expect(contactInfoViolation(null), isNull);
  });

  test('isAllowedExternalLink allows http(s) and blocks contact links', () {
    expect(
      isAllowedExternalLink(
        'https://firebasestorage.googleapis.com/v0/b/x/o/hw.pdf?alt=media',
      ),
      isTrue,
    );
    expect(isAllowedExternalLink('http://example.edu/lesson'), isTrue);
    for (final link in [
      'tel:0501234567',
      'sms:0501234567',
      'whatsapp://send?phone=1',
      'mailto:a@b.c',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'https://wa.me/966501234567',
      'https://chat.whatsapp.com/abc',
      'https://api.whatsapp.com/send?phone=1',
      'https://wa.link/x',
      'not a link',
      '',
    ]) {
      expect(isAllowedExternalLink(link), isFalse, reason: link);
    }
  });

  test('contact field keys match the server-side deny-list', () {
    expect(contactFieldKeys, [
      'phone',
      'phoneNumber',
      'mobile',
      'whatsapp',
      'parentPhone',
      'guardianPhone',
    ]);
  });

  // Same inputs as the "separator, case and digit-script variants" test in
  // functions/test/contact_info_policy.test.mjs.
  group('separator, case and digit-script variants match the server', () {
    const cases = <String, ContactInfoFinding?>{
      '050\u00a0123\u00a04567': ContactInfoFinding.phoneNumber,
      '050\t123\t4567': ContactInfoFinding.phoneNumber,
      '050.123.4567': ContactInfoFinding.phoneNumber,
      '٠٥٠ ١٢٣ ٤٥٦٧': ContactInfoFinding.phoneNumber,
      '+٩٦٦ ٥٠ ١٢٣ ٤٥٦٧': ContactInfoFinding.phoneNumber,
      '050 ۱۲۳ 4567': ContactInfoFinding.phoneNumber,
      'HTTPS://WA.ME/1': ContactInfoFinding.whatsappLink,
      'Tel:1': ContactInfoFinding.phoneLink,
      'رقميwa.me/1': ContactInfoFinding.whatsappLink,
      'السورة ٢:٢٥٥': null,
      'الحصة ١٥/١٠/٢٠٢٦': null,
      'swa.me': null,
      'hotel:5': null,
    };
    cases.forEach((text, expected) {
      test(text, () => expect(detectContactInfo(text), expected));
    });
  });

  test('field keys and rejection message match the TypeScript policy', () {
    final ts = File(
      'functions/src/privacy/contactInfoPolicy.ts',
    ).readAsStringSync();
    final keysBlock = RegExp(
      r'CONTACT_FIELD_KEYS = \[([\s\S]*?)\]',
    ).firstMatch(ts)!.group(1)!;
    final tsKeys = RegExp(
      r'"([A-Za-z]+)"',
    ).allMatches(keysBlock).map((m) => m.group(1)).toList();
    expect(contactFieldKeys, tsKeys);
    expect(ts, contains('"$contactInfoRejectionMessage"'));
  });
}

/**
 * No-personal-contact policy (no Firebase emulator).
 *
 * Run: cd functions && npm run build && node --test test/contact_info_policy.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const policy = require("../lib/privacy/contactInfoPolicy.js");

test("phone numbers are detected in common local and international forms", () => {
  for (const text of [
    "0501234567",
    "رقمي 0501234567 كلمني",
    "050 123 4567",
    "050-123-4567",
    "(050) 123-4567",
    "+966 50 123 4567",
    "+966501234567",
    "00966501234567",
    "966501234567",
    "01012345678",
    "رقم ولي الأمر 0111 234 5678",
    "+20 101 234 5678",
    "201512345678",
    "+44 20 7946 0958",
    "٠٥٠١٢٣٤٥٦٧",
    "۰۵۰۱۲۳۴۵۶۷",
    "call 0501234567 2026",
  ]) {
    assert.equal(policy.detectContactInfo(text), "phone_number", text);
  }
});

test("WhatsApp and telephone links are detected", () => {
  assert.equal(policy.detectContactInfo("https://wa.me/966501234567"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("راسلني wa.me/qr/ABC"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("https://chat.whatsapp.com/AbCdEf"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("https://api.whatsapp.com/send?phone=1"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("whatsapp://send?text=hi"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("https://wa.link/abc123"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("tel:123"), "phone_link");
  assert.equal(policy.detectContactInfo("اتصل sms:5551234"), "phone_link");
  assert.equal(policy.detectContactInfo("<a href='TEL:+1'>x</a>"), "phone_link");
});

test("legitimate academic content is not rejected", () => {
  for (const text of [
    "",
    "أحسنت! الدرجة 95/100",
    "الدرجة 18 من 20",
    "احفظ الآيات 1-10 من سورة البقرة",
    "آية الكرسي 2:255",
    "سورة البقرة 2:1-5 ثم 2:6-20",
    "الواجب يوم 2026-10-15",
    "الموعد 15/10/2026 الساعة 4:30",
    "15.10.2026",
    "تمرين 3.2 صفحة 45",
    "الصفحات 12 13 14 15",
    "حل التمارين 1 2 3 4 5 6 7 8 9 10",
    "رسوم الشهر 1,500 جنيه",
    "المبلغ 1500.00",
    "الجزء 30 الحزب 60",
    "عدد الطلاب 120 والحلقات 12",
    "https://example.edu/lesson/2026/10",
    "https://youtube.com/watch?v=abc123",
    "telescope telegraph hotel: lesson",
    "whatsapp group is not allowed",
    "ISBN 978-3-16-148410-0",
  ]) {
    assert.equal(policy.detectContactInfo(text), null, text);
  }
});

test("contact field keys are recognised", () => {
  assert.equal(policy.findContactFieldKey({ email: "a@b", phone: "1" }), "phone");
  assert.equal(policy.findContactFieldKey({ phoneNumber: "" }), "phoneNumber");
  assert.equal(policy.findContactFieldKey({ whatsapp: null }), "whatsapp");
  assert.equal(policy.findContactFieldKey({ email: "a@b", name: "x" }), null);
  assert.equal(policy.findContactFieldKey(null), null);
});

test("contactInfoViolation returns the Arabic message or null", () => {
  assert.equal(
    policy.contactInfoViolation("0501234567"),
    policy.CONTACT_INFO_REJECTION_MESSAGE,
  );
  assert.equal(policy.contactInfoViolation("البقرة 1-20"), null);
  assert.equal(policy.contactInfoViolation(""), null);
  assert.equal(policy.contactInfoViolation(undefined), null);
});

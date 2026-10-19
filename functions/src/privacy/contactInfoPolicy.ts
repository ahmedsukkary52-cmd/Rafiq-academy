/**
 * No-personal-contact policy (pure). Personal phone numbers are never stored,
 * and user-generated text must not carry phone numbers or WhatsApp/telephone
 * links. Mirrored by `lib/shared/domain/contact_info_policy.dart` and the
 * `contactFieldKeys()` deny-list in firestore.rules.
 *
 * Detection is best-effort: spelled-out digits, obfuscated numbers, emails
 * and other messaging handles are not caught.
 */

export const CONTACT_FIELD_KEYS = [
  "phone",
  "phoneNumber",
  "mobile",
  "whatsapp",
  "parentPhone",
  "guardianPhone",
] as const;

export type ContactInfoFinding = "phone_number" | "phone_link" | "whatsapp_link";

export const CONTACT_INFO_REJECTION_MESSAGE =
  "لا يُسمح بمشاركة أرقام الهواتف أو روابط واتساب أو روابط الاتصال";

const PHONE_LINK = /(?:^|[^a-z0-9])(?:tel|sms|callto):/i;
const WHATSAPP_LINK =
  /(?:^|[^a-z0-9])whatsapp:|(?:^|[^a-z0-9.])(?:wa\.me|wa\.link)(?:[/?#\s]|$)|(?:^|[^a-z0-9])(?:[a-z0-9-]+\.)?whatsapp\.com(?:[/?#\s]|$)/i;

/** Digit groups joined only by spaces, dashes, dots or parentheses. */
const DIGIT_RUN = /\+?\d+(?:[ \t\u00a0\-.()]{1,3}\d+)*/g;
const MAX_PHONE_DIGITS = 15;

function normalizeDigits(text: string): string {
  return text.replace(/[\u0660-\u0669\u06f0-\u06f9]/g, (c) => {
    const code = c.charCodeAt(0);
    return String(code >= 0x06f0 ? code - 0x06f0 : code - 0x0660);
  });
}

function isPhoneDigits(digits: string, hasPlus: boolean): boolean {
  if (/^05\d{8}$/.test(digits) || /^9665\d{8}$/.test(digits)) return true;
  if (/^01[0125]\d{8}$/.test(digits) || /^201[0125]\d{8}$/.test(digits)) {
    return true;
  }
  if (digits.startsWith("00")) {
    const rest = digits.slice(2);
    return rest.length >= 8 && rest.length <= MAX_PHONE_DIGITS && !rest.startsWith("0");
  }
  return hasPlus && digits.length >= 8 && digits.length <= MAX_PHONE_DIGITS;
}

function containsPhoneNumber(text: string): boolean {
  for (const run of text.match(DIGIT_RUN) ?? []) {
    const hasPlus = run.startsWith("+");
    const groups = run.split(/\D+/).filter((g) => g.length > 0);
    for (let i = 0; i < groups.length; i++) {
      let joined = "";
      for (let j = i; j < groups.length; j++) {
        joined += groups[j];
        if (joined.length > MAX_PHONE_DIGITS + 2) break;
        if (isPhoneDigits(joined, hasPlus && i === 0)) return true;
      }
    }
  }
  return false;
}

/** First kind of contact info found in [text], or null. */
export function detectContactInfo(text: string): ContactInfoFinding | null {
  if (!text) return null;
  const normalized = normalizeDigits(text);
  if (WHATSAPP_LINK.test(normalized)) return "whatsapp_link";
  if (PHONE_LINK.test(normalized)) return "phone_link";
  if (containsPhoneNumber(normalized)) return "phone_number";
  return null;
}

/** First contact-field key present on [data], or null. */
export function findContactFieldKey(data: unknown): string | null {
  if (!data || typeof data !== "object") return null;
  for (const key of CONTACT_FIELD_KEYS) {
    if (Object.prototype.hasOwnProperty.call(data, key)) return key;
  }
  return null;
}

/**
 * Arabic rejection message when [text] carries contact info, else null.
 * Empty / missing text is allowed. Mirrors Dart `contactInfoViolation`.
 */
export function contactInfoViolation(
  text: string | null | undefined,
): string | null {
  if (!text) return null;
  return detectContactInfo(text) !== null ? CONTACT_INFO_REJECTION_MESSAGE : null;
}

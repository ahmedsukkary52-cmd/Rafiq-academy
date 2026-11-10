/**
 * Academy login credentials — members sign in with an academy username and
 * password; no personal email is needed.
 *
 * Firebase Auth still needs an email-shaped identifier, so each username maps
 * to an internal login address under a reserved, never-registrable TLD
 * (RFC 2606 `.invalid`). Nobody can receive mail there, which also means the
 * Firebase "reset password" email can never be used to take over an account:
 * recovery is an Admin-issued temporary password (`adminResetMemberPassword`).
 *
 * Passwords are generated here, returned to the Admin exactly once and never
 * written to Firestore or logs.
 */

import { randomInt } from "node:crypto";

export const LOGIN_EMAIL_DOMAIN = "members.rafiq-academy.invalid";
export const LOGIN_USERNAMES_COLLECTION = "loginUsernames";

export const USERNAME_PATTERN = /^[a-z][a-z0-9._-]{2,29}$/;
export const TEMP_PASSWORD_LENGTH = 10;
export const MIN_MEMBER_PASSWORD_LENGTH = 8;

/** No 0/O, 1/l/I — passwords are read aloud or copied from a screen. */
const PASSWORD_ALPHABET = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const PASSWORD_DIGITS = "23456789";
const PASSWORD_LETTERS = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";

export type MemberRole = "student" | "parent" | "teacher" | "supervisor" | "assistant_teacher";

export const USERNAME_PREFIX: Record<MemberRole, string> = {
  student: "st",
  parent: "pr",
  teacher: "tc",
  supervisor: "sv",
  assistant_teacher: "as",
};

export function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase();
}

export function isValidUsername(raw: string): boolean {
  return USERNAME_PATTERN.test(normalizeUsername(raw));
}

export function loginEmailFor(username: string): string {
  return `${normalizeUsername(username)}@${LOGIN_EMAIL_DOMAIN}`;
}

export function isInternalLoginEmail(email: string): boolean {
  return email.trim().toLowerCase().endsWith(`@${LOGIN_EMAIL_DOMAIN}`);
}

/** `st` + 6 digits — short enough to type, ~10^6 space per role. */
export function generateUsername(role: MemberRole, random = randomInt): string {
  return `${USERNAME_PREFIX[role]}${String(random(0, 1_000_000)).padStart(6, "0")}`;
}

function pick(alphabet: string, random: typeof randomInt): string {
  return alphabet[random(0, alphabet.length)];
}

/** Always contains at least one letter and one digit. */
export function generateTemporaryPassword(random = randomInt): string {
  const chars = [pick(PASSWORD_LETTERS, random), pick(PASSWORD_DIGITS, random)];
  while (chars.length < TEMP_PASSWORD_LENGTH) chars.push(pick(PASSWORD_ALPHABET, random));
  for (let i = chars.length - 1; i > 0; i--) {
    const j = random(0, i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join("");
}

/** Arabic message, or null when the member's chosen password is acceptable. */
export function memberPasswordProblem(password: string): string | null {
  if (password.length < MIN_MEMBER_PASSWORD_LENGTH) {
    return `كلمة المرور يجب أن تكون ${MIN_MEMBER_PASSWORD_LENGTH} أحرف على الأقل`;
  }
  if (password.length > 128) return "كلمة المرور طويلة جداً";
  if (!/[A-Za-z\u0600-\u06FF]/.test(password) || !/[0-9\u0660-\u0669]/.test(password)) {
    return "كلمة المرور يجب أن تحتوي على حروف وأرقام";
  }
  return null;
}

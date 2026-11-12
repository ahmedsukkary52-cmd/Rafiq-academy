/**
 * PH-02 — shared caller helpers for server-authoritative callables.
 *
 * Role SSOT is `users/{uid}.role` (C1). Callables never trust a role, price,
 * balance, recipient or reviewer identity sent by the client.
 */

import type * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

export function requireCallerUid(uid: string | undefined): string {
  if (typeof uid !== "string" || uid.trim().length === 0) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }
  return uid.trim();
}

export async function loadCallerRole(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<string> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "ملف المستخدم غير موجود");
  }
  return activeRoleOf(snap.data());
}

/**
 * Effective academy role of a `users/{uid}` profile. A deactivated profile
 * (`isActive == false`) has no role, so a still-valid Auth token grants
 * nothing. Missing `isActive` is treated as active (legacy profiles), the
 * same default as the client and the security rules. A newly provisioned
 * Admin (`passwordChangeRequired`) has no role until completeFirstLogin.
 */
export function activeRoleOf(data: Record<string, unknown> | undefined): string {
  if (!data || data.isActive === false || data.passwordChangeRequired === true) return "";
  return typeof data.role === "string" ? data.role : "";
}

export function requireText(raw: unknown, field: string, maxLength = 200): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} مطلوب`);
  }
  const value = raw.trim();
  if (value.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} طويل جداً`);
  }
  return value;
}

export function optionalText(raw: unknown, maxLength: number): string {
  if (raw == null) return "";
  if (typeof raw !== "string") {
    throw new HttpsError("invalid-argument", "قيمة نصية غير صالحة");
  }
  const value = raw.trim();
  if (value.length > maxLength) {
    throw new HttpsError("invalid-argument", "النص طويل جداً");
  }
  return value;
}

export function stringList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((v): v is string => typeof v === "string")
    .map((v) => v.trim())
    .filter((v) => v.length > 0);
}

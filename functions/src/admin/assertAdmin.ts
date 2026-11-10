import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";
import { activeRoleOf } from "../authority/callerContext";

const ADMIN_ROLE = "admin";

/**
 * Verifies the callable caller has users/{uid}.role == admin.
 * Role SSOT is Firestore profile role (C1) — no custom claims required.
 */
export async function assertCallerIsAdmin(uid: string | undefined): Promise<string> {
  if (!uid) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }

  const snap = await admin.firestore().collection("users").doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError("permission-denied", "ملف المستخدم غير موجود");
  }

  if (activeRoleOf(snap.data()) !== ADMIN_ROLE) {
    throw new HttpsError(
      "permission-denied",
      "هذه العملية متاحة للمسؤول فقط",
    );
  }

  return uid;
}

export const ALLOWED_PROVISION_ROLES = [
  "student",
  "parent",
  "teacher",
  "supervisor",
  "assistant_teacher",
  "admin",
] as const;

export type ProvisionRole = (typeof ALLOWED_PROVISION_ROLES)[number];

export function parseProvisionRole(raw: unknown): ProvisionRole {
  if (typeof raw !== "string" || !ALLOWED_PROVISION_ROLES.includes(raw as ProvisionRole)) {
    throw new HttpsError(
      "invalid-argument",
      "role غير صالح — يجب أن يكون أحد أدوار الأكاديمية",
    );
  }
  return raw as ProvisionRole;
}

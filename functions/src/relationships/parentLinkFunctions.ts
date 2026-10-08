/**
 * P0-01 / D12 — Admin-controlled Parent ↔ Student linking.
 *
 * `parentProfiles/{parentId}.childrenIds` is the relationship graph read by
 * rules (`isLinkedParentOf`), payment review, notifications, overdue grace and
 * chat authorization. Only this callable writes it (rules deny every client,
 * including Admin). Each change is transactional on the parent profile,
 * idempotent (re-linking or re-unlinking is a no-op) and audited.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
} from "../audit/auditLogContract";
import { adminActor, buildAuditLogEntry } from "../audit/auditLogWrite";
import {
  loadCallerRole,
  requireCallerUid,
  requireText,
  stringList,
} from "../authority/callerContext";
import { LIFECYCLE_ARCHIVED } from "../lifecycle/studentLifecycleContract";
import { assertBackendAllowed } from "../productionGate";

export const PARENT_LINK_OPERATIONS = ["link", "unlink"] as const;
export type ParentLinkOperation = (typeof PARENT_LINK_OPERATIONS)[number];

export function parseParentLinkOperation(raw: unknown): ParentLinkOperation {
  if (raw == null) return "link";
  if (
    typeof raw === "string" &&
    (PARENT_LINK_OPERATIONS as readonly string[]).includes(raw)
  ) {
    return raw as ParentLinkOperation;
  }
  throw new HttpsError("invalid-argument", "نوع العملية غير صالح");
}

/** Pure next-state for childrenIds (deduplicated, stable order). */
export function nextChildrenIds(
  current: readonly string[],
  studentId: string,
  operation: ParentLinkOperation,
): { childrenIds: string[]; changed: boolean } {
  const unique = [...new Set(current)];
  const has = unique.includes(studentId);
  if (operation === "link") {
    if (has) return { childrenIds: unique, changed: false };
    return { childrenIds: [...unique, studentId], changed: true };
  }
  if (!has) return { childrenIds: unique, changed: false };
  return { childrenIds: unique.filter((id) => id !== studentId), changed: true };
}

export type ParentLinkResult = {
  parentId: string;
  studentId: string;
  operation: ParentLinkOperation;
  changed: boolean;
  childrenIds: string[];
};

export async function adminLinkParentChildCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<ParentLinkResult> {
  const uid = requireCallerUid(callerUid);
  const parentId = requireText(data.parentId, "parentId");
  const studentId = requireText(data.studentId, "studentId");
  const operation = parseParentLinkOperation(data.operation);

  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "ربط ولي الأمر بالطالب متاح للمسؤول فقط");
  }

  const parentUserRef = db.collection("users").doc(parentId);
  const studentUserRef = db.collection("users").doc(studentId);
  const parentProfileRef = db.collection("parentProfiles").doc(parentId);
  const studentProfileRef = db.collection("studentProfiles").doc(studentId);

  return db.runTransaction(async (tx) => {
    const [parentUser, studentUser, parentProfile, studentProfile] = await tx.getAll(
      parentUserRef,
      studentUserRef,
      parentProfileRef,
      studentProfileRef,
    );
    if (!parentUser.exists || parentUser.data()?.role !== "parent") {
      throw new HttpsError("failed-precondition", "الحساب المحدد ليس ولي أمر");
    }
    if (!parentProfile.exists) {
      throw new HttpsError("failed-precondition", "ملف ولي الأمر غير موجود");
    }
    if (operation === "link") {
      if (!studentUser.exists || studentUser.data()?.role !== "student") {
        throw new HttpsError("failed-precondition", "الحساب المحدد ليس طالباً");
      }
      if (!studentProfile.exists) {
        throw new HttpsError("failed-precondition", "ملف الطالب غير موجود");
      }
      if (studentUser.data()?.lifecycle === LIFECYCLE_ARCHIVED) {
        throw new HttpsError("failed-precondition", "لا يمكن ربط طالب مؤرشف");
      }
    }

    const next = nextChildrenIds(
      stringList(parentProfile.data()?.childrenIds),
      studentId,
      operation,
    );
    if (next.changed) {
      tx.update(parentProfileRef, {
        childrenIds: next.childrenIds,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(
        db.collection(AUDIT_LOGS_COLLECTION).doc(),
        buildAuditLogEntry(
          {
            actor: adminActor(uid),
            action: AUDIT_ACTION.relationshipChildrenChange,
            targetType: AUDIT_TARGET_TYPE.parentProfile,
            targetId: parentId,
            metadata: { parentId, studentId, operation },
            source: "adminLinkParentChild",
          },
          FieldValue.serverTimestamp(),
        ),
      );
    }
    return {
      parentId,
      studentId,
      operation,
      changed: next.changed,
      childrenIds: next.childrenIds,
    };
  });
}

export const adminLinkParentChild = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("adminLinkParentChild");
    return adminLinkParentChildCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

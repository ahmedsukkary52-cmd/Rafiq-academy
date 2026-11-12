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
import { LIFECYCLE_ARCHIVED, normalizeLifecycle } from "../lifecycle/studentLifecycleContract";
import { assertBackendAllowed } from "../productionGate";
import { appendRelationshipHistory, RELATIONSHIP_KIND } from "./relationshipHistory";

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
      if (normalizeLifecycle(studentProfile.get("lifecycle")) === LIFECYCLE_ARCHIVED) {
        throw new HttpsError("failed-precondition", "لا يمكن ربط طالب مؤرشف");
      }
      if (parentUser.data()?.isActive === false) {
        throw new HttpsError("failed-precondition", "حساب ولي الأمر غير نشط");
      }
    }

    const next = nextChildrenIds(
      stringList(parentProfile.data()?.childrenIds),
      studentId,
      operation,
    );
    // Every student keeps at least one guardian (adminOnboardStudent always
    // links one); moving the last one goes through adminReplaceParentLink.
    // A link to a missing or non-student account can still be cleaned up.
    if (
      operation === "unlink" &&
      next.changed &&
      studentUser.exists &&
      studentUser.data()?.role === "student"
    ) {
      const guardians = await tx.get(
        db.collection("parentProfiles").where("childrenIds", "array-contains", studentId),
      );
      if (guardians.docs.every((d) => d.id === parentId)) {
        throw new HttpsError(
          "failed-precondition",
          "لا يمكن فك ارتباط ولي الأمر الوحيد للطالب؛ استخدم استبدال ولي الأمر",
        );
      }
    }
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
      appendRelationshipHistory(db, tx, {
        kind: RELATIONSHIP_KIND.parentChild,
        operation,
        actorId: uid,
        actorRole: "admin",
        parentId,
        studentId,
      });
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

export type ParentReplaceResult = {
  studentId: string;
  fromParentId: string;
  toParentId: string;
  changed: boolean;
};

/**
 * Moves a child from one guardian to another in one transaction, so the
 * student is never left without the old link and without the new one. Other
 * guardians of the same child are untouched.
 */
export async function adminReplaceParentLinkCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<ParentReplaceResult> {
  const uid = requireCallerUid(callerUid);
  const studentId = requireText(data.studentId, "studentId");
  const fromParentId = requireText(data.fromParentId, "fromParentId");
  const toParentId = requireText(data.toParentId, "toParentId");
  if (fromParentId === toParentId) {
    throw new HttpsError("invalid-argument", "ولي الأمر الجديد هو نفسه الحالي");
  }
  if ((await loadCallerRole(db, uid)) !== "admin") {
    throw new HttpsError("permission-denied", "تغيير ولي الأمر متاح للمسؤول فقط");
  }
  const refs = {
    student: db.collection("users").doc(studentId),
    studentProfile: db.collection("studentProfiles").doc(studentId),
    fromUser: db.collection("users").doc(fromParentId),
    toUser: db.collection("users").doc(toParentId),
    fromProfile: db.collection("parentProfiles").doc(fromParentId),
    toProfile: db.collection("parentProfiles").doc(toParentId),
  };

  return db.runTransaction(async (tx) => {
    const [student, studentProfile, , toUser, fromProfile, toProfile] = await tx.getAll(
      refs.student,
      refs.studentProfile,
      refs.fromUser,
      refs.toUser,
      refs.fromProfile,
      refs.toProfile,
    );
    if (!student.exists || student.get("role") !== "student" || !studentProfile.exists) {
      throw new HttpsError("failed-precondition", "الحساب المحدد ليس طالباً");
    }
    if (normalizeLifecycle(studentProfile.get("lifecycle")) === LIFECYCLE_ARCHIVED) {
      throw new HttpsError("failed-precondition", "لا يمكن تعديل روابط طالب مؤرشف");
    }
    if (!toUser.exists || toUser.get("role") !== "parent" || !toProfile.exists) {
      throw new HttpsError("failed-precondition", "ولي الأمر الجديد غير صالح");
    }
    if (toUser.get("isActive") === false) {
      throw new HttpsError("failed-precondition", "حساب ولي الأمر الجديد غير نشط");
    }
    const fromChildren = stringList(fromProfile.data()?.childrenIds);
    if (!fromProfile.exists || !fromChildren.includes(studentId)) {
      throw new HttpsError("failed-precondition", "الطالب غير مرتبط بولي الأمر الحالي المحدد");
    }
    const removed = nextChildrenIds(fromChildren, studentId, "unlink");
    const added = nextChildrenIds(stringList(toProfile.data()?.childrenIds), studentId, "link");
    tx.update(refs.fromProfile, {
      childrenIds: removed.childrenIds,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (added.changed) {
      tx.update(refs.toProfile, {
        childrenIds: added.childrenIds,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: adminActor(uid),
          action: AUDIT_ACTION.relationshipChildrenChange,
          targetType: AUDIT_TARGET_TYPE.parentProfile,
          targetId: toParentId,
          metadata: { parentId: toParentId, previousParentId: fromParentId, studentId, operation: "replace" },
          source: "adminReplaceParentLink",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    appendRelationshipHistory(db, tx, {
      kind: RELATIONSHIP_KIND.parentChild,
      operation: "replace",
      actorId: uid,
      actorRole: "admin",
      studentId,
      parentId: toParentId,
      previousParentId: fromParentId,
    });
    return { studentId, fromParentId, toParentId, changed: true };
  });
}

export const adminReplaceParentLink = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("adminReplaceParentLink");
    return adminReplaceParentLinkCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

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

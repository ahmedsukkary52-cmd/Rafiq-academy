/**
 * WA-11 — load relationship graph slices from Firestore for 1:1 auth.
 */

import * as admin from "firebase-admin";
import { activeRoleOf } from "../authority/callerContext";
import {
  emptyRelationshipContext,
  isChatRole,
  parseHalaqaRow,
  type ChatRole,
  type RelationshipContext,
} from "./chatRelationship";

export async function loadUserRole(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<ChatRole | null> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) return null;
  const role = activeRoleOf(snap.data());
  return isChatRole(role) ? role : null;
}

export async function loadRelationshipContext(
  db: admin.firestore.Firestore,
  uid: string,
  role: ChatRole,
): Promise<RelationshipContext> {
  const ctx = emptyRelationshipContext();

  if (role === "student") {
    const qs = await db
      .collection("halaqat")
      .where("studentIds", "array-contains", uid)
      .get();
    ctx.studentHalaqat = qs.docs.map((d) =>
      parseHalaqaRow(d.id, d.data() as Record<string, unknown>),
    );
    return ctx;
  }

  if (role === "teacher") {
    const qs = await db
      .collection("halaqat")
      .where("teacherId", "==", uid)
      .get();
    ctx.teacherHalaqat = qs.docs.map((d) =>
      parseHalaqaRow(d.id, d.data() as Record<string, unknown>),
    );
    return ctx;
  }

  if (role === "supervisor") {
    const qs = await db
      .collection("halaqat")
      .where("supervisorId", "==", uid)
      .get();
    ctx.supervisorHalaqat = qs.docs.map((d) =>
      parseHalaqaRow(d.id, d.data() as Record<string, unknown>),
    );
    return ctx;
  }

  if (role === "parent") {
    const snap = await db.collection("parentProfiles").doc(uid).get();
    const children = snap.data()?.childrenIds;
    ctx.parentChildrenIds = Array.isArray(children)
      ? children
          .filter((c): c is string => typeof c === "string")
          .map((c) => c.trim())
          .filter(Boolean)
      : [];
    return ctx;
  }

  // admin — no graph slice required for staff/management pairs
  return ctx;
}

export async function loadParticipantProfile(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<{ uid: string; name: string; role: string; profileImageUrl?: string }> {
  const userSnap = await db.collection("users").doc(uid).get();
  if (userSnap.exists) {
    const data = userSnap.data() ?? {};
    return {
      uid,
      name: typeof data.name === "string" ? data.name : "",
      role: typeof data.role === "string" ? data.role : "",
      profileImageUrl:
        typeof data.profileImageUrl === "string"
          ? data.profileImageUrl
          : undefined,
    };
  }
  return { uid, name: "", role: "" };
}

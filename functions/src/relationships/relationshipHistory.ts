/**
 * Append-only relationship history (`relationshipHistory`).
 *
 * Every trusted operation that changes who is related to whom (parent ↔
 * child, halaqa membership, primary teacher, supervisor, assistant teacher,
 * temporary cover) appends one entry inside its own transaction, so the
 * history can never disagree with the relationship it describes. Entries are
 * never updated or deleted; rules allow Admin reads only.
 *
 * `subjectIds` lists every person and halaqa the change touches, so a single
 * `array-contains` query returns the history of one profile from any side.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

export const RELATIONSHIP_HISTORY_COLLECTION = "relationshipHistory";

export const RELATIONSHIP_KIND = {
  parentChild: "parent_child",
  halaqaMembership: "halaqa_membership",
  halaqaTeacher: "halaqa_teacher",
  halaqaSupervisor: "halaqa_supervisor",
  halaqaAssistant: "halaqa_assistant",
  halaqaCover: "halaqa_cover",
} as const;
export type RelationshipKind = (typeof RELATIONSHIP_KIND)[keyof typeof RELATIONSHIP_KIND];

export type RelationshipEntry = {
  kind: RelationshipKind;
  /** link | unlink | replace | admit | transfer | create | assign | unassign | start | end */
  operation: string;
  actorId: string;
  actorRole: string;
  halaqaId?: string;
  fromHalaqaId?: string;
  toHalaqaId?: string;
  studentId?: string;
  parentId?: string;
  previousParentId?: string;
  staffId?: string;
  previousStaffId?: string;
  coverId?: string;
  reason?: string;
};

const ID_FIELDS = [
  "halaqaId",
  "fromHalaqaId",
  "toHalaqaId",
  "studentId",
  "parentId",
  "previousParentId",
  "staffId",
  "previousStaffId",
] as const;

/** Pure document shape; `at` is injected so tests can compare it. */
export function buildRelationshipEntry<T>(entry: RelationshipEntry, at: T): Record<string, unknown> {
  const doc: Record<string, unknown> = {
    kind: entry.kind,
    operation: entry.operation,
    actorId: entry.actorId,
    actorRole: entry.actorRole,
    at,
  };
  const subjects = new Set<string>();
  for (const field of ID_FIELDS) {
    const value = typeof entry[field] === "string" ? (entry[field] as string).trim() : "";
    if (!value) continue;
    doc[field] = value;
    subjects.add(value);
  }
  if (entry.coverId) doc.coverId = entry.coverId;
  if (entry.reason) doc.reason = entry.reason;
  doc.subjectIds = [...subjects].sort();
  return doc;
}

export function appendRelationshipHistory(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  entry: RelationshipEntry,
): void {
  tx.set(
    db.collection(RELATIONSHIP_HISTORY_COLLECTION).doc(),
    buildRelationshipEntry(entry, FieldValue.serverTimestamp()),
  );
}

/**
 * Stable academy reference codes (e.g. S-003, P-001, T-001).
 *
 * Three identifiers are kept apart:
 *   - the academy reference (`users.academyRef`, user-facing, never reused);
 *   - the Firebase UID (internal, never shown);
 *   - the relationship itself (parentProfiles.childrenIds, halaqat.*).
 *
 * Bulk import uses the roster's own codes; accounts and halaqat created one by
 * one in the app get the next free code of their kind (`halaqat.academyRef`). Both share the academy-wide
 * `importRows/{ref}` ledger, so a code can never point at two people, and a
 * later import that repeats a code created in the app is recognised instead
 * of duplicating the person.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { normalizeArabicSearchText } from "../search/arabicNormalization";

export const ACADEMY_REF_COUNTERS_COLLECTION = "academyRefCounters";
const LEDGER = "importRows";
const MAX_PROBES = 200;

export type RefKind = "student" | "parent" | "teacher" | "supervisor" | "assistant" | "halaqa";

export const REF_PREFIX: Record<RefKind, string> = {
  student: "S",
  parent: "P",
  teacher: "T",
  supervisor: "V",
  assistant: "A",
  halaqa: "H",
};

export function formatAcademyRef(kind: RefKind, n: number): string {
  return `${REF_PREFIX[kind]}-${String(n).padStart(3, "0")}`;
}

/** The number of [ref] when it is an app-format code of [kind] (S-500 → 500). */
export function academyRefNumber(kind: RefKind, ref: string): number | null {
  const match = new RegExp(`^${REF_PREFIX[kind]}-(\\d{1,9})$`).exec(ref);
  return match ? Number(match[1]) : null;
}

export function academyRefCounterRef(db: admin.firestore.Firestore, kind: RefKind) {
  return db.collection(ACADEMY_REF_COUNTERS_COLLECTION).doc(kind);
}

/** Ledger entry written for an account created in the app (not by import). */
export function manualLedgerEntry(kind: RefKind, uid: string, name: string) {
  return {
    kind,
    id: uid,
    status: "done",
    origin: "manual",
    fingerprint: "manual",
    nameNormalized: normalizeArabicSearchText(name),
  };
}

/**
 * Whether an import row may adopt a code already created in the app: same
 * kind and the same person name. Anything else stays a conflict.
 */
export function manualEntryMatches(
  entry: Record<string, unknown> | undefined,
  kind: string,
  name: string,
): boolean {
  return (
    entry?.origin === "manual" &&
    entry?.kind === kind &&
    typeof entry?.id === "string" &&
    entry.nameNormalized === normalizeArabicSearchText(name)
  );
}

export type AcademyRefReservation = { kind: RefKind; n: number; ref: string };

/**
 * Read half of an allocation inside [tx]: the next code of [kind] that the
 * ledger does not hold yet (codes taken by an earlier import are skipped,
 * never overwritten). Call before the transaction's first write, then
 * [claimAcademyRefInTx]. Concurrent allocations read the same counter
 * document, so Firestore serialises them and a code is never handed out twice.
 */
export async function reserveAcademyRefInTx(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  kind: RefKind,
): Promise<AcademyRefReservation> {
  const counter = await tx.get(db.collection(ACADEMY_REF_COUNTERS_COLLECTION).doc(kind));
  const last = counter.data()?.last;
  const start = typeof last === "number" ? last : 0;
  const free = await probeFreeRef(db, tx, kind, start);
  if (free) return free;
  // A dense run of roster codes imported without moving the counter (ledgers
  // written before imports advanced it): continue after the highest code of
  // this kind instead of failing.
  const entries = await tx.get(db.collection(LEDGER).where("kind", "==", kind));
  const highest = Math.max(start, ...entries.docs.map((d) => academyRefNumber(kind, d.id) ?? 0));
  const after = await probeFreeRef(db, tx, kind, highest);
  if (after) return after;
  throw new HttpsError("resource-exhausted", "تعذر تخصيص رقم مرجعي، أعد المحاولة");
}

async function probeFreeRef(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  kind: RefKind,
  from: number,
): Promise<AcademyRefReservation | null> {
  let n = from;
  for (let probe = 0; probe < MAX_PROBES; probe++) {
    n += 1;
    const ref = formatAcademyRef(kind, n);
    const slot = await tx.get(db.collection(LEDGER).doc(ref));
    if (!slot.exists) return { kind, n, ref };
  }
  return null;
}

/** Write half: records the reserved code in the ledger and advances the counter. */
export function claimAcademyRefInTx(
  db: admin.firestore.Firestore,
  tx: admin.firestore.Transaction,
  reservation: AcademyRefReservation,
  owner: { id: string; name: string },
): void {
  tx.set(db.collection(LEDGER).doc(reservation.ref), {
    ...manualLedgerEntry(reservation.kind, owner.id, owner.name),
    updatedAt: FieldValue.serverTimestamp(),
  });
  tx.set(
    db.collection(ACADEMY_REF_COUNTERS_COLLECTION).doc(reservation.kind),
    { last: reservation.n, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
}

/**
 * Reserves the next free code of [kind] for [uid] and stamps it on the user.
 */
export async function allocateAcademyRef(
  db: admin.firestore.Firestore,
  params: { kind: RefKind; uid: string; name: string },
): Promise<string> {
  return db.runTransaction(async (tx) => {
    const reservation = await reserveAcademyRefInTx(db, tx, params.kind);
    claimAcademyRefInTx(db, tx, reservation, { id: params.uid, name: params.name });
    tx.update(db.collection("users").doc(params.uid), { academyRef: reservation.ref });
    return reservation.ref;
  });
}

import { createHash } from "node:crypto";

import * as admin from "firebase-admin";
import { FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import {
  FCM_DEVICES_SUBCOLLECTION,
  FCM_TOKENS_COLLECTION,
  isUsableToken,
  SendableToken,
} from "./fcmTokenContract";
import { isOwnershipReconcileEnabled } from "./ownershipGate";

/**
 * H2 — one active account per FCM token (server-owned).
 *
 * `fcmTokenOwners/{sha256(token)}` = `{ uid, deviceId, claimedAt }` names the
 * single device record allowed to receive pushes for that token. The newest
 * enabled registration of a token (by the device document's server
 * `updateTime`, which the client cannot forge) owns it; the losing record is
 * disabled with `disabledReason: "token_transferred"`.
 *
 * Clients never touch this collection (Rules catch-all deny). The token is
 * stored only as a hash. Senders consult the owner record; a token with no
 * owner record yet (registered before this trigger existed) keeps the legacy
 * behaviour until its next registration claims it or the backfill runs.
 *
 * Releasing a token (owner disabled it or moved to a new token) leaves a
 * tombstone `{ releasedAt }` instead of deleting the record: once a token has
 * had an owner it is never "legacy" again, so a stale pre-trigger record of a
 * previous account holding the same token cannot become sendable.
 */
export const FCM_TOKEN_OWNERS_COLLECTION = "fcmTokenOwners";
export const TOKEN_TRANSFERRED_REASON = "token_transferred";

export type TokenOwner = { uid: string; deviceId: string };

export function tokenOwnerDocId(token: string): string {
  return createHash("sha256").update(token.trim()).digest("hex");
}

/** Whether [uid]/[deviceId] may receive pushes for a token with [owner]. */
export function deviceOwnsToken(
  owner: Partial<TokenOwner> | null | undefined,
  uid: string,
  deviceId: string,
): boolean {
  if (!owner) return true;
  return owner.uid === uid && owner.deviceId === deviceId;
}

export type OwnershipOutcome =
  | "claimed"
  | "unchanged"
  | "lost_to_newer"
  | "released"
  | "ignored";

type DeviceState = {
  ref: admin.firestore.DocumentReference;
  token: string | null;
  updateTime: admin.firestore.Timestamp | null;
};

function enabledToken(
  snap: admin.firestore.DocumentSnapshot,
): string | null {
  if (!snap.exists) return null;
  const data = snap.data() ?? {};
  if (data.disabled === true || !isUsableToken(data.token)) return null;
  return (data.token as string).trim();
}

function deviceRef(
  db: admin.firestore.Firestore,
  uid: string,
  deviceId: string,
): admin.firestore.DocumentReference {
  return db
    .collection(FCM_TOKENS_COLLECTION)
    .doc(uid)
    .collection(FCM_DEVICES_SUBCOLLECTION)
    .doc(deviceId);
}

function isNewer(
  a: admin.firestore.Timestamp | null,
  b: admin.firestore.Timestamp | null,
): boolean {
  if (!a) return false;
  if (!b) return true;
  return a.seconds > b.seconds ||
    (a.seconds === b.seconds && a.nanoseconds > b.nanoseconds);
}

/**
 * Reconciles ownership after a write to `fcmTokens/{uid}/devices/{deviceId}`.
 *
 * Works from the *current* documents inside one transaction, so duplicate,
 * late or out-of-order trigger deliveries converge to the same result.
 * [previousToken] is the token before the write, released if this device
 * no longer holds it enabled.
 */
export async function reconcileDeviceTokenOwnership(
  db: admin.firestore.Firestore,
  params: {
    uid: string;
    deviceId: string;
    previousToken?: unknown;
    /** Backfill only: never claim a token whose owner released it. */
    skipReleased?: boolean;
  },
): Promise<OwnershipOutcome> {
  const { uid, deviceId } = params;
  const previous = isUsableToken(params.previousToken)
    ? params.previousToken.trim()
    : null;
  const ref = deviceRef(db, uid, deviceId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = enabledToken(snap);
    const now = FieldValue.serverTimestamp();
    const release = (target: admin.firestore.DocumentReference) =>
      tx.set(target, { releasedAt: now });

    if (current === null) {
      if (previous === null) return "ignored";
      const ownerRef = db
        .collection(FCM_TOKEN_OWNERS_COLLECTION)
        .doc(tokenOwnerDocId(previous));
      const owner = await tx.get(ownerRef);
      if (!owner.exists || !deviceOwnsToken(owner.data(), uid, deviceId)) {
        return "ignored";
      }
      release(ownerRef);
      return "released";
    }

    const ownerRef = db
      .collection(FCM_TOKEN_OWNERS_COLLECTION)
      .doc(tokenOwnerDocId(current));
    const releaseRef =
      previous !== null && previous !== current
        ? db.collection(FCM_TOKEN_OWNERS_COLLECTION).doc(tokenOwnerDocId(previous))
        : null;

    const ownerSnap = await tx.get(ownerRef);
    const releaseSnap = releaseRef ? await tx.get(releaseRef) : null;
    const owner = ownerSnap.exists
      ? (ownerSnap.data() as Partial<TokenOwner>)
      : null;
    if (params.skipReleased && owner && typeof owner.uid !== "string") {
      return "ignored";
    }
    const self: DeviceState = {
      ref,
      token: current,
      updateTime: snap.updateTime ?? null,
    };

    let rival: DeviceState | null = null;
    if (
      owner &&
      typeof owner.uid === "string" &&
      typeof owner.deviceId === "string" &&
      !deviceOwnsToken(owner, uid, deviceId)
    ) {
      const rivalRef = deviceRef(db, owner.uid, owner.deviceId);
      const rivalSnap = await tx.get(rivalRef);
      rival = {
        ref: rivalRef,
        token: enabledToken(rivalSnap),
        updateTime: rivalSnap.updateTime ?? null,
      };
    }

    if (releaseRef && releaseSnap?.exists &&
        deviceOwnsToken(releaseSnap.data(), uid, deviceId)) {
      release(releaseRef);
    }

    const disable = (target: DeviceState) =>
      tx.set(
        target.ref,
        {
          disabled: true,
          disabledReason: TOKEN_TRANSFERRED_REASON,
          disabledAt: now,
        },
        { merge: true },
      );

    if (rival && rival.token === current && isNewer(rival.updateTime, self.updateTime)) {
      disable(self);
      tx.set(ownerRef, {
        uid: owner!.uid,
        deviceId: owner!.deviceId,
        claimedAt: rival.updateTime,
      });
      return "lost_to_newer";
    }

    if (rival && rival.token === current) disable(rival);

    if (owner && deviceOwnsToken(owner, uid, deviceId)) {
      // claimedAt is informational: no ownership decision reads it (isNewer
      // compares device updateTimes), so it is only filled in when missing.
      if (!(ownerSnap.get("claimedAt") instanceof Timestamp)) {
        tx.set(ownerRef, { claimedAt: self.updateTime }, { merge: true });
      }
      return "unchanged";
    }
    tx.set(ownerRef, { uid, deviceId, claimedAt: self.updateTime });
    return "claimed";
  });
}

/** Drops tokens whose owner record names a different account or device. */
export async function filterOwnedTokens(
  db: admin.firestore.Firestore,
  uid: string,
  tokens: readonly SendableToken[],
): Promise<SendableToken[]> {
  if (tokens.length === 0) return [];
  const owners = await db.getAll(
    ...tokens.map((t) =>
      db.collection(FCM_TOKEN_OWNERS_COLLECTION).doc(tokenOwnerDocId(t.token)),
    ),
  );
  return tokens.filter((t, i) =>
    deviceOwnsToken(
      owners[i].exists ? (owners[i].data() as Partial<TokenOwner>) : null,
      uid,
      t.deviceId,
    ),
  );
}

export type OwnershipBackfillPage = {
  scanned: number;
  outcomes: Partial<Record<OwnershipOutcome, number>>;
  nextCursor: string | null;
  done: boolean;
};

/**
 * One page of the one-off migration for device records written before the
 * trigger existed. Each enabled record goes through the same transaction as
 * the trigger, so the newest registration of a shared token ends up the sole
 * owner and older holders are disabled; re-running is idempotent. Released
 * tokens are never re-claimed. [cursor] is the last document path returned.
 */
export async function backfillTokenOwnershipPage(
  db: admin.firestore.Firestore,
  params: { pageSize: number; cursor?: string | null },
): Promise<OwnershipBackfillPage> {
  let query = db
    .collectionGroup(FCM_DEVICES_SUBCOLLECTION)
    .orderBy(FieldPath.documentId())
    .limit(params.pageSize);
  if (params.cursor) query = query.startAfter(params.cursor);
  const page = await query.get();

  const outcomes: Partial<Record<OwnershipOutcome, number>> = {};
  for (const doc of page.docs) {
    const owner = doc.ref.parent.parent;
    if (!owner || owner.parent.id !== FCM_TOKENS_COLLECTION) continue;
    if (enabledToken(doc) === null) continue;
    const outcome = await reconcileDeviceTokenOwnership(db, {
      uid: owner.id,
      deviceId: doc.id,
      skipReleased: true,
    });
    outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
  }

  const done = page.size < params.pageSize;
  return {
    scanned: page.size,
    outcomes,
    nextCursor: done || page.empty ? null : page.docs[page.size - 1].ref.path,
    done,
  };
}

/**
 * Retried deliveries older than this are dropped. Bounds the cost of an
 * outage. Ownership left stale by a dropped (expired or permanently failed)
 * event is repaired by the holder's next registration: the client upsert
 * always rewrites `updatedAt` with a server timestamp, so every sign-in, app
 * start and token refresh raises a fresh event that reconciles from current
 * state. Until then the previous owner may keep receiving that device's
 * pushes; a holder that never registers again stays stale.
 */
export const OWNERSHIP_RETRY_WINDOW_MS = 6 * 60 * 60 * 1000;

// gRPC status codes (numeric and string forms) worth another delivery:
// CANCELLED, UNKNOWN, DEADLINE_EXCEEDED, RESOURCE_EXHAUSTED, ABORTED,
// INTERNAL, UNAVAILABLE.
const TRANSIENT_CODES = new Set<number>([1, 2, 4, 8, 10, 13, 14]);
const TRANSIENT_NAMES = new Set<string>([
  "cancelled",
  "unknown",
  "deadline-exceeded",
  "resource-exhausted",
  "aborted",
  "internal",
  "unavailable",
]);

/** Whether a reconcile failure may succeed on a later delivery. */
export function isTransientOwnershipError(error: unknown): boolean {
  const code = (error as { code?: unknown } | null | undefined)?.code;
  if (typeof code === "number") return TRANSIENT_CODES.has(code);
  if (typeof code === "string") {
    return TRANSIENT_NAMES.has(code.toLowerCase().replace(/_/g, "-"));
  }
  return false;
}

export type OwnershipTriggerResult =
  | OwnershipOutcome
  | "gate_closed"
  | "expired"
  | "dropped";

/**
 * Trigger body. A closed gate or an expired delivery returns without
 * throwing; a transient failure rethrows so the platform redelivers the
 * event; anything else is logged and dropped (a redelivery would fail the
 * same way). Reconciliation reads current state in a transaction, so a
 * redelivered or duplicate event converges to the same owner.
 */
export async function runOwnershipTrigger(params: {
  gateOpen: boolean;
  eventTime: string | undefined;
  now?: number;
  reconcile: () => Promise<OwnershipOutcome>;
}): Promise<OwnershipTriggerResult> {
  if (!params.gateOpen) {
    console.warn(
      "[H2] reconcileFcmTokenOwnership skipped — ownership gate closed.",
    );
    return "gate_closed";
  }
  const sent = params.eventTime ? Date.parse(params.eventTime) : NaN;
  const age = (params.now ?? Date.now()) - sent;
  if (Number.isFinite(age) && age > OWNERSHIP_RETRY_WINDOW_MS) {
    console.error(
      "[H2] reconcileFcmTokenOwnership dropped an event older than the retry window.",
    );
    return "expired";
  }
  try {
    return await params.reconcile();
  } catch (error) {
    if (isTransientOwnershipError(error)) throw error;
    console.error("[H2] reconcileFcmTokenOwnership failed permanently.", {
      code: (error as { code?: unknown } | null)?.code ?? null,
    });
    return "dropped";
  }
}

export const reconcileFcmTokenOwnership = onDocumentWritten(
  {
    region: "europe-west1",
    document: "fcmTokens/{uid}/devices/{deviceId}",
    retry: true,
  },
  async (event) => {
    await runOwnershipTrigger({
      gateOpen: isOwnershipReconcileEnabled(),
      eventTime: event.time,
      reconcile: () =>
        reconcileDeviceTokenOwnership(admin.firestore(), {
          uid: event.params.uid,
          deviceId: event.params.deviceId,
          previousToken: event.data?.before?.data()?.token,
        }),
    });
  },
);

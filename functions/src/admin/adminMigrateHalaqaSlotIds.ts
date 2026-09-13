import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { assertBackendAllowed } from "../productionGate";
import { assertCallerIsAdmin } from "./assertAdmin";
import {
  isHalaqaReadyForSessionsSlotPrerequisite,
  migrateScheduleSlots,
  shouldWriteMigratedSchedule,
} from "../halaqa/slotIdMigration";

interface MigrateRequest {
  dryRun?: boolean;
  /** When set, migrate only this halaqa; otherwise all halaqat. */
  halaqaId?: string;
}

type HalaqaReport = {
  halaqaId: string;
  status: string | null;
  slotCount: number;
  assigned: number;
  preserved: number;
  skippedMalformed: number;
  changed: boolean;
  allHaveSlotIds: boolean;
  readyForSessions: boolean;
  wrote: boolean;
};

type MigrateResponse = {
  dryRun: boolean;
  halaqatScanned: number;
  halaqatNeedingMigration: number;
  halaqatUpdated: number;
  slotsAssigned: number;
  slotsPreserved: number;
  readyForSessionsPrerequisite: boolean;
  reports: HalaqaReport[];
};

function requireOptionalHalaqaId(raw: unknown): string | undefined {
  if (raw === undefined || raw === null || raw === "") return undefined;
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new HttpsError("invalid-argument", "halaqaId غير صالح");
  }
  return raw.trim();
}

/**
 * Transactional migrate: re-read schedule so a concurrent migrator that already
 * wrote slotIds wins (existing slotId never replaced).
 */
async function migrateHalaqaDoc(params: {
  db: admin.firestore.Firestore;
  ref: admin.firestore.DocumentReference;
  dryRun: boolean;
}): Promise<{
  status: string | null;
  migrated: ReturnType<typeof migrateScheduleSlots>;
  wrote: boolean;
  readyForSessions: boolean;
}> {
  const { db, ref, dryRun } = params;

  if (dryRun) {
    const snap = await ref.get();
    const raw = snap.data() ?? {};
    const migrated = migrateScheduleSlots(raw.schedule);
    const status = typeof raw.status === "string" ? raw.status : null;
    return {
      status,
      migrated,
      wrote: false,
      readyForSessions: isHalaqaReadyForSessionsSlotPrerequisite({
        status,
        schedule: migrated.schedule,
      }),
    };
  }

  let result!: {
    status: string | null;
    migrated: ReturnType<typeof migrateScheduleSlots>;
    wrote: boolean;
    readyForSessions: boolean;
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const raw = snap.data() ?? {};
    const migrated = migrateScheduleSlots(raw.schedule);
    const status = typeof raw.status === "string" ? raw.status : null;
    const wrote = shouldWriteMigratedSchedule(false, migrated.changed);
    if (wrote) {
      tx.update(ref, {
        schedule: migrated.schedule,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    result = {
      status,
      migrated,
      wrote,
      readyForSessions: isHalaqaReadyForSessionsSlotPrerequisite({
        status,
        schedule: migrated.schedule,
      }),
    };
  });

  return result;
}

/**
 * WA-7 — Admin-only backfill of stable UUID slotId on halaqat.schedule[].
 * Idempotent + transactional. Supports dryRun (no writes). Gated by WA-0.
 * Does NOT create sessions (WA-8).
 */
export const adminMigrateHalaqaSlotIds = onCall(
  { region: "us-central1" },
  async (request): Promise<MigrateResponse> => {
    assertBackendAllowed("adminMigrateHalaqaSlotIds");
    const adminUid = await assertCallerIsAdmin(request.auth?.uid);
    const data = (request.data ?? {}) as MigrateRequest;
    const dryRun = data.dryRun === true;
    const onlyId = requireOptionalHalaqaId(data.halaqaId);
    const db = admin.firestore();

    const snaps = onlyId
      ? await db
          .collection("halaqat")
          .doc(onlyId)
          .get()
          .then((doc) => (doc.exists ? [doc] : []))
      : (await db.collection("halaqat").get()).docs;

    if (onlyId && snaps.length === 0) {
      throw new HttpsError("not-found", "الحلقة غير موجودة");
    }

    const reports: HalaqaReport[] = [];
    let slotsAssigned = 0;
    let slotsPreserved = 0;
    let halaqatUpdated = 0;
    let halaqatNeedingMigration = 0;

    for (const doc of snaps) {
      const { status, migrated, wrote, readyForSessions } =
        await migrateHalaqaDoc({
          db,
          ref: doc.ref,
          dryRun,
        });

      const allHaveSlotIds = isHalaqaReadyForSessionsSlotPrerequisite({
        status: "active",
        schedule: migrated.schedule,
      });

      if (migrated.assigned > 0 || !readyForSessions) {
        halaqatNeedingMigration += 1;
      }
      if (wrote) halaqatUpdated += 1;

      slotsAssigned += migrated.assigned;
      slotsPreserved += migrated.preserved;

      reports.push({
        halaqaId: doc.id,
        status,
        slotCount: Array.isArray(migrated.schedule)
          ? migrated.schedule.length
          : 0,
        assigned: migrated.assigned,
        preserved: migrated.preserved,
        skippedMalformed: migrated.skippedMalformed,
        changed: migrated.changed,
        allHaveSlotIds,
        readyForSessions,
        wrote,
      });
    }

    if (!dryRun && halaqatUpdated > 0) {
      await db.collection("auditLogs").add({
        action: "halaqa_schedule_slotid_migrate",
        actorId: adminUid,
        dryRun: false,
        halaqatUpdated,
        slotsAssigned,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    return {
      dryRun,
      halaqatScanned: reports.length,
      halaqatNeedingMigration,
      halaqatUpdated,
      slotsAssigned,
      slotsPreserved,
      readyForSessionsPrerequisite: reports.every((r) => r.readyForSessions),
      reports,
    };
  },
);

/**
 * WA-7 / C6 §6.3 — pure helpers for stable schedule slotId backfill.
 * Idempotent: existing non-empty slotId values are preserved.
 */

import { randomUUID } from "node:crypto";

export type SlotMigrationStats = {
  assigned: number;
  preserved: number;
  skippedMalformed: number;
  changed: boolean;
};

export type MigratedScheduleResult = SlotMigrationStats & {
  schedule: unknown[];
};

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function existingSlotId(raw: unknown): string {
  if (typeof raw !== "string") return "";
  return raw.trim();
}

/**
 * Assigns UUID `slotId` where missing. Never deletes entries.
 * Does not rewrite day/startTime/endTime or other fields.
 * IDs are attached to slot objects — never derived from array index.
 */
export function migrateScheduleSlots(
  schedule: unknown,
  generateId: () => string = () => randomUUID(),
): MigratedScheduleResult {
  if (!Array.isArray(schedule)) {
    return {
      schedule: [],
      assigned: 0,
      preserved: 0,
      skippedMalformed: 0,
      changed: false,
    };
  }

  if (schedule.length === 0) {
    return {
      schedule: [],
      assigned: 0,
      preserved: 0,
      skippedMalformed: 0,
      changed: false,
    };
  }

  let assigned = 0;
  let preserved = 0;
  let skippedMalformed = 0;
  let changed = false;
  const out: unknown[] = [];

  for (const entry of schedule) {
    if (!isPlainObject(entry)) {
      skippedMalformed += 1;
      out.push(entry);
      continue;
    }

    const id = existingSlotId(entry.slotId);
    if (id) {
      preserved += 1;
      if (entry.slotId !== id) {
        out.push({ ...entry, slotId: id });
        changed = true;
      } else {
        out.push(entry);
      }
      continue;
    }

    const nextId = generateId();
    out.push({ ...entry, slotId: nextId });
    assigned += 1;
    changed = true;
  }

  return {
    schedule: out,
    assigned,
    preserved,
    skippedMalformed,
    changed,
  };
}

/** True when every plain-object slot has a non-empty slotId. */
export function scheduleSlotsAllHaveIds(schedule: unknown): boolean {
  if (!Array.isArray(schedule)) return false;
  if (schedule.length === 0) return true;
  for (const entry of schedule) {
    if (!isPlainObject(entry)) return false;
    if (!existingSlotId(entry.slotId)) return false;
  }
  return true;
}

/**
 * Sessions prerequisite (B-SLOT-ID-MIGRATE / D8):
 * active (or unknown-status) halaqat need a non-empty schedule with every
 * plain slot carrying slotId and no malformed entries.
 * Non-active halaqat do not block the prerequisite flag.
 */
export function isHalaqaReadyForSessionsSlotPrerequisite(params: {
  status: string | null | undefined;
  schedule: unknown;
}): boolean {
  const status = (params.status ?? "").trim();
  const isActiveLike = status === "" || status === "active";
  if (!isActiveLike) return true;
  if (!Array.isArray(params.schedule) || params.schedule.length === 0) {
    return false;
  }
  return scheduleSlotsAllHaveIds(params.schedule);
}

/** dryRun must never write; unchanged schedules must not write. */
export function shouldWriteMigratedSchedule(
  dryRun: boolean,
  changed: boolean,
): boolean {
  return dryRun !== true && changed === true;
}

/** D8 / WA-7 — reject empty schedule for new Halaqa writes (validation helper). */
export function assertNonEmptyScheduleWithSlotIds(schedule: unknown): void {
  if (!Array.isArray(schedule) || schedule.length === 0) {
    throw new Error("halaqa schedule must contain at least one slot");
  }
  if (!scheduleSlotsAllHaveIds(schedule)) {
    throw new Error("every schedule slot must have a stable slotId");
  }
}

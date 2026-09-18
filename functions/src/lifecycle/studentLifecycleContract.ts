/**
 * WA-15 / C14 — student operational lifecycle.
 *
 * The fourth status dimension, and the only one WA-15 introduces. It is
 * deliberately independent of the other three:
 *
 *   login/auth   → `users.isActive`               (untouched by WA-15)
 *   payment      → `paymentAccess/{parentId}`     (untouched by WA-15)
 *   membership   → `halaqat.studentIds`           (untouched by WA-15)
 *   lifecycle    → `studentProfiles.lifecycle`    ← this file
 *
 * Archiving is an operational statement only. It never disables an account,
 * never suspends payment, never changes a role, and never deletes history.
 */

export const STUDENT_PROFILES_COLLECTION = "studentProfiles";
export const USERS_COLLECTION = "users";

export const LIFECYCLE_FIELD = "lifecycle";
export const STUDENT_ROLE = "student";

export const LIFECYCLE_ACTIVE = "active";
export const LIFECYCLE_ARCHIVED = "archived";

export const LIFECYCLE_VALUES = [LIFECYCLE_ACTIVE, LIFECYCLE_ARCHIVED] as const;

export type LifecycleValue = (typeof LIFECYCLE_VALUES)[number];

export type LifecycleAction = "archive" | "unarchive";

export const LIFECYCLE_ACTIONS = ["archive", "unarchive"] as const;

/** Target state each action drives toward. */
export const LIFECYCLE_TARGET: Record<LifecycleAction, LifecycleValue> = {
  archive: LIFECYCLE_ARCHIVED,
  unarchive: LIFECYCLE_ACTIVE,
};

/** Maps lifecycle actions to canonical C16 audit actions (WA-16). */
export const LIFECYCLE_AUDIT_ACTION: Record<LifecycleAction, string> = {
  archive: "user_archive",
  unarchive: "user_unarchive",
};

export function isLifecycleValue(raw: unknown): raw is LifecycleValue {
  return raw === LIFECYCLE_ACTIVE || raw === LIFECYCLE_ARCHIVED;
}

/**
 * Missing or malformed lifecycle reads as `active`.
 *
 * This is what makes WA-15 migration-free: every existing student document
 * without the field is already correct, so no broad backfill is required.
 */
export function normalizeLifecycle(raw: unknown): LifecycleValue {
  if (typeof raw !== "string") return LIFECYCLE_ACTIVE;
  const value = raw.trim();
  return isLifecycleValue(value) ? value : LIFECYCLE_ACTIVE;
}

export function parseLifecycleAction(raw: unknown): LifecycleAction | null {
  if (raw !== "archive" && raw !== "unarchive") return null;
  return raw;
}

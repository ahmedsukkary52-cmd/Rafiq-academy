/**
 * WA-16 / C16 — shared audit log builder + writer.
 *
 * Guarantee (frozen):
 * At-least-once append semantics with operation-level idempotency where
 * applicable, and a possible audit gap if the business mutation succeeds but
 * the subsequent audit write fails.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import {
  ACTOR_ROLE_ADMIN,
  ACTOR_ROLE_ASSISTANT_TEACHER,
  ACTOR_ROLE_SUPERVISOR,
  ACTOR_ROLE_SYSTEM,
  ACTOR_ROLE_TEACHER,
  AUDIT_ACTION_FIELD,
  AUDIT_ACTOR_ID_FIELD,
  AUDIT_ACTOR_ROLE_FIELD,
  AUDIT_LEGACY_FORBIDDEN_FIELDS,
  AUDIT_LOGS_COLLECTION,
  AUDIT_METADATA_ALLOWLIST,
  AUDIT_METADATA_FIELD,
  AUDIT_METADATA_FORBIDDEN_KEYS,
  AUDIT_REQUIRED_FIELDS,
  AUDIT_SOURCE_FIELD,
  AUDIT_TARGET_ID_FIELD,
  AUDIT_TARGET_TYPE_FIELD,
  AUDIT_TIMESTAMP_FIELD,
  AuditActor,
  AuditLogInput,
  SYSTEM_ACTOR_ID,
} from "./auditLogContract";

export function adminActor(uid: string): AuditActor {
  const actorId = typeof uid === "string" ? uid.trim() : "";
  if (!actorId) {
    throw new Error("audit actorId (admin) is required");
  }
  return { actorId, actorRole: ACTOR_ROLE_ADMIN };
}

export function supervisorActor(uid: string): AuditActor {
  const actorId = typeof uid === "string" ? uid.trim() : "";
  if (!actorId) {
    throw new Error("audit actorId (supervisor) is required");
  }
  return { actorId, actorRole: ACTOR_ROLE_SUPERVISOR };
}

export function teacherActor(uid: string): AuditActor {
  const actorId = typeof uid === "string" ? uid.trim() : "";
  if (!actorId) {
    throw new Error("audit actorId (teacher) is required");
  }
  return { actorId, actorRole: ACTOR_ROLE_TEACHER };
}

/**
 * Actor for an authenticated caller whose role was loaded server-side from
 * `users/{uid}.role`. Parent / Student / unknown roles never author audits.
 */
export function actorForCallerRole(uid: string, role: string): AuditActor {
  switch (role) {
    case ACTOR_ROLE_ADMIN:
      return adminActor(uid);
    case ACTOR_ROLE_SUPERVISOR:
      return supervisorActor(uid);
    case ACTOR_ROLE_TEACHER:
      return teacherActor(uid);
    case ACTOR_ROLE_ASSISTANT_TEACHER:
      return { actorId: requireNonEmpty(uid, "actorId"), actorRole: ACTOR_ROLE_ASSISTANT_TEACHER };
    default:
      throw new Error(`audit actorRole not allowed for caller role: ${role}`);
  }
}

/** Reserved for future scheduler hooks (e.g. payment_suspend). */
export function systemActor(): AuditActor {
  return { actorId: SYSTEM_ACTOR_ID, actorRole: ACTOR_ROLE_SYSTEM };
}

function requireNonEmpty(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`audit ${field} is required`);
  }
  return value.trim();
}

function assertNoForbiddenMetadataKeys(
  metadata: Record<string, unknown>,
): void {
  for (const key of Object.keys(metadata)) {
    if (
      (AUDIT_METADATA_FORBIDDEN_KEYS as readonly string[]).includes(key)
    ) {
      throw new Error(`audit metadata forbids key: ${key}`);
    }
    if (!AUDIT_METADATA_ALLOWLIST.has(key)) {
      throw new Error(`audit metadata key not allowlisted: ${key}`);
    }
  }
}

/**
 * Builds a canonical NEW audit document.
 *
 * Always includes `metadata` (possibly `{}`). Never emits `actorUid` or
 * `createdAt`. Timestamp is injected by the caller as serverTimestamp.
 */
export function buildAuditLogEntry<T>(
  input: AuditLogInput,
  timestamp: T,
): Record<string, unknown> {
  const actorId = requireNonEmpty(input.actor.actorId, "actorId");
  const actorRole = requireNonEmpty(input.actor.actorRole, "actorRole");
  if (
    actorRole !== ACTOR_ROLE_ADMIN &&
    actorRole !== ACTOR_ROLE_SYSTEM &&
    actorRole !== ACTOR_ROLE_SUPERVISOR &&
    actorRole !== ACTOR_ROLE_TEACHER &&
    actorRole !== ACTOR_ROLE_ASSISTANT_TEACHER
  ) {
    throw new Error(`audit actorRole invalid: ${actorRole}`);
  }

  const action = requireNonEmpty(input.action, "action");
  const targetType = requireNonEmpty(input.targetType, "targetType");
  const targetId = requireNonEmpty(input.targetId, "targetId");
  const source = requireNonEmpty(input.source, "source");

  const metadata =
    input.metadata && typeof input.metadata === "object"
      && !Array.isArray(input.metadata)
      ? { ...input.metadata }
      : {};
  assertNoForbiddenMetadataKeys(metadata);

  const entry: Record<string, unknown> = {
    [AUDIT_ACTOR_ID_FIELD]: actorId,
    [AUDIT_ACTOR_ROLE_FIELD]: actorRole,
    [AUDIT_ACTION_FIELD]: action,
    [AUDIT_TARGET_TYPE_FIELD]: targetType,
    [AUDIT_TARGET_ID_FIELD]: targetId,
    [AUDIT_TIMESTAMP_FIELD]: timestamp,
    [AUDIT_METADATA_FIELD]: metadata,
    [AUDIT_SOURCE_FIELD]: source,
  };

  for (const legacy of AUDIT_LEGACY_FORBIDDEN_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(entry, legacy)) {
      throw new Error(`audit must not emit legacy field: ${legacy}`);
    }
  }

  for (const required of AUDIT_REQUIRED_FIELDS) {
    if (!Object.prototype.hasOwnProperty.call(entry, required)) {
      throw new Error(`audit missing required field: ${required}`);
    }
  }

  return entry;
}

/** Appends one audit document. Call only after a real business change. */
export async function writeAuditLog(
  input: AuditLogInput,
  db: admin.firestore.Firestore = admin.firestore(),
): Promise<void> {
  const entry = buildAuditLogEntry(input, FieldValue.serverTimestamp());
  await db.collection(AUDIT_LOGS_COLLECTION).add(entry);
}

/** Deterministic migration/page target ids (no random UUIDs). */
export function migrationTargetId(
  operation: string,
  pageKey: string,
): string {
  const op = requireNonEmpty(operation, "migration operation");
  const page = requireNonEmpty(pageKey, "migration pageKey");
  return `${op}_${page}`;
}

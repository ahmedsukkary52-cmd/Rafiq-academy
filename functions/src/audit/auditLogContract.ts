/**
 * WA-16 / C16 — canonical audit log contract.
 *
 * NEW audit documents use this envelope only. Historical documents may still
 * contain legacy fields (actorUid, createdAt, flat extras, old action names);
 * WA-16 does not rewrite them.
 */

export const AUDIT_LOGS_COLLECTION = "auditLogs";

export const AUDIT_ACTOR_ID_FIELD = "actorId";
export const AUDIT_ACTOR_ROLE_FIELD = "actorRole";
export const AUDIT_ACTION_FIELD = "action";
export const AUDIT_TARGET_TYPE_FIELD = "targetType";
export const AUDIT_TARGET_ID_FIELD = "targetId";
export const AUDIT_TIMESTAMP_FIELD = "timestamp";
export const AUDIT_METADATA_FIELD = "metadata";
export const AUDIT_SOURCE_FIELD = "source";

/** Forbidden on NEW documents — legacy field names. */
export const AUDIT_LEGACY_FORBIDDEN_FIELDS = [
  "actorUid",
  "createdAt",
] as const;

export const AUDIT_REQUIRED_FIELDS = [
  AUDIT_ACTOR_ID_FIELD,
  AUDIT_ACTOR_ROLE_FIELD,
  AUDIT_ACTION_FIELD,
  AUDIT_TARGET_TYPE_FIELD,
  AUDIT_TARGET_ID_FIELD,
  AUDIT_TIMESTAMP_FIELD,
  AUDIT_METADATA_FIELD,
  AUDIT_SOURCE_FIELD,
] as const;

export const ACTOR_ROLE_ADMIN = "admin";
export const ACTOR_ROLE_SYSTEM = "system";
export const SYSTEM_ACTOR_ID = "system";

/** Canonical product actions (NEW emissions). */
export const AUDIT_ACTION = {
  userProvision: "user_provision",
  paymentReinstate: "payment_reinstate",
  userArchive: "user_archive",
  userUnarchive: "user_unarchive",
  invoiceCreate: "invoice_create",
  migrateUserPhones: "admin_migrate_user_phones",
  migrateHalaqaSlotIds: "halaqa_schedule_slotid_migrate",
  studentLifecycleBackfill: "student_lifecycle_backfill",
  studentSearchBackfill: "student_search_backfill",
} as const;

export type AuditAction = (typeof AUDIT_ACTION)[keyof typeof AUDIT_ACTION];

/** Deferred C16.3 hooks — contract-ready, not emitted by WA-16. */
export const AUDIT_ACTION_DEFERRED = {
  paymentSuspend: "payment_suspend",
  paymentReview: "payment_review",
  adminPricingChange: "admin_pricing_change",
  adminVodafoneChange: "admin_vodafone_change",
  studentTransfer: "student_transfer",
  relationshipChildrenChange: "relationship_children_change",
  sessionCreateOrCorrect: "session_create_or_correct",
  attendanceCorrect: "attendance_correct",
  evaluationCreateOrCorrect: "evaluation_create_or_correct",
  chatMessageModerateDelete: "chat_message_moderate_delete",
} as const;

export const AUDIT_TARGET_TYPE = {
  user: "user",
  studentProfile: "studentProfile",
  paymentAccess: "paymentAccess",
  invoice: "invoice",
  migration: "migration",
} as const;

export type AuditTargetType =
  (typeof AUDIT_TARGET_TYPE)[keyof typeof AUDIT_TARGET_TYPE];

/**
 * Allowlisted metadata keys for NEW emissions. Writers may use a subset;
 * unknown keys are rejected by the builder.
 */
export const AUDIT_METADATA_ALLOWLIST = new Set([
  "previousStatus",
  "newStatus",
  "previousLifecycle",
  "newLifecycle",
  "invoiceId",
  "paymentId",
  "parentId",
  "studentId",
  "halaqaId",
  "pricingRuleId",
  "pricingRuleVersion",
  "periodKey",
  "currency",
  "amount",
  "role",
  "migratedCount",
  "updatedCount",
  "createdCount",
  "deletedCount",
  "skippedCount",
  "scanned",
  "stamped",
  "alreadySet",
  "preservedExistingPrivate",
  "halaqatUpdated",
  "slotsAssigned",
  "cursor",
  "nextCursor",
  "pageSize",
  "dryRun",
]);

/** Privacy deny-list — must never appear as metadata keys or nested content probes. */
export const AUDIT_METADATA_FORBIDDEN_KEYS = [
  "password",
  "email",
  "phone",
  "phoneNumber",
  "token",
  "fcmToken",
  "secret",
  "hmac",
  "userPrivate",
  "address",
  "nationalId",
  "proofStoragePath",
  "proofDownloadUrl",
  "proofUrl",
  "messageBody",
  "text",
  "mediaUrl",
] as const;

export type AuditActor = {
  actorId: string;
  actorRole: typeof ACTOR_ROLE_ADMIN | typeof ACTOR_ROLE_SYSTEM;
};

export type AuditLogInput = {
  actor: AuditActor;
  action: string;
  targetType: string;
  targetId: string;
  metadata?: Record<string, unknown>;
  source: string;
};

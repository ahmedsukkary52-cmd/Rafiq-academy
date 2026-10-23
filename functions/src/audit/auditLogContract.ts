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
/**
 * Scoped operational actor (freeze §4.7 payment review, admit/transfer within
 * supervised halaqat). Always derived from `users/{uid}.role` server-side.
 */
export const ACTOR_ROLE_SUPERVISOR = "supervisor";
/** Live-evaluation author (spec §20.1 `evaluation_create_or_correct`). */
export const ACTOR_ROLE_TEACHER = "teacher";
export const SYSTEM_ACTOR_ID = "system";

/** Canonical product actions (NEW emissions). */
export const AUDIT_ACTION = {
  userProvision: "user_provision",
  paymentReinstate: "payment_reinstate",
  userArchive: "user_archive",
  userUnarchive: "user_unarchive",
  invoiceCreate: "invoice_create",
  migrateHalaqaSlotIds: "halaqa_schedule_slotid_migrate",
  studentLifecycleBackfill: "student_lifecycle_backfill",
  studentSearchBackfill: "student_search_backfill",
  // PH-02 — server-authoritative workflows.
  paymentReview: "payment_review",
  studentAdmit: "student_admit",
  studentTransfer: "student_transfer",
  attendanceCorrect: "attendance_correct",
  evaluationCreateOrCorrect: "evaluation_create_or_correct",
  // P0 completion — Admin operational workflows.
  relationshipChildrenChange: "relationship_children_change",
  halaqaCreate: "halaqa_create",
  halaqaScheduleChange: "halaqa_schedule_change",
  halaqaMeetingLinkChange: "halaqa_meeting_link_change",
} as const;

export type AuditAction = (typeof AUDIT_ACTION)[keyof typeof AUDIT_ACTION];

/** Deferred C16.3 hooks — contract-ready, not emitted yet. */
export const AUDIT_ACTION_DEFERRED = {
  paymentSuspend: "payment_suspend",
  adminPricingChange: "admin_pricing_change",
  adminVodafoneChange: "admin_vodafone_change",
  sessionCreateOrCorrect: "session_create_or_correct",
  chatMessageModerateDelete: "chat_message_moderate_delete",
} as const;

export const AUDIT_TARGET_TYPE = {
  user: "user",
  studentProfile: "studentProfile",
  paymentAccess: "paymentAccess",
  invoice: "invoice",
  migration: "migration",
  payment: "payment",
  session: "session",
  halaqa: "halaqa",
  evaluation: "evaluation",
  parentProfile: "parentProfile",
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
  "updatedCount",
  "createdCount",
  "deletedCount",
  "skippedCount",
  "scanned",
  "stamped",
  "alreadySet",
  "halaqatUpdated",
  "slotsAssigned",
  "cursor",
  "nextCursor",
  "pageSize",
  "dryRun",
  "previousReviewStatus",
  "newReviewStatus",
  "decision",
  "sessionId",
  "date",
  "fromHalaqaId",
  "toHalaqaId",
  "evaluationType",
  "versesRange",
  "operation",
  "teacherId",
  "supervisorId",
  "slotId",
  "slotCount",
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
  actorRole:
    | typeof ACTOR_ROLE_ADMIN
    | typeof ACTOR_ROLE_SYSTEM
    | typeof ACTOR_ROLE_SUPERVISOR
    | typeof ACTOR_ROLE_TEACHER;
};

export type AuditLogInput = {
  actor: AuditActor;
  action: string;
  targetType: string;
  targetId: string;
  metadata?: Record<string, unknown>;
  source: string;
};

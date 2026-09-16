/**
 * WA-14 / C13 — pure projection logic for `studentSearch/{studentId}`.
 *
 * No Firebase imports: every function here is a total function over plain
 * data so the trigger stays a thin IO shell and the contract is unit-testable.
 *
 * Authorization invariant: `halaqaIds` and `visibleTo` derive EXCLUSIVELY from
 * `halaqat.studentIds`. The client-writable `studentProfiles.halaqaId` pointer
 * is display-only and can never widen who may read a student.
 */

import {
  ARABIC_NORMALIZATION_VERSION,
  normalizeArabicSearchText,
} from "./arabicNormalization";
import {
  FULL_NAME_FIELD,
  FULL_NAME_NORMALIZED_FIELD,
  HALAQA_ID_FIELD,
  HALAQA_IDS_FIELD,
  HALAQA_NAME_FIELD,
  MAX_HALAQA_MEMBERSHIPS,
  MAX_PROJECTED_HALAQA_IDS,
  MAX_PROJECTED_VISIBLE_TO,
  NORMALIZATION_VERSION_FIELD,
  sameStringList,
  sortedIdList,
  STUDENT_ID_FIELD,
  STUDENT_ROLE,
  STUDENT_SEARCH_FIELDS,
  StudentSearchProjection,
  trimmedString,
  UPDATED_AT_FIELD,
  VISIBLE_TO_FIELD,
} from "./studentSearchContract";

/** A `halaqat` document that lists the student in `studentIds`. */
export type HalaqaMembershipDoc = {
  halaqaId: string;
  name?: unknown;
  teacherId?: unknown;
  supervisorId?: unknown;
};

export type UserSource = { name?: unknown; role?: unknown } | null;
export type StudentProfileSource = { name?: unknown; halaqaId?: unknown } | null;

export type StudentSearchSources = {
  studentId: string;
  user: UserSource;
  profile: StudentProfileSource;
  /** Every halaqa whose roster contains the student (SSOT). */
  memberships: readonly HalaqaMembershipDoc[];
};

export type MembershipDerivation = {
  halaqaIds: string[];
  visibleTo: string[];
  nameByHalaqaId: Record<string, string>;
  /** True when the roster placed the student in more halaqat than the cap. */
  capExceeded: boolean;
  /** True when a defensive storage bound truncated a stored array. */
  truncated: boolean;
};

export type StudentSearchDecision =
  | { action: "noop"; studentId: string }
  | { action: "delete"; studentId: string; reason: "not_a_student" | "no_user" }
  | {
      action: "create" | "update";
      studentId: string;
      projection: StudentSearchProjection;
    };

/** Only `users.role` decides directory membership (identity SSOT, C1). */
export function isStudentUser(user: UserSource): boolean {
  return trimmedString(user?.role) === STUDENT_ROLE;
}

/**
 * Frozen name source: `users.name`, falling back to `studentProfiles.name`,
 * otherwise `""`. An empty name still projects so Admin can find and fix it.
 */
export function resolveStudentFullName(params: {
  user: UserSource;
  profile: StudentProfileSource;
}): string {
  const fromUser = trimmedString(params.user?.name);
  if (fromUser.length > 0) return fromUser;
  return trimmedString(params.profile?.name);
}

/**
 * Roster-only derivation of the scoping fields.
 *
 * `visibleTo` is the deduplicated set of teacher + supervisor uids across every
 * halaqa containing the student. Students and parents are never added, so a
 * Parent or Student query can never satisfy the Rules condition.
 */
export function deriveMembership(
  memberships: readonly HalaqaMembershipDoc[],
): MembershipDerivation {
  const nameByHalaqaId: Record<string, string> = {};
  const halaqaIdSet: string[] = [];
  const viewers: string[] = [];

  for (const halaqa of memberships) {
    const halaqaId = trimmedString(halaqa.halaqaId);
    if (halaqaId.length === 0) continue;
    halaqaIdSet.push(halaqaId);
    nameByHalaqaId[halaqaId] = trimmedString(halaqa.name);
    viewers.push(trimmedString(halaqa.teacherId));
    viewers.push(trimmedString(halaqa.supervisorId));
  }

  const allHalaqaIds = sortedIdList(halaqaIdSet);
  const allViewers = sortedIdList(viewers);

  const halaqaIds = allHalaqaIds.slice(0, MAX_PROJECTED_HALAQA_IDS);
  const visibleTo = allViewers.slice(0, MAX_PROJECTED_VISIBLE_TO);

  return {
    halaqaIds,
    visibleTo,
    nameByHalaqaId,
    capExceeded: allHalaqaIds.length > MAX_HALAQA_MEMBERSHIPS,
    truncated:
      allHalaqaIds.length > halaqaIds.length
      || allViewers.length > visibleTo.length,
  };
}

/**
 * Display pointer resolution (never authorization):
 * 1. the `studentProfiles.halaqaId` pointer when it is a real membership,
 * 2. otherwise the lowest-sorted membership — the same tie-break the existing
 *    `AcademyMembershipInvariant.primaryAfterMembershipsChanged` already uses,
 * 3. `null` when there are no memberships.
 */
export function resolvePrimaryHalaqaId(params: {
  pointer: unknown;
  halaqaIds: readonly string[];
}): string | null {
  if (params.halaqaIds.length === 0) return null;
  const pointer = trimmedString(params.pointer);
  if (pointer.length > 0 && params.halaqaIds.includes(pointer)) return pointer;
  return params.halaqaIds[0];
}

/**
 * Builds the complete projection, or `null` when the subject is not a student.
 * Every value is derived — nothing is copied from a source document — so the
 * key set is structurally pinned to [STUDENT_SEARCH_FIELDS].
 */
export function buildStudentSearchProjection(
  sources: StudentSearchSources,
): StudentSearchProjection | null {
  const studentId = trimmedString(sources.studentId);
  if (studentId.length === 0) return null;
  if (!isStudentUser(sources.user)) return null;

  const membership = deriveMembership(sources.memberships);
  const fullName = resolveStudentFullName({
    user: sources.user,
    profile: sources.profile,
  });
  const halaqaId = resolvePrimaryHalaqaId({
    pointer: sources.profile?.halaqaId,
    halaqaIds: membership.halaqaIds,
  });

  return {
    studentId,
    fullName,
    fullNameNormalized: normalizeArabicSearchText(fullName),
    halaqaId,
    // A missing halaqa document keeps the id but renders as unnamed.
    halaqaName: halaqaId === null
      ? ""
      : membership.nameByHalaqaId[halaqaId] ?? "",
    halaqaIds: membership.halaqaIds,
    visibleTo: membership.visibleTo,
    normalizationVersion: ARABIC_NORMALIZATION_VERSION,
  };
}

/** Structural equality ignoring `updatedAt` — the no-op / churn guard. */
export function projectionEquals(
  a: StudentSearchProjection | null,
  b: StudentSearchProjection | null,
): boolean {
  if (a === null || b === null) return a === b;
  return a.studentId === b.studentId
    && a.fullName === b.fullName
    && a.fullNameNormalized === b.fullNameNormalized
    && a.halaqaId === b.halaqaId
    && a.halaqaName === b.halaqaName
    && a.normalizationVersion === b.normalizationVersion
    && sameStringList(a.halaqaIds, b.halaqaIds)
    && sameStringList(a.visibleTo, b.visibleTo);
}

/** Reads a stored document back into projection shape for comparison. */
export function readStoredProjection(
  raw: Record<string, unknown> | null | undefined,
): StudentSearchProjection | null {
  if (!raw) return null;
  const studentId = trimmedString(raw.studentId);
  if (studentId.length === 0) return null;
  const halaqaId = trimmedString(raw.halaqaId);
  const version = raw.normalizationVersion;
  return {
    studentId,
    fullName: trimmedString(raw.fullName),
    fullNameNormalized: trimmedString(raw.fullNameNormalized),
    halaqaId: halaqaId.length > 0 ? halaqaId : null,
    halaqaName: trimmedString(raw.halaqaName),
    halaqaIds: sortedIdList(Array.isArray(raw.halaqaIds) ? raw.halaqaIds : []),
    visibleTo: sortedIdList(Array.isArray(raw.visibleTo) ? raw.visibleTo : []),
    normalizationVersion: typeof version === "number" ? version : -1,
  };
}

/**
 * Idempotent create / update / noop / delete decision.
 *
 * A projection is deleted only when the subject stops being a student (or the
 * user document disappears) — never merely because they lost a halaqa, since
 * an unassigned student must stay discoverable by Admin.
 */
export function decideStudentSearchWrite(params: {
  sources: StudentSearchSources;
  existing: Record<string, unknown> | null | undefined;
}): StudentSearchDecision {
  const studentId = trimmedString(params.sources.studentId);
  const next = buildStudentSearchProjection(params.sources);
  const existed = Boolean(params.existing);

  if (next === null) {
    if (!existed) return { action: "noop", studentId };
    return {
      action: "delete",
      studentId,
      reason: params.sources.user === null ? "no_user" : "not_a_student",
    };
  }

  if (!existed) return { action: "create", studentId, projection: next };

  const current = readStoredProjection(params.existing);
  if (projectionEquals(current, next)) return { action: "noop", studentId };
  return { action: "update", studentId, projection: next };
}

// ── Change-signature guards (skip fan-out on irrelevant source edits) ───────

export function userProjectionFieldsChanged(
  before: UserSource | undefined,
  after: UserSource | undefined,
): boolean {
  if (!after) return Boolean(before);
  if (!before) return true;
  return trimmedString(before.name) !== trimmedString(after.name)
    || trimmedString(before.role) !== trimmedString(after.role);
}

export function studentProfileProjectionFieldsChanged(
  before: StudentProfileSource | undefined,
  after: StudentProfileSource | undefined,
): boolean {
  if (!after) return Boolean(before);
  if (!before) return true;
  return trimmedString(before.name) !== trimmedString(after.name)
    || trimmedString(before.halaqaId) !== trimmedString(after.halaqaId);
}

export type HalaqaProjectionSource = {
  name?: unknown;
  teacherId?: unknown;
  supervisorId?: unknown;
  studentIds?: unknown;
};

function rosterOf(source: HalaqaProjectionSource | undefined): string[] {
  const raw = source?.studentIds;
  return sortedIdList(Array.isArray(raw) ? (raw as unknown[]) : []);
}

export type HalaqaChangeKind = "none" | "rename_only" | "recompute";

/**
 * Classifies a `halaqat` write against the four fields the projection reads.
 * `rename_only` is the cheap path: it changes `halaqaName` on already-correct
 * rows without re-reading `users` or `studentProfiles`.
 */
export function classifyHalaqaChange(params: {
  before: HalaqaProjectionSource | undefined;
  after: HalaqaProjectionSource | undefined;
}): HalaqaChangeKind {
  const { before, after } = params;
  if (!after) return before ? "recompute" : "none";
  if (!before) return "recompute";

  const rosterChanged = !sameStringList(rosterOf(before), rosterOf(after));
  const staffChanged =
    trimmedString(before.teacherId) !== trimmedString(after.teacherId)
    || trimmedString(before.supervisorId) !== trimmedString(after.supervisorId);
  const nameChanged =
    trimmedString(before.name) !== trimmedString(after.name);

  if (rosterChanged || staffChanged) return "recompute";
  if (nameChanged) return "rename_only";
  return "none";
}

/** Students touched by a roster change: the union of both rosters. */
export function affectedStudentIds(params: {
  before: HalaqaProjectionSource | undefined;
  after: HalaqaProjectionSource | undefined;
}): string[] {
  return sortedIdList([...rosterOf(params.before), ...rosterOf(params.after)]);
}

/**
 * The exact map persisted to Firestore, built key by key from the allowlist.
 *
 * This is the single place a projection document is shaped, so the leakage
 * test can assert the real persisted key set rather than an approximation.
 * `updatedAt` is injected (a server timestamp at runtime) so the builder stays
 * pure and comparable in tests.
 */
export function buildStudentSearchDocument<T>(
  projection: StudentSearchProjection,
  updatedAt: T,
): Record<string, unknown> {
  return {
    [STUDENT_ID_FIELD]: projection.studentId,
    [FULL_NAME_FIELD]: projection.fullName,
    [FULL_NAME_NORMALIZED_FIELD]: projection.fullNameNormalized,
    [HALAQA_ID_FIELD]: projection.halaqaId,
    [HALAQA_NAME_FIELD]: projection.halaqaName,
    [HALAQA_IDS_FIELD]: projection.halaqaIds,
    [VISIBLE_TO_FIELD]: projection.visibleTo,
    [NORMALIZATION_VERSION_FIELD]: projection.normalizationVersion,
    [UPDATED_AT_FIELD]: updatedAt,
  };
}

export const STUDENT_SEARCH_PERSISTED_KEYS = [...STUDENT_SEARCH_FIELDS].sort();

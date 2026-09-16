/**
 * WA-14 / C13 — frozen `studentSearch/{studentId}` projection contract.
 *
 * The projection is a SAFE directory view: it carries stable identifiers and
 * display text only. It is CF-owned (Rules deny every client write) and is
 * built from [STUDENT_SEARCH_FIELDS] by explicit allowlist, so a new field
 * appearing on `users`, `studentProfiles` or `halaqat` can never propagate.
 */

export const STUDENT_SEARCH_COLLECTION = "studentSearch";
export const USERS_COLLECTION = "users";
export const STUDENT_PROFILES_COLLECTION = "studentProfiles";
export const HALAQAT_COLLECTION = "halaqat";

export const STUDENT_ROLE = "student";

export const STUDENT_ID_FIELD = "studentId";
export const FULL_NAME_FIELD = "fullName";
export const FULL_NAME_NORMALIZED_FIELD = "fullNameNormalized";
export const HALAQA_ID_FIELD = "halaqaId";
export const HALAQA_NAME_FIELD = "halaqaName";
export const HALAQA_IDS_FIELD = "halaqaIds";
export const VISIBLE_TO_FIELD = "visibleTo";
export const UPDATED_AT_FIELD = "updatedAt";
export const NORMALIZATION_VERSION_FIELD = "normalizationVersion";

/** The complete, frozen key set of a projection document. */
export const STUDENT_SEARCH_FIELDS = [
  STUDENT_ID_FIELD,
  FULL_NAME_FIELD,
  FULL_NAME_NORMALIZED_FIELD,
  HALAQA_ID_FIELD,
  HALAQA_NAME_FIELD,
  HALAQA_IDS_FIELD,
  VISIBLE_TO_FIELD,
  UPDATED_AT_FIELD,
  NORMALIZATION_VERSION_FIELD,
] as const;

/**
 * Never projected. Phone/private contact is D16; status dimensions belong to
 * WA-15. Listed explicitly so the guard test reads as a contract, not a hint.
 */
export const STUDENT_SEARCH_FORBIDDEN_FIELDS = [
  "phone",
  "phoneNumber",
  "email",
  "address",
  "dateOfBirth",
  "dob",
  "birthYear",
  "nationalId",
  "parentId",
  "parentIds",
  "parentName",
  "parentPhone",
  "guardianName",
  "guardianPhone",
  "payment",
  "paymentStatus",
  "paymentAccess",
  "notes",
  "isActive",
  "lifecycle",
  "role",
] as const;

/** Normal product invariant (AcademyMembershipInvariant.maxHalaqatPerStudent). */
export const MAX_HALAQA_MEMBERSHIPS = 2;

/**
 * Defensive storage bounds. The live Supervisor admission path writes
 * `halaqat.studentIds` without the cap check, so a corrupt roster must not be
 * able to grow an unbounded array on a broadly readable document.
 */
export const MAX_PROJECTED_HALAQA_IDS = 10;
export const MAX_PROJECTED_VISIBLE_TO = 20;

/** Sentinel appended to a prefix to build a Firestore `<=` range bound. */
export const PREFIX_RANGE_SUFFIX = "\uf8ff";

export type StudentSearchProjection = {
  studentId: string;
  fullName: string;
  fullNameNormalized: string;
  halaqaId: string | null;
  halaqaName: string;
  halaqaIds: string[];
  visibleTo: string[];
  normalizationVersion: number;
};

export function trimmedString(raw: unknown): string {
  return typeof raw === "string" ? raw.trim() : "";
}

/** Deduplicated, trimmed, sorted id list — deterministic across runs. */
export function sortedIdList(raw: Iterable<unknown>): string[] {
  const seen = new Set<string>();
  for (const entry of raw) {
    const id = trimmedString(entry);
    if (id.length > 0) seen.add(id);
  }
  return [...seen].sort();
}

export function sameStringList(
  a: readonly string[],
  b: readonly string[],
): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

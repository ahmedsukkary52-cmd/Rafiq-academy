/**
 * WA-11 / D14 — pure 1:1 chat relationship authorization helpers.
 *
 * Role-pair filters alone are NOT sufficient. Relationship graph must hold.
 * Parent is never authorized as a Halaqa group member (WA-10); this module
 * covers direct 1:1 only.
 */

export type ChatRole =
  | "student"
  | "parent"
  | "teacher"
  | "supervisor"
  | "admin";

export const DIRECT_CHAT_KIND = "direct";

/** C9 — sender edit window (IMPLEMENTATION-DEFINED BUT SAFE). */
export const MESSAGE_EDIT_WINDOW_MS = 15 * 60 * 1000;

export function isChatRole(raw: unknown): raw is ChatRole {
  return (
    raw === "student"
    || raw === "parent"
    || raw === "teacher"
    || raw === "supervisor"
    || raw === "admin"
  );
}

export function directConversationId(uidA: string, uidB: string): string {
  const a = uidA.trim();
  const b = uidB.trim();
  if (!a || !b) throw new Error("both uids are required");
  if (a === b) throw new Error("cannot create conversation with self");
  return [a, b].sort().join("_");
}

/**
 * Role-pair gate (necessary but not sufficient).
 * Mirrors product-facing allowed pairs; graph checks still required.
 */
export function rolesMayDirectChat(roleA: ChatRole, roleB: ChatRole): boolean {
  const pairs: Record<ChatRole, ReadonlySet<ChatRole>> = {
    student: new Set(["teacher", "supervisor"]),
    parent: new Set(["teacher", "supervisor", "admin"]),
    teacher: new Set(["student", "parent", "supervisor", "admin"]),
    supervisor: new Set(["student", "parent", "teacher", "admin"]),
    admin: new Set(["parent", "teacher", "supervisor"]),
  };
  return pairs[roleA]?.has(roleB) === true;
}

export type HalaqaRow = {
  id: string;
  teacherId: string;
  supervisorId: string;
  studentIds: string[];
};

export type RelationshipContext = {
  /** Halaqat where student appears in studentIds. */
  studentHalaqat: HalaqaRow[];
  /** Halaqat where teacherId matches. */
  teacherHalaqat: HalaqaRow[];
  /** Halaqat where supervisorId matches. */
  supervisorHalaqat: HalaqaRow[];
  /** parentProfiles.childrenIds for parent. */
  parentChildrenIds: string[];
};

function normalizeIds(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const e of raw) {
    if (typeof e !== "string") continue;
    const id = e.trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

export function parseHalaqaRow(
  id: string,
  data: Record<string, unknown>,
): HalaqaRow {
  return {
    id,
    teacherId:
      typeof data.teacherId === "string" ? data.teacherId.trim() : "",
    supervisorId:
      typeof data.supervisorId === "string" ? data.supervisorId.trim() : "",
    studentIds: normalizeIds(data.studentIds),
  };
}

function studentInHalaqa(h: HalaqaRow, studentId: string): boolean {
  return h.studentIds.includes(studentId);
}

/**
 * Authoritative D14 relationship check (pure).
 * Returns true only when roles are allowed AND graph evidence exists.
 */
export function isDirectChatRelationshipAllowed(params: {
  roleA: ChatRole;
  uidA: string;
  roleB: ChatRole;
  uidB: string;
  ctxA: RelationshipContext;
  ctxB: RelationshipContext;
}): boolean {
  const { roleA, uidA, roleB, uidB, ctxA, ctxB } = params;
  if (!rolesMayDirectChat(roleA, roleB)) return false;

  const ordered = (r1: ChatRole, r2: ChatRole) =>
    roleA === r1 && roleB === r2;

  // Student ↔ Teacher (own halaqa)
  if (ordered("student", "teacher") || ordered("teacher", "student")) {
    const studentId = roleA === "student" ? uidA : uidB;
    const teacherId = roleA === "teacher" ? uidA : uidB;
    const studentCtx = roleA === "student" ? ctxA : ctxB;
    return studentCtx.studentHalaqat.some(
      (h) => h.teacherId === teacherId && studentInHalaqa(h, studentId),
    );
  }

  // Student ↔ Supervisor (own halaqa)
  if (ordered("student", "supervisor") || ordered("supervisor", "student")) {
    const studentId = roleA === "student" ? uidA : uidB;
    const supervisorId = roleA === "supervisor" ? uidA : uidB;
    const studentCtx = roleA === "student" ? ctxA : ctxB;
    return studentCtx.studentHalaqat.some(
      (h) =>
        h.supervisorId === supervisorId && studentInHalaqa(h, studentId),
    );
  }

  // Parent ↔ Teacher (linked child's teacher)
  if (ordered("parent", "teacher") || ordered("teacher", "parent")) {
    const parentCtx = roleA === "parent" ? ctxA : ctxB;
    const teacherId = roleA === "teacher" ? uidA : uidB;
    const teacherCtx = roleA === "teacher" ? ctxA : ctxB;
    if (parentCtx.parentChildrenIds.length === 0) return false;
    return teacherCtx.teacherHalaqat.some((h) =>
      h.teacherId === teacherId
      && parentCtx.parentChildrenIds.some((c) => studentInHalaqa(h, c)),
    );
  }

  // Parent ↔ Supervisor
  if (ordered("parent", "supervisor") || ordered("supervisor", "parent")) {
    const parentCtx = roleA === "parent" ? ctxA : ctxB;
    const supervisorId = roleA === "supervisor" ? uidA : uidB;
    const supervisorCtx = roleA === "supervisor" ? ctxA : ctxB;
    if (parentCtx.parentChildrenIds.length === 0) return false;
    return supervisorCtx.supervisorHalaqat.some(
      (h) =>
        h.supervisorId === supervisorId
        && parentCtx.parentChildrenIds.some((c) => studentInHalaqa(h, c)),
    );
  }

  // Parent ↔ Admin (academy parent may contact management)
  if (ordered("parent", "admin") || ordered("admin", "parent")) {
    return true;
  }

  // Teacher ↔ Supervisor (shared halaqa)
  if (ordered("teacher", "supervisor") || ordered("supervisor", "teacher")) {
    const teacherId = roleA === "teacher" ? uidA : uidB;
    const supervisorId = roleA === "supervisor" ? uidA : uidB;
    const teacherCtx = roleA === "teacher" ? ctxA : ctxB;
    return teacherCtx.teacherHalaqat.some(
      (h) => h.teacherId === teacherId && h.supervisorId === supervisorId,
    );
  }

  // Teacher ↔ Admin / Supervisor ↔ Admin
  if (
    ordered("teacher", "admin")
    || ordered("admin", "teacher")
    || ordered("supervisor", "admin")
    || ordered("admin", "supervisor")
  ) {
    return true;
  }

  return false;
}

export function softDeletePayload(params: {
  deletedBy: string;
  now?: Date;
}): {
  deleted: true;
  deletedAt: Date;
  deletedBy: string;
  text: string;
} {
  return {
    deleted: true,
    deletedAt: params.now ?? new Date(),
    deletedBy: params.deletedBy.trim(),
    text: "",
  };
}

export function canEditMessage(params: {
  senderId: string;
  callerUid: string;
  sentAt: Date;
  now?: Date;
  alreadyDeleted?: boolean;
}): boolean {
  if (params.alreadyDeleted) return false;
  if (params.senderId.trim() !== params.callerUid.trim()) return false;
  const now = params.now ?? new Date();
  return now.getTime() - params.sentAt.getTime() <= MESSAGE_EDIT_WINDOW_MS;
}

/** Sender "delete for everyone" window; Admin moderation has no window. */
export const MESSAGE_DELETE_WINDOW_MS = 60 * 60 * 1000;

export function canSoftDeleteMessage(params: {
  senderId: string;
  callerUid: string;
  callerRole: ChatRole;
  alreadyDeleted?: boolean;
  sentAt?: Date;
  now?: Date;
}): boolean {
  if (params.alreadyDeleted) return false;
  if (params.callerRole === "admin") return true;
  if (params.senderId.trim() !== params.callerUid.trim()) return false;
  if (!params.sentAt) return true;
  const now = params.now ?? new Date();
  return now.getTime() - params.sentAt.getTime() <= MESSAGE_DELETE_WINDOW_MS;
}

/** Empty relationship context for tests / missing users. */
export function emptyRelationshipContext(): RelationshipContext {
  return {
    studentHalaqat: [],
    teacherHalaqat: [],
    supervisorHalaqat: [],
    parentChildrenIds: [],
  };
}

/**
 * WA-10 / C8 — pure Halaqa group conversation identity + membership projection.
 *
 * Group id: halaqa_group_{halaqaId}
 * Members: teacher + supervisor? + students (deduped).
 * Parent and Admin are never projected as members.
 */

export const HALAQA_GROUP_KIND = "halaqa_group";
export const HALAQA_GROUP_ID_PREFIX = "halaqa_group_";

export type HalaqaMembershipSource = {
  teacherId?: unknown;
  supervisorId?: unknown;
  studentIds?: unknown;
  name?: unknown;
  status?: unknown;
};

export type GroupParticipantStub = {
  uid: string;
  role: "teacher" | "supervisor" | "student";
  name: string;
};

export type ExistingGroupConversation = {
  kind?: unknown;
  halaqaId?: unknown;
  participantIds?: unknown;
  participants?: unknown;
  lastMessage?: unknown;
  lastMessageAt?: unknown;
  lastMessageSenderId?: unknown;
  unreadCounts?: unknown;
  createdAt?: unknown;
  createdBy?: unknown;
};

export type GroupSyncDecision =
  | {
      action: "create";
      conversationId: string;
      halaqaId: string;
      participantIds: string[];
      participants: GroupParticipantStub[];
      title: string;
    }
  | {
      action: "update";
      conversationId: string;
      halaqaId: string;
      participantIds: string[];
      participants: GroupParticipantStub[];
      title: string;
      /** Preserve historical message metadata and createdAt. */
      preserve: {
        lastMessage?: unknown;
        lastMessageAt?: unknown;
        lastMessageSenderId?: unknown;
        unreadCounts: Record<string, unknown>;
        createdAt?: unknown;
        createdBy?: unknown;
      };
      membershipChanged: boolean;
    }
  | {
      action: "noop";
      conversationId: string;
      participantIds: string[];
    };

function requireNonEmptyString(raw: unknown, field: string): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new Error(`${field} is required`);
  }
  return raw.trim();
}

function optionalNonEmptyString(raw: unknown): string | undefined {
  if (typeof raw !== "string") return undefined;
  const t = raw.trim();
  return t.length > 0 ? t : undefined;
}

export function normalizeIdList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const entry of raw) {
    if (typeof entry !== "string") continue;
    const id = entry.trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

/** Deterministic conversation document id (C8). */
export function halaqaGroupConversationId(halaqaId: string): string {
  const id = requireNonEmptyString(halaqaId, "halaqaId");
  return `${HALAQA_GROUP_ID_PREFIX}${id}`;
}

export function isHalaqaGroupConversationId(conversationId: string): boolean {
  return conversationId.startsWith(HALAQA_GROUP_ID_PREFIX)
    && conversationId.length > HALAQA_GROUP_ID_PREFIX.length;
}

export function halaqaIdFromGroupConversationId(
  conversationId: string,
): string | null {
  if (!isHalaqaGroupConversationId(conversationId)) return null;
  return conversationId.slice(HALAQA_GROUP_ID_PREFIX.length);
}

/**
 * Authoritative membership projection from Halaqa fields.
 * Never includes Parent or Admin. Deduplicates; teacher wins role if also listed as student.
 */
export function buildHalaqaGroupMembership(
  source: HalaqaMembershipSource,
): { participantIds: string[]; participants: GroupParticipantStub[] } {
  const teacherId = optionalNonEmptyString(source.teacherId);
  const supervisorId = optionalNonEmptyString(source.supervisorId);
  const studentIds = normalizeIdList(source.studentIds);

  const roleByUid = new Map<string, GroupParticipantStub["role"]>();

  for (const sid of studentIds) {
    roleByUid.set(sid, "student");
  }
  if (supervisorId) {
    roleByUid.set(supervisorId, "supervisor");
  }
  if (teacherId) {
    roleByUid.set(teacherId, "teacher");
  }

  const participants: GroupParticipantStub[] = [];
  for (const [uid, role] of roleByUid) {
    participants.push({ uid, role, name: "" });
  }
  // Stable order: teacher, supervisor, then students sorted.
  participants.sort((a, b) => {
    const rank = (r: GroupParticipantStub["role"]) =>
      r === "teacher" ? 0 : r === "supervisor" ? 1 : 2;
    const byRole = rank(a.role) - rank(b.role);
    if (byRole !== 0) return byRole;
    return a.uid.localeCompare(b.uid);
  });

  return {
    participantIds: participants.map((p) => p.uid),
    participants,
  };
}

export function sameStringSet(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) return false;
  const setB = new Set(b);
  for (const x of a) {
    if (!setB.has(x)) return false;
  }
  return true;
}

/** True when teacher/supervisor/studentIds (membership SSOT) changed. */
export function halaqaMembershipFieldsChanged(
  before: HalaqaMembershipSource | null | undefined,
  after: HalaqaMembershipSource | null | undefined,
): boolean {
  if (!after) return Boolean(before);
  if (!before) return true;
  const bTeacher = optionalNonEmptyString(before.teacherId) ?? "";
  const aTeacher = optionalNonEmptyString(after.teacherId) ?? "";
  const bSv = optionalNonEmptyString(before.supervisorId) ?? "";
  const aSv = optionalNonEmptyString(after.supervisorId) ?? "";
  if (bTeacher !== aTeacher || bSv !== aSv) return true;
  return !sameStringSet(
    normalizeIdList(before.studentIds),
    normalizeIdList(after.studentIds),
  );
}

function pruneUnreadCounts(
  raw: unknown,
  participantIds: readonly string[],
): Record<string, unknown> {
  const allowed = new Set(participantIds);
  const out: Record<string, unknown> = {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    for (const id of participantIds) out[id] = 0;
    return out;
  }
  const map = raw as Record<string, unknown>;
  for (const id of participantIds) {
    out[id] = typeof map[id] === "number" ? map[id] : 0;
  }
  // Drop unread keys for removed members (do not keep stale member keys).
  for (const key of Object.keys(map)) {
    if (!allowed.has(key)) {
      // intentionally omitted
    }
  }
  return out;
}

export function groupTitleFromHalaqa(source: HalaqaMembershipSource): string {
  const name = optionalNonEmptyString(source.name);
  return name ? `مجموعة ${name}` : "مجموعة الحلقة";
}

/**
 * Idempotent create/update/noop decision for conversations/{halaqa_group_*}.
 * Does not delete the conversation; replaces membership projection only.
 */
export function decideHalaqaGroupSync(params: {
  halaqaId: string;
  halaqa: HalaqaMembershipSource;
  existing: ExistingGroupConversation | null;
}): GroupSyncDecision {
  const halaqaId = requireNonEmptyString(params.halaqaId, "halaqaId");
  const conversationId = halaqaGroupConversationId(halaqaId);
  const membership = buildHalaqaGroupMembership(params.halaqa);
  const title = groupTitleFromHalaqa(params.halaqa);

  if (!params.existing) {
    return {
      action: "create",
      conversationId,
      halaqaId,
      participantIds: membership.participantIds,
      participants: membership.participants,
      title,
    };
  }

  const existingIds = normalizeIdList(params.existing.participantIds);
  const membershipChanged = !sameStringSet(
    existingIds,
    membership.participantIds,
  );

  if (
    !membershipChanged
    && params.existing.kind === HALAQA_GROUP_KIND
    && params.existing.halaqaId === halaqaId
  ) {
    return {
      action: "noop",
      conversationId,
      participantIds: membership.participantIds,
    };
  }

  return {
    action: "update",
    conversationId,
    halaqaId,
    participantIds: membership.participantIds,
    participants: membership.participants,
    title,
    membershipChanged,
    preserve: {
      lastMessage: params.existing.lastMessage,
      lastMessageAt: params.existing.lastMessageAt,
      lastMessageSenderId: params.existing.lastMessageSenderId,
      unreadCounts: pruneUnreadCounts(
        params.existing.unreadCounts,
        membership.participantIds,
      ),
      createdAt: params.existing.createdAt,
      createdBy: params.existing.createdBy,
    },
  };
}

/**
 * In-memory sync gate for concurrency tests (transaction analog per conversation).
 */
export async function syncHalaqaGroupInMemory(params: {
  store: Map<string, ExistingGroupConversation & { id: string }>;
  locks: Map<string, Promise<void>>;
  halaqaId: string;
  halaqa: HalaqaMembershipSource;
  createdBy?: string;
}): Promise<{
  conversationId: string;
  action: "create" | "update" | "noop";
  participantIds: string[];
}> {
  const conversationId = halaqaGroupConversationId(params.halaqaId);
  const prev = params.locks.get(conversationId) ?? Promise.resolve();
  let release!: () => void;
  const gate = new Promise<void>((r) => {
    release = r;
  });
  params.locks.set(conversationId, prev.then(() => gate));
  await prev;
  try {
    const existing = params.store.get(conversationId) ?? null;
    const decision = decideHalaqaGroupSync({
      halaqaId: params.halaqaId,
      halaqa: params.halaqa,
      existing,
    });
    if (decision.action === "noop") {
      return {
        conversationId,
        action: "noop",
        participantIds: decision.participantIds,
      };
    }
    if (decision.action === "create") {
      params.store.set(conversationId, {
        id: conversationId,
        kind: HALAQA_GROUP_KIND,
        halaqaId: decision.halaqaId,
        participantIds: decision.participantIds,
        participants: decision.participants,
        unreadCounts: Object.fromEntries(
          decision.participantIds.map((id) => [id, 0]),
        ),
        createdBy: params.createdBy ?? "system",
      });
      return {
        conversationId,
        action: "create",
        participantIds: decision.participantIds,
      };
    }
    const prevDoc = params.store.get(conversationId)!;
    params.store.set(conversationId, {
      ...prevDoc,
      kind: HALAQA_GROUP_KIND,
      halaqaId: decision.halaqaId,
      participantIds: decision.participantIds,
      participants: decision.participants,
      unreadCounts: decision.preserve.unreadCounts,
      lastMessage: decision.preserve.lastMessage,
      lastMessageAt: decision.preserve.lastMessageAt,
      lastMessageSenderId: decision.preserve.lastMessageSenderId,
      createdAt: decision.preserve.createdAt,
      createdBy: decision.preserve.createdBy,
    });
    return {
      conversationId,
      action: "update",
      participantIds: decision.participantIds,
    };
  } finally {
    release();
  }
}

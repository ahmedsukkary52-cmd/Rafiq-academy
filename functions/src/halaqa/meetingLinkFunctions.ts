/**
 * B14 — per-Halaqa meeting link.
 *
 * Canonical storage is `halaqaMeetingLinks/{halaqaId}` =
 * `{ meetingLink, updatedAt }`; no link means no document. During the
 * compatibility phase every change is also mirrored to the legacy
 * `halaqat/{halaqaId}.meetingLink` field (`""` when cleared) in the same
 * transaction, so clients that still read the halaqa keep working.
 *
 * `validateMeetingLink` is the single authoritative URL policy; it is used by
 * `adminCreateHalaqa` and `setHalaqaMeetingLink`, and mirrored by the client
 * in `lib/shared/domain/meeting_link_policy.dart`.
 *
 * Authority (role SSOT `users/{uid}.role`, never request data):
 * - admin: set, update or explicitly clear the link of any Halaqa;
 * - supervisor: only where `halaqat.supervisorId == caller`, and only to add a
 *   link while none is stored in either place (update/clear by a supervisor
 *   is not approved);
 * - everyone else: denied. Clients cannot write `meetingLink` (firestore.rules).
 *
 * Link values never appear in error messages, error details or audit metadata.
 */

import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  AUDIT_ACTION,
  AUDIT_LOGS_COLLECTION,
  AUDIT_TARGET_TYPE,
} from "../audit/auditLogContract";
import { actorForCallerRole, buildAuditLogEntry } from "../audit/auditLogWrite";
import {
  loadCallerRole,
  requireCallerUid,
  requireText,
} from "../authority/callerContext";
import {
  CONTACT_INFO_REJECTION_MESSAGE,
  detectContactInfo,
} from "../privacy/contactInfoPolicy";
import { assertBackendAllowed } from "../productionGate";

export const MAX_MEETING_LINK_LENGTH = 500;

export const HALAQA_MEETING_LINKS_COLLECTION = "halaqaMeetingLinks";

/** The complete canonical document for [link] (already validated). */
export function canonicalMeetingLinkData(link: string): {
  meetingLink: string;
  updatedAt: FieldValue;
} {
  return { meetingLink: link, updatedAt: FieldValue.serverTimestamp() };
}

export type MeetingLinkIssue =
  | "empty"
  | "too_long"
  | "whitespace"
  | "unsupported_characters"
  | "not_https"
  | "credentials"
  | "invalid_host"
  | "malformed"
  | "contact_info";

export const MEETING_LINK_MESSAGES: Readonly<Record<MeetingLinkIssue, string>> =
  Object.freeze({
    empty: "أدخل رابط الاجتماع، أو استخدم «حذف الرابط» لإزالته",
    too_long: "رابط الاجتماع أطول من المسموح (500 حرف)",
    whitespace: "رابط الاجتماع يحتوي على مسافات أو رموز تحكم غير مسموحة",
    unsupported_characters:
      "رابط الاجتماع يحتوي على رموز غير مدعومة؛ انسخ الرابط كما هو من تطبيق الاجتماع",
    not_https: "رابط الاجتماع يجب أن يبدأ بـ https://",
    credentials: "رابط الاجتماع يجب ألا يحتوي على اسم مستخدم أو كلمة مرور",
    invalid_host: "عنوان موقع الاجتماع في الرابط غير صالح",
    malformed: "رابط الاجتماع غير صالح",
    contact_info: CONTACT_INFO_REJECTION_MESSAGE,
  });

const WHITESPACE_OR_CONTROL =
  /[\s\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028\u2029\u202a-\u202e\u2066-\u2069\ufeff]/;
const PRINTABLE_ASCII = /^[\x21-\x7e]+$/;
const HTTPS_PREFIX = /^https:\/\//i;
const HOST_LABEL = /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;
const PORT = /^\d{1,5}$/;

function hostIssue(authority: string): MeetingLinkIssue | null {
  if (authority.includes("@")) return "credentials";
  const colon = authority.lastIndexOf(":");
  const host = (colon >= 0 ? authority.slice(0, colon) : authority).toLowerCase();
  if (colon >= 0) {
    const port = authority.slice(colon + 1);
    if (!PORT.test(port) || Number(port) < 1 || Number(port) > 65535) {
      return "invalid_host";
    }
  }
  if (host.length === 0 || host.length > 253) return "invalid_host";
  const labels = host.split(".");
  if (labels.length < 2 || !labels.every((l) => HOST_LABEL.test(l))) {
    return "invalid_host";
  }
  return null;
}

/**
 * First policy issue of [raw] or null when it is an acceptable link.
 * Only outer whitespace is trimmed; nothing is ever prefixed or rewritten.
 */
export function meetingLinkIssue(raw: unknown): MeetingLinkIssue | null {
  if (typeof raw !== "string") return "malformed";
  const value = raw.trim();
  if (value.length === 0) return "empty";
  if (value.length > MAX_MEETING_LINK_LENGTH) return "too_long";
  if (WHITESPACE_OR_CONTROL.test(value)) return "whitespace";
  if (!PRINTABLE_ASCII.test(value)) return "unsupported_characters";
  if (!HTTPS_PREFIX.test(value)) return "not_https";
  if (value.includes("\\")) return "malformed";

  const afterScheme = value.slice("https://".length);
  const end = afterScheme.search(/[/?#]/);
  const authority = end < 0 ? afterScheme : afterScheme.slice(0, end);
  const rest = end < 0 ? "" : afterScheme.slice(end);
  const host = hostIssue(authority);
  if (host) return host;

  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return "malformed";
  }
  if (parsed.protocol !== "https:") return "not_https";
  if (parsed.username !== "" || parsed.password !== "") return "credentials";

  // WhatsApp / tel links anywhere; phone-number digit runs only outside the
  // host, so a provider host containing digits is never rejected for them.
  const anywhere = detectContactInfo(value);
  if (anywhere === "whatsapp_link" || anywhere === "phone_link") {
    return "contact_info";
  }
  if (detectContactInfo(rest) !== null) return "contact_info";
  return null;
}

/** Returns the trimmed link or throws a value-free `invalid-argument`. */
export function validateMeetingLink(raw: unknown): string {
  const issue = meetingLinkIssue(raw);
  if (issue) {
    throw new HttpsError("invalid-argument", MEETING_LINK_MESSAGES[issue], {
      code: "meeting_link_invalid",
      reason: issue,
    });
  }
  return (raw as string).trim();
}

/** Create-time variant: missing or blank means "no link". */
export function optionalMeetingLink(raw: unknown): string {
  if (raw == null) return "";
  if (typeof raw === "string" && raw.trim().length === 0) return "";
  return validateMeetingLink(raw);
}

export type MeetingLinkOperation = "set" | "update" | "clear" | "unchanged";

export type SetMeetingLinkResult = {
  halaqaId: string;
  operation: MeetingLinkOperation;
};

const AUDIT_OPERATION: Readonly<Record<Exclude<MeetingLinkOperation, "unchanged">, string>> =
  Object.freeze({
    set: "meeting_link_set",
    update: "meeting_link_update",
    clear: "meeting_link_clear",
  });

const DENIED_MESSAGE = "إدارة رابط الاجتماع متاحة للمسؤول ولمشرف هذه الحلقة فقط";
const SUPERVISOR_ADD_ONLY_MESSAGE =
  "يمكن للمشرف إضافة رابط فقط عندما لا يوجد رابط؛ تعديل الرابط الحالي أو حذفه متاح للمسؤول";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function parseRequest(data: Record<string, unknown>): {
  halaqaId: string;
  clear: boolean;
  link: string;
} {
  const halaqaId = requireText(data.halaqaId, "halaqaId", 128);
  if (halaqaId.includes("/") || halaqaId === "." || halaqaId === ".." || /^__.*__$/.test(halaqaId)) {
    throw new HttpsError("invalid-argument", "halaqaId غير صالح");
  }
  if (data.clear != null && typeof data.clear !== "boolean") {
    throw new HttpsError("invalid-argument", "قيمة الحذف غير صالحة");
  }
  const clear = data.clear === true;
  if (clear) {
    if (data.meetingLink != null) {
      throw new HttpsError("invalid-argument", "لا يمكن إرسال رابط مع طلب الحذف");
    }
    return { halaqaId, clear, link: "" };
  }
  return { halaqaId, clear, link: validateMeetingLink(data.meetingLink) };
}

/** What is stored for one Halaqa across the canonical doc and legacy field. */
export type StoredMeetingLink = {
  canonicalExists: boolean;
  /** Trimmed canonical value; `""` when missing, empty or not a string. */
  canonical: string;
  /** Trimmed legacy `halaqat.meetingLink`; `""` when missing or not a string. */
  legacy: string;
};

export function resolveStoredMeetingLink(
  canonicalDoc: Record<string, unknown> | undefined,
  halaqa: Record<string, unknown>,
): StoredMeetingLink {
  return {
    canonicalExists: canonicalDoc !== undefined,
    canonical: canonicalDoc === undefined ? "" : text(canonicalDoc.meetingLink),
    legacy: text(halaqa.meetingLink),
  };
}

/**
 * The canonical doc is authoritative whenever it exists; the legacy field is
 * only consulted when it does not. A request is `unchanged` only when both
 * stores already hold the requested state; otherwise the change rewrites both,
 * which also repairs a legacy mirror that disagrees with the canonical doc.
 */
export function classifyMeetingLinkChange(
  stored: StoredMeetingLink,
  request: { clear: boolean; link: string },
): MeetingLinkOperation {
  const anythingStored = stored.canonicalExists || stored.legacy !== "";
  if (request.clear) return anythingStored ? "clear" : "unchanged";
  if (
    stored.canonicalExists &&
    stored.canonical === request.link &&
    stored.legacy === request.link
  ) {
    return "unchanged";
  }
  return anythingStored ? "update" : "set";
}

/**
 * Sets, updates or clears one Halaqa's meeting link. The canonical doc, the
 * legacy mirror (only `meetingLink` and `updatedAt` on the halaqa) and the
 * audit entry are written in one transaction.
 */
export async function setHalaqaMeetingLinkCore(
  db: admin.firestore.Firestore,
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<SetMeetingLinkResult> {
  const uid = requireCallerUid(callerUid);
  const request = parseRequest(data);
  const role = await loadCallerRole(db, uid);
  if (role !== "admin" && role !== "supervisor") {
    throw new HttpsError("permission-denied", DENIED_MESSAGE);
  }
  const halaqaRef = db.collection("halaqat").doc(request.halaqaId);
  const linkRef = db.collection(HALAQA_MEETING_LINKS_COLLECTION).doc(request.halaqaId);

  return db.runTransaction(async (tx) => {
    const [snap, linkSnap] = await tx.getAll(halaqaRef, linkRef);
    if (!snap.exists) {
      if (role === "admin") throw new HttpsError("not-found", "الحلقة غير موجودة");
      throw new HttpsError("permission-denied", DENIED_MESSAGE);
    }
    const halaqa = snap.data() ?? {};
    if (role === "supervisor" && text(halaqa.supervisorId) !== uid) {
      throw new HttpsError("permission-denied", DENIED_MESSAGE);
    }

    const stored = resolveStoredMeetingLink(
      linkSnap.exists ? linkSnap.data() ?? {} : undefined,
      halaqa,
    );
    const operation = classifyMeetingLinkChange(stored, request);
    if (role === "supervisor" && (operation === "update" || operation === "clear")) {
      throw new HttpsError("permission-denied", SUPERVISOR_ADD_ONLY_MESSAGE);
    }
    if (operation === "unchanged") {
      return { halaqaId: halaqaRef.id, operation };
    }

    if (operation === "clear") {
      tx.delete(linkRef);
    } else {
      tx.set(linkRef, canonicalMeetingLinkData(request.link));
    }
    // Legacy mirror, kept until the client cutover and strip phases ship.
    tx.update(halaqaRef, {
      meetingLink: request.link,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection(AUDIT_LOGS_COLLECTION).doc(),
      buildAuditLogEntry(
        {
          actor: actorForCallerRole(uid, role),
          action: AUDIT_ACTION.halaqaMeetingLinkChange,
          targetType: AUDIT_TARGET_TYPE.halaqa,
          targetId: halaqaRef.id,
          metadata: { halaqaId: halaqaRef.id, operation: AUDIT_OPERATION[operation] },
          source: "setHalaqaMeetingLink",
        },
        FieldValue.serverTimestamp(),
      ),
    );
    return { halaqaId: halaqaRef.id, operation };
  });
}

export const setHalaqaMeetingLink = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("setHalaqaMeetingLink");
    return setHalaqaMeetingLinkCore(
      admin.firestore(),
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

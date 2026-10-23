/**
 * Server-authoritative payment proof submission (proof-cycle identity).
 *
 * The Parent uploads the receipt image to
 * `payment_proofs/{parentUid}/{paymentId}/{fileName}` (storage.rules: create
 * only, never overwritten or deleted by clients), then calls this callable.
 * Clients cannot write `payments/{id}` (firestore.rules), so a proof becomes
 * the current, reviewable one only here, after the server checked:
 *   - the caller is the active Parent who owns the payment (and the invoiced
 *     student is linked to them), and the invoice is not paid;
 *   - the object exists under that exact path with an allowed image type and
 *     size;
 *   - the file name was never used by this payment before (current name and
 *     the server-written `proofFileNameHistory`), and the object was created
 *     after the current proof cycle started — an older object (including one
 *     used before the history existed) can never become a new cycle.
 *
 * Every accepted submission gets a fresh server-random `proofCycleId`;
 * `reviewPaymentProof` binds a review to it. Confirmed amounts and the prior
 * review outcome are never touched here.
 *
 * Retrying the same submission after a lost response returns the cycle it
 * already established (`replayed: true`) instead of opening another one —
 * also after that cycle was reviewed (rejected, partial or approved), so a
 * receipt is never reviewed twice. "Same submission" means the current proof
 * is this exact object (path + Storage generation), submitted by this Parent
 * under a server-issued cycle; a matching file name alone never qualifies.
 */

import { randomBytes } from "node:crypto";

import * as admin from "firebase-admin";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { loadCallerRole, requireCallerUid, requireText, stringList } from "../authority/callerContext";
import { assertBackendAllowed } from "../productionGate";
import { PROOF_CYCLE_ID_PATTERN, REVIEW_STATUS_PENDING } from "./paymentReview";

type Bucket = ReturnType<ReturnType<typeof admin.storage>["bucket"]>;

export const PAYMENT_PROOFS_PREFIX = "payment_proofs";
export const PROOF_SUBMISSION_METHOD = "vodafone_cash";
export const PROOF_MAX_BYTES = 10 * 1024 * 1024;

const PROOF_FILE_NAME_PATTERN = /^[A-Za-z0-9_-]{1,64}\.(jpg|jpeg|png|webp)$/;

const CONTENT_TYPE_BY_EXTENSION: Record<string, string> = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  webp: "image/webp",
};

export const PROOF_NOT_UPLOADED_MESSAGE = "لم يكتمل رفع الإيصال. أعد المحاولة.";
export const PROOF_REUSED_MESSAGE = "هذا الإيصال مستخدم سابقاً — ارفع صورة جديدة";
export const PROOF_RETRY_UNVERIFIED_MESSAGE =
  "هذا الإيصال مُرسل بالفعل لهذه الدفعة — حدّث الصفحة لمعرفة حالتها";
export const PROOF_INVALID_OBJECT_MESSAGE =
  "ملف الإيصال غير صالح (صورة JPG أو PNG أو WebP أقل من ١٠ ميجا)";

export type SubmitPaymentProofResult = {
  paymentId: string;
  proofCycleId: string;
  proofFileName: string;
  replayed: boolean;
};

export function newProofCycleId(): string {
  return `pc_${randomBytes(18).toString("base64url")}`;
}

export function paymentProofObjectPath(
  parentId: string,
  paymentId: string,
  fileName: string,
): string {
  return `${PAYMENT_PROOFS_PREFIX}/${parentId}/${paymentId}/${fileName}`;
}

type StoredProofObject = { generation: string; createdAtMillis: number };

/** Metadata-only check: the object must already exist; nothing is written. */
async function inspectProofObject(bucket: Bucket, path: string, fileName: string): Promise<StoredProofObject> {
  const file = bucket.file(path);
  const [exists] = await file.exists();
  if (!exists) {
    throw new HttpsError("failed-precondition", PROOF_NOT_UPLOADED_MESSAGE);
  }
  const [metadata] = await file.getMetadata();
  const size = Number(metadata.size ?? 0);
  const contentType = String(metadata.contentType ?? "").split(";")[0].trim().toLowerCase();
  const extension = fileName.split(".").pop()?.toLowerCase() ?? "";
  const createdAtMillis = Date.parse(String(metadata.timeCreated ?? ""));
  const generation = String(metadata.generation ?? "");
  if (
    !(size > 0 && size < PROOF_MAX_BYTES) ||
    contentType !== CONTENT_TYPE_BY_EXTENSION[extension] ||
    !Number.isFinite(createdAtMillis) ||
    generation.length === 0
  ) {
    throw new HttpsError("failed-precondition", PROOF_INVALID_OBJECT_MESSAGE);
  }
  return { generation, createdAtMillis };
}

export async function submitPaymentProofCore(
  deps: { db: admin.firestore.Firestore; bucket: Bucket },
  callerUid: string | undefined,
  data: Record<string, unknown>,
): Promise<SubmitPaymentProofResult> {
  const { db, bucket } = deps;
  const uid = requireCallerUid(callerUid);
  const paymentId = requireText(data.paymentId, "paymentId");
  const fileName = typeof data.fileName === "string" ? data.fileName.trim() : "";
  if (!PROOF_FILE_NAME_PATTERN.test(fileName) || paymentId.includes("/")) {
    throw new HttpsError("invalid-argument", "بيانات الإيصال غير صالحة");
  }

  if ((await loadCallerRole(db, uid)) !== "parent") {
    throw new HttpsError("permission-denied", "رفع الإيصال متاح لولي الأمر فقط");
  }

  const storagePath = paymentProofObjectPath(uid, paymentId, fileName);
  const object = await inspectProofObject(bucket, storagePath, fileName);
  const paymentRef = db.collection("payments").doc(paymentId);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(paymentRef);
    if (!snap.exists) {
      throw new HttpsError("not-found", "الدفعة غير موجودة");
    }
    const payment = snap.data() ?? {};
    const parentId = typeof payment.parentId === "string" ? payment.parentId.trim() : "";
    if (parentId !== uid) {
      throw new HttpsError("permission-denied", "هذه الدفعة غير مرتبطة بحسابك");
    }
    const studentId = typeof payment.studentId === "string" ? payment.studentId.trim() : "";
    if (studentId) {
      const parentSnap = await tx.get(db.collection("parentProfiles").doc(uid));
      if (!stringList(parentSnap.data()?.childrenIds).includes(studentId)) {
        throw new HttpsError("failed-precondition", "الطالب غير مرتبط بولي الأمر صاحب الدفعة");
      }
    }
    const currentName =
      typeof payment.proofFileName === "string" ? payment.proofFileName.trim() : "";
    const currentCycle =
      typeof payment.proofCycleId === "string" ? payment.proofCycleId : "";

    // Lost response: the identical submission already opened the current
    // cycle. Replayed whatever its review outcome since; nothing is written.
    if (
      currentName === fileName &&
      PROOF_CYCLE_ID_PATTERN.test(currentCycle) &&
      payment.proofSubmittedBy === uid &&
      payment.proofStoragePath === storagePath &&
      payment.proofObjectGeneration === object.generation
    ) {
      return { paymentId, proofCycleId: currentCycle, proofFileName: fileName, replayed: true };
    }

    if (payment.status === "paid") {
      throw new HttpsError("failed-precondition", "تم سداد هذه الدفعة بالفعل");
    }
    if (payment.reviewStatus === "approved") {
      throw new HttpsError("failed-precondition", "تم اعتماد هذه الدفعة بالفعل");
    }

    // The current proof's name, but not provably this submission: never a
    // new cycle, and not reported as a stale reuse either.
    if (currentName === fileName) {
      throw new HttpsError("failed-precondition", PROOF_RETRY_UNVERIFIED_MESSAGE);
    }
    if (stringList(payment.proofFileNameHistory).includes(fileName)) {
      throw new HttpsError("failed-precondition", PROOF_REUSED_MESSAGE);
    }
    const cycleStart = payment.proofSubmittedAt;
    if (
      cycleStart instanceof Timestamp &&
      object.createdAtMillis <= cycleStart.toMillis()
    ) {
      throw new HttpsError("failed-precondition", PROOF_REUSED_MESSAGE);
    }

    const proofCycleId = newProofCycleId();
    tx.update(paymentRef, {
      proofStoragePath: storagePath,
      proofFileName: fileName,
      proofCycleId,
      proofObjectGeneration: object.generation,
      proofSubmittedAt: FieldValue.serverTimestamp(),
      proofSubmittedBy: uid,
      proofFileNameHistory: FieldValue.arrayUnion(
        ...(currentName ? [currentName] : []),
        fileName,
      ),
      proofDownloadUrl: FieldValue.delete(),
      method: PROOF_SUBMISSION_METHOD,
      reviewStatus: REVIEW_STATUS_PENDING,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { paymentId, proofCycleId, proofFileName: fileName, replayed: false };
  });
}

export const submitPaymentProof = onCall(
  { region: "europe-west1" },
  async (request) => {
    assertBackendAllowed("submitPaymentProof");
    return submitPaymentProofCore(
      { db: admin.firestore(), bucket: admin.storage().bucket() },
      request.auth?.uid,
      (request.data ?? {}) as Record<string, unknown>,
    );
  },
);

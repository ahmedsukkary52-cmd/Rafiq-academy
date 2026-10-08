import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import {
  buildHomeworkReviewedNotification,
  decideHomeworkReviewed,
} from "./academyNotifications";
import {
  loadParentIdsByStudent,
  loadStudentNames,
  writeInAppNotifications,
} from "./academyNotificationStore";
import {
  assertSafeDataPayload,
  buildParentEvaluationNotification,
  decideDeliveryAttempt,
  decideEvaluationNotification,
  EvaluationFacts,
  ParentNotification,
} from "./evaluationNotification";
import {
  DeviceTokenDoc,
  FCM_DEVICES_SUBCOLLECTION,
  FCM_TOKENS_COLLECTION,
  NOTIFICATION_DELIVERIES_COLLECTION,
  NOTIFICATIONS_COLLECTION,
  selectSendableTokens,
  SendOutcome,
  summarizeSendOutcomes,
} from "./fcmTokenContract";
import { pushGateBlockedMessage, resolvePushSendMode } from "./pushGate";

const FEATURE = "notifyParentsOnEvaluation";

/** Push transport — Admin SDK in production, injectable for emulator tests. */
export type PushSender = (params: {
  notification: ParentNotification;
  tokens: readonly { deviceId: string; token: string }[];
}) => Promise<SendOutcome[]>;

/**
 * WA-13 / C11.3 — live evaluation send chain (server-owned).
 *
 * recitationRecords write → academy fact → parent notification doc →
 * Admin SDK FCM send → invalid token cleanup.
 *
 * PH-02: the same trigger also owns the homework-review in-app fan-out that
 * used to be published from the teacher device.
 *
 * The client never authors these notifications and never sends FCM: a push is
 * only emitted for notifications this trigger created together with their
 * `notificationDeliveries` claim, so a forged `notifications/{id}` document
 * cannot produce a push.
 */
export const notifyParentsOnEvaluation = onDocumentWritten(
  { region: "europe-west1", document: "recitationRecords/{recordId}" },
  async (event) => {
    const mode = resolvePushSendMode();
    if (mode === "blocked") {
      console.warn(pushGateBlockedMessage(FEATURE));
      return;
    }

    await handleRecitationRecordWrite({
      db: admin.firestore(),
      recordId: event.params.recordId,
      before: event.data?.before?.data() ?? null,
      after: event.data?.after?.data() ?? null,
      sender: sendPush,
    });
  },
);

export async function handleRecitationRecordWrite(params: {
  db: admin.firestore.Firestore;
  recordId: string;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  sender: PushSender;
}): Promise<void> {
  const { db, recordId, before, after, sender } = params;

  const reviewed = decideHomeworkReviewed({ before, after });
  if (reviewed.notify) {
    await fanOutHomeworkReviewed({ db, recordId, ...reviewed });
    return;
  }

  const decision = decideEvaluationNotification({ recordId, before, after });
  if (!decision.notify) return;

  const parentIds = await loadParentIds(db, decision.facts.studentId);
  if (parentIds.length === 0) return;

  const names = await loadStudentNames(db, [decision.facts.studentId]);
  const studentName = names.get(decision.facts.studentId) ?? "";

  for (const parentId of parentIds) {
    await deliverToParent({
      db,
      parentId,
      notification: buildParentEvaluationNotification({
        parentId,
        eventId: decision.eventId,
        facts: decision.facts,
        studentName,
      }),
      facts: decision.facts,
      eventId: decision.eventId,
      sender,
    });
  }
}

async function fanOutHomeworkReviewed(params: {
  db: admin.firestore.Firestore;
  recordId: string;
  studentId: string;
  halaqaId: string;
  grade: string;
}): Promise<void> {
  const { db, recordId, studentId, halaqaId, grade } = params;
  const parentsByStudent = await loadParentIdsByStudent(db, [studentId]);
  const names = await loadStudentNames(db, [studentId]);
  const observers = [studentId, ...(parentsByStudent.get(studentId) ?? [])];
  await writeInAppNotifications(
    db,
    observers.map((observerId) =>
      buildHomeworkReviewedNotification({
        observerId,
        recordId,
        studentId,
        halaqaId,
        studentName: names.get(studentId),
        grade,
      }),
    ),
  );
}

/** C11.3 step 3 — parent audience from the childrenIds relationship only. */
async function loadParentIds(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<string[]> {
  if (studentId === "") return [];
  const byStudent = await loadParentIdsByStudent(db, [studentId]);
  return byStudent.get(studentId) ?? [];
}

async function deliverToParent(params: {
  db: admin.firestore.Firestore;
  parentId: string;
  notification: ParentNotification;
  facts: EvaluationFacts;
  eventId: string;
  sender: PushSender;
}): Promise<void> {
  const { db, parentId, notification, facts, eventId, sender } = params;
  assertSafeDataPayload(notification.data);

  const notificationRef = db
    .collection(NOTIFICATIONS_COLLECTION)
    .doc(notification.notificationId);
  const deliveryRef = db
    .collection(NOTIFICATION_DELIVERIES_COLLECTION)
    .doc(notification.notificationId);

  const claim = await db.runTransaction(async (tx) => {
    const [existingNotification, existingDelivery] = await Promise.all([
      tx.get(notificationRef),
      tx.get(deliveryRef),
    ]);

    const attempt = decideDeliveryAttempt(existingDelivery.data() ?? null);
    if (!attempt.proceed) return { ...attempt, sentDeviceIds: [] as string[] };
    const previouslySent = existingDelivery.data()?.sentDeviceIds;
    const sentDeviceIds = Array.isArray(previouslySent)
      ? previouslySent.filter((id): id is string => typeof id === "string")
      : [];

    if (!existingNotification.exists) {
      tx.set(notificationRef, {
        audience: notification.audience,
        title: notification.title,
        body: notification.body,
        type: notification.type,
        readBy: [] as string[],
        hasAudioAlert: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data: notification.data,
      });
    }

    tx.set(
      deliveryRef,
      {
        notificationId: notification.notificationId,
        recipientId: parentId,
        eventId,
        evaluationId: facts.evaluationId,
        status: "sending",
        attempts: attempt.attempt,
        createdAt: existingDelivery.exists
          ? existingDelivery.data()?.createdAt
          : admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { ...attempt, sentDeviceIds };
  });

  if (!claim.proceed) return;

  // A redelivered event never re-pushes a device that already received it.
  const alreadySent = new Set(claim.sentDeviceIds);
  const devices = await loadDeviceTokens(db, parentId);
  const sendable = selectSendableTokens(devices).filter(
    (t) => !alreadySent.has(t.deviceId),
  );
  if (sendable.length === 0) {
    await deliveryRef.set(
      {
        status: alreadySent.size > 0 ? "sent" : "no_tokens",
        successCount: 0,
        failureCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return;
  }

  const outcomes = await sender({
    notification,
    tokens: sendable,
  });
  const summary = summarizeSendOutcomes(outcomes);

  await disableDevices({
    db,
    parentId,
    deviceIds: summary.invalidDeviceIds,
  });

  const delivered = outcomes
    .filter((o) => o.success)
    .map((o) => o.deviceId);
  // Dead tokens are disabled above; only retriable failures keep it open.
  const status =
    summary.retriableDeviceIds.length === 0 &&
    delivered.length + alreadySent.size > 0
      ? "sent"
      : summary.status;

  await deliveryRef.set(
    {
      status,
      successCount: summary.successCount,
      failureCount: summary.failureCount,
      disabledDeviceIds: summary.invalidDeviceIds,
      sentDeviceIds: [...new Set([...alreadySent, ...delivered])],
      errorCodes: summary.errorCodes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  if (summary.status !== "sent") {
    // Never swallow a partial/total delivery failure.
    console.error(
      `[WA-13] ${FEATURE} delivery ${summary.status} for ` +
        `${notification.notificationId}: ${summary.failureCount} failed ` +
        `(codes: ${summary.errorCodes.join(",") || "unknown"})`,
    );
  }
}

async function loadDeviceTokens(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<DeviceTokenDoc[]> {
  const snap = await db
    .collection(FCM_TOKENS_COLLECTION)
    .doc(uid)
    .collection(FCM_DEVICES_SUBCOLLECTION)
    .get();

  return snap.docs.map((doc) => ({
    deviceId: doc.id,
    token: doc.data().token,
    platform: doc.data().platform,
    disabled: doc.data().disabled,
  }));
}

async function sendPush(params: {
  notification: ParentNotification;
  tokens: readonly { deviceId: string; token: string }[];
}): Promise<SendOutcome[]> {
  const { notification, tokens } = params;

  const response = await admin.messaging().sendEachForMulticast({
    tokens: tokens.map((t) => t.token),
    notification: { title: notification.title, body: notification.body },
    data: notification.data,
    // C11.4 — collapse duplicates of the same deterministic notification.
    android: { collapseKey: notification.notificationId },
    apns: {
      headers: { "apns-collapse-id": notification.notificationId },
    },
  });

  return response.responses.map((result, index) => ({
    deviceId: tokens[index].deviceId,
    success: result.success,
    errorCode: result.error?.code,
  }));
}

/** Safe cleanup: mark dead tokens disabled, never delete client-owned docs. */
async function disableDevices(params: {
  db: admin.firestore.Firestore;
  parentId: string;
  deviceIds: readonly string[];
}): Promise<void> {
  const { db, parentId, deviceIds } = params;
  if (deviceIds.length === 0) return;

  const devicesRef = db
    .collection(FCM_TOKENS_COLLECTION)
    .doc(parentId)
    .collection(FCM_DEVICES_SUBCOLLECTION);

  const batch = db.batch();
  for (const deviceId of deviceIds) {
    batch.set(
      devicesRef.doc(deviceId),
      {
        disabled: true,
        disabledReason: "unregistered_token",
        disabledAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }
  await batch.commit();
}

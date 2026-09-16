import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

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
  PARENT_PROFILES_COLLECTION,
  selectSendableTokens,
  SendOutcome,
  summarizeSendOutcomes,
  USERS_COLLECTION,
} from "./fcmTokenContract";
import { pushGateBlockedMessage, resolvePushSendMode } from "./pushGate";

const FEATURE = "notifyParentsOnEvaluation";

/**
 * WA-13 / C11.3 — live evaluation send chain (server-owned).
 *
 * recitationRecords write → academy fact → parent notification doc →
 * Admin SDK FCM send → invalid token cleanup.
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

    const recordId = event.params.recordId;
    const decision = decideEvaluationNotification({
      recordId,
      before: event.data?.before?.data() ?? null,
      after: event.data?.after?.data() ?? null,
    });
    if (!decision.notify) return;

    const db = admin.firestore();
    const parentIds = await loadParentIds(db, decision.facts.studentId);
    if (parentIds.length === 0) return;

    const studentName = await loadStudentName(db, decision.facts.studentId);

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
      });
    }
  },
);

/** C11.3 step 3 — parent audience from the childrenIds relationship only. */
async function loadParentIds(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<string[]> {
  if (studentId === "") return [];
  const snap = await db
    .collection(PARENT_PROFILES_COLLECTION)
    .where("childrenIds", "array-contains", studentId)
    .get();
  return snap.docs.map((doc) => doc.id).sort();
}

/** Display enrichment only — never part of the FCM data payload. */
async function loadStudentName(
  db: admin.firestore.Firestore,
  studentId: string,
): Promise<string> {
  if (studentId === "") return "";
  const snap = await db.collection(USERS_COLLECTION).doc(studentId).get();
  const name = snap.data()?.name;
  return typeof name === "string" ? name.trim() : "";
}

async function deliverToParent(params: {
  db: admin.firestore.Firestore;
  parentId: string;
  notification: ParentNotification;
  facts: EvaluationFacts;
  eventId: string;
}): Promise<void> {
  const { db, parentId, notification, facts, eventId } = params;
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
    if (!attempt.proceed) return attempt;

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

    return attempt;
  });

  if (!claim.proceed) return;

  const devices = await loadDeviceTokens(db, parentId);
  const sendable = selectSendableTokens(devices);
  if (sendable.length === 0) {
    await deliveryRef.set(
      {
        status: "no_tokens",
        successCount: 0,
        failureCount: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return;
  }

  const outcomes = await sendPush({
    notification,
    tokens: sendable,
  });
  const summary = summarizeSendOutcomes(outcomes);

  await disableDevices({
    db,
    parentId,
    deviceIds: summary.invalidDeviceIds,
  });

  await deliveryRef.set(
    {
      status: summary.status,
      successCount: summary.successCount,
      failureCount: summary.failureCount,
      disabledDeviceIds: summary.invalidDeviceIds,
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

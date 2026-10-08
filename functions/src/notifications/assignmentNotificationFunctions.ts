/**
 * PH-02 / C11 — assignment → academy fact → in-app notifications.
 *
 * Replaces the teacher-device fan-out. Recipients are re-derived here from
 * the halaqa roster and parent links; the assignment author is re-checked
 * against halaqat.teacherId so a forged document cannot address anyone.
 */

import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

import {
  buildActivityPublishedNotification,
  buildHomeworkAssignedNotification,
  InAppNotification,
} from "./academyNotifications";
import {
  loadParentIdsByStudent,
  loadStudentNames,
  writeInAppNotifications,
} from "./academyNotificationStore";
import { pushGateBlockedMessage, resolvePushSendMode } from "./pushGate";
import { stringList } from "../authority/callerContext";

const FEATURE = "notifyOnAssignmentCreated";
const WIRE_HALAQA_ACTIVITY = "halaqaActivity";

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export type AssignmentFanOutResult = {
  written: number;
  skipped?: string;
};

export async function fanOutAssignmentCreated(
  db: admin.firestore.Firestore,
  assignmentId: string,
  data: Record<string, unknown>,
): Promise<AssignmentFanOutResult> {
  const halaqaId = text(data.halaqaId);
  const assignedBy = text(data.assignedBy);
  if (!halaqaId || !assignedBy) return { written: 0, skipped: "missing_identity" };

  const halaqaSnap = await db.collection("halaqat").doc(halaqaId).get();
  if (!halaqaSnap.exists) return { written: 0, skipped: "halaqa_missing" };
  const halaqa = halaqaSnap.data() ?? {};
  if (text(halaqa.teacherId) !== assignedBy) {
    return { written: 0, skipped: "author_not_halaqa_teacher" };
  }
  const roster = stringList(halaqa.studentIds);

  const isActivity = text(data.kind) === WIRE_HALAQA_ACTIVITY;
  const subjectStudents = isActivity
    ? roster
    : roster.includes(text(data.studentId))
      ? [text(data.studentId)]
      : [];
  if (subjectStudents.length === 0) {
    return { written: 0, skipped: isActivity ? "empty_roster" : "student_not_on_roster" };
  }

  const parentsByStudent = await loadParentIdsByStudent(db, subjectStudents);
  const names = await loadStudentNames(db, subjectStudents);

  const notifications: InAppNotification[] = [];
  for (const studentId of subjectStudents) {
    const observers = [studentId, ...(parentsByStudent.get(studentId) ?? [])];
    for (const observerId of observers) {
      notifications.push(
        isActivity
          ? buildActivityPublishedNotification({
              observerId,
              activityId: assignmentId,
              studentId,
              halaqaId,
              studentName: names.get(studentId),
              prompt: text(data.prompt),
            })
          : buildHomeworkAssignedNotification({
              observerId,
              assignmentId,
              studentId,
              halaqaId,
              studentName: names.get(studentId),
              newMemorizationRange: text(data.newMemorizationRange),
              reviewRange: text(data.reviewRange),
            }),
      );
    }
  }

  return { written: await writeInAppNotifications(db, notifications) };
}

export const notifyOnAssignmentCreated = onDocumentCreated(
  { region: "europe-west1", document: "assignments/{assignmentId}" },
  async (event) => {
    if (resolvePushSendMode() === "blocked") {
      console.warn(pushGateBlockedMessage(FEATURE));
      return;
    }
    const data = event.data?.data();
    if (!data) return;
    await fanOutAssignmentCreated(admin.firestore(), event.params.assignmentId, data);
  },
);

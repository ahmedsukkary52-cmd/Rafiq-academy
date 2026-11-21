import * as admin from "firebase-admin";
import { assertEmulatorProjectIsDemo } from "./emulatorProjectGuard";

admin.initializeApp();
assertEmulatorProjectIsDemo(process.env, admin.app().options.projectId);

/**
 * WA-0 / D2: Paymob is OUT. Callables remain in source for quarantine/history
 * but are NOT exported — prevents accidental production activation.
 *
 * To re-enable (must NOT happen under current locks): would require product
 * decision reversal of D2 + B-BILLING Verified.
 */
// export { createPaymentIntention } from "./paymob/createPaymentIntention";
// export { paymobWebhook } from "./paymob/paymobWebhook";

export { adminProvisionUser } from "./admin/adminProvisionUser";
export {
  adminGenerateInvoice,
  adminReinstatePaymentAccess,
} from "./admin/adminBilling";
export { processPaymentOverdueGrace } from "./billing/processOverdueGrace";
export { adminMigrateHalaqaSlotIds } from "./admin/adminMigrateHalaqaSlotIds";
export { materializeSession } from "./sessions/materializeSession";
export {
  adminSyncHalaqaGroup,
  syncHalaqaGroupOnWrite,
} from "./chat/halaqaGroupSyncFunctions";
export {
  ensureAdminGroupConversation,
  syncAdminGroupOnUserWrite,
} from "./chat/adminGroupFunctions";
export {
  createDirectConversation,
  softDeleteChatMessage,
  editChatMessage,
} from "./chat/chatAuthFunctions";
export { sendChatMessage } from "./chat/chatMessageFunctions";
export {
  notifyParentsOnEvaluation,
} from "./notifications/evaluationNotificationFunctions";
export { reconcileFcmTokenOwnership } from "./notifications/fcmTokenOwnership";
export {
  adminBackfillStudentSearch,
  projectStudentSearchOnHalaqaWrite,
  projectStudentSearchOnProfileWrite,
  projectStudentSearchOnUserWrite,
} from "./search/studentSearchFunctions";
export {
  adminBackfillStudentLifecycle,
  adminSetStudentLifecycle,
} from "./lifecycle/studentLifecycleFunctions";

// PH-02 — backend authority (server-owned transitions; clients send intent).
export { reviewPaymentProof } from "./billing/paymentReview";
export { submitPaymentProof } from "./billing/paymentProofSubmission";
export {
  recordSessionAttendance,
  upsertSessionEvaluation,
} from "./sessions/sessionRecordFunctions";
export { notifyOnAssignmentCreated } from "./notifications/assignmentNotificationFunctions";
export {
  admitStudentToHalaqa,
  adminTransferStudent,
} from "./halaqa/membershipFunctions";
export { completeHomework, purchaseAvatar } from "./economy/economyFunctions";
export { grantAward, issueAchievement } from "./awards/awardFunctions";
export { getParentAchievements } from "./awards/parentAchievementFunctions";
export { getHalaqaAwards } from "./awards/halaqaAwardsFunctions";

// P0 completion — Admin operational workflows (server-authoritative).
export { adminLinkParentChild } from "./relationships/parentLinkFunctions";
export {
  adminAddHalaqaSlot,
  adminCreateHalaqa,
} from "./halaqa/halaqaScheduleFunctions";
export { setHalaqaMeetingLink } from "./halaqa/meetingLinkFunctions";
export { getParentChildHalaqat } from "./halaqa/parentHalaqaFunctions";
export { getParentChildSchedule } from "./halaqa/parentScheduleFunctions";

// Admin milestone — complaints lifecycle and absence-request notifications.
export { respondToComplaint, submitComplaint } from "./complaints/complaintFunctions";
export {
  notifyOnAbsenceRequestCreated,
  notifyOnAbsenceRequestReviewed,
} from "./notifications/absenceRequestNotificationFunctions";
export { notifyOnPaymentUpdated } from "./notifications/paymentNotificationFunctions";
export {
  adminOnboardStudent,
  supervisorOnboardStudent,
  adminResetMemberPassword,
  completeFirstLogin,
} from "./accounts/onboardingFunctions";
export { adminBackfillUserNameNormalized } from "./accounts/memberDirectory";
export {
  adminCreateChatGroup,
  adminSetChatGroupMembers,
  adminUpdateChatGroup,
  reactToChatMessage,
} from "./chat/chatGroupFunctions";
export { adminImportAcademyRow } from "./accounts/academyImportFunctions";
export {
  adminReassignHalaqaStaff,
  adminSetStaffStatus,
} from "./staff/staffLifecycleFunctions";

// Academy relationships — assistant teachers, temporary cover, accounts.
export {
  adminEndHalaqaCover,
  adminSetHalaqaAssistant,
  adminStartHalaqaCover,
} from "./staff/halaqaAssistantFunctions";
export { adminReplaceParentLink } from "./relationships/parentLinkFunctions";
export {
  adminCreateMemberAccount,
  adminGetMemberAccount,
} from "./accounts/memberAccountFunctions";
export { adminSetMemberActive } from "./accounts/memberStatusFunctions";

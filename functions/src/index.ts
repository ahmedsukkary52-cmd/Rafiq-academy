import * as admin from "firebase-admin";

admin.initializeApp();

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
export { adminMigrateUserPhones } from "./admin/adminMigrateUserPhones";
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

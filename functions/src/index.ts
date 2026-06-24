import * as admin from "firebase-admin";

admin.initializeApp();

export { createPaymentIntention } from "./paymob/createPaymentIntention";
export { paymobWebhook } from "./paymob/paymobWebhook";
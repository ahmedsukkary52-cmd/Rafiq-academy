/**
 * Deactivated and first-login-pending accounts must not be notification
 * recipients. Mirrors Firestore hasActiveProfile (missing isActive = active).
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const {
  isEligibleNotificationRecipient,
  ROLE_NOTIFICATION_AUDIENCES,
} = require("../lib/notifications/academyNotifications.js");

test("active and legacy profiles are eligible", () => {
  assert.equal(isEligibleNotificationRecipient({ isActive: true, role: "parent" }), true);
  assert.equal(isEligibleNotificationRecipient({ role: "teacher" }), true);
  assert.equal(isEligibleNotificationRecipient({ isActive: true, passwordChangeRequired: false }), true);
});

test("deactivated and pending-password profiles are not eligible", () => {
  assert.equal(isEligibleNotificationRecipient({ isActive: false, role: "parent" }), false);
  assert.equal(
    isEligibleNotificationRecipient({ isActive: true, passwordChangeRequired: true }),
    false,
  );
  assert.equal(isEligibleNotificationRecipient(undefined), false);
});

test("role broadcast audiences stay distinct from uid audiences", () => {
  assert.ok(ROLE_NOTIFICATION_AUDIENCES.includes("admin"));
  assert.ok(ROLE_NOTIFICATION_AUDIENCES.includes("all"));
  assert.equal(ROLE_NOTIFICATION_AUDIENCES.includes("uid-parent-1"), false);
});

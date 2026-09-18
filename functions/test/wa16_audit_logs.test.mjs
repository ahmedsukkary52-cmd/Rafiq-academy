/**
 * WA-16 / C16 audit log unit tests (no Firebase emulator).
 *
 * Run: cd functions && npm run build && npm run test:wa16
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const srcDir = join(repoRoot, "functions", "src");

const contract = require("../lib/audit/auditLogContract.js");
const write = require("../lib/audit/auditLogWrite.js");
const lifecycleContract = require("../lib/lifecycle/studentLifecycleContract.js");
const lifecycleTransition = require("../lib/lifecycle/studentLifecycleTransition.js");

const provisionSrc = readFileSync(
  join(srcDir, "admin", "adminProvisionUser.ts"),
  "utf8",
);
const billingSrc = readFileSync(
  join(srcDir, "admin", "adminBilling.ts"),
  "utf8",
);
const phonesSrc = readFileSync(
  join(srcDir, "admin", "adminMigrateUserPhones.ts"),
  "utf8",
);
const slotsSrc = readFileSync(
  join(srcDir, "admin", "adminMigrateHalaqaSlotIds.ts"),
  "utf8",
);
const lifecycleSrc = readFileSync(
  join(srcDir, "lifecycle", "studentLifecycleFunctions.ts"),
  "utf8",
);
const searchSrc = readFileSync(
  join(srcDir, "search", "studentSearchFunctions.ts"),
  "utf8",
);

function stripComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/(^|[^:])\/\/.*$/gm, "$1");
}

// ── Canonical envelope ─────────────────────────────────────────────────────

test("WA-16 canonical envelope has required keys and no legacy fields", () => {
  const entry = write.buildAuditLogEntry(
    {
      actor: write.adminActor("admin1"),
      action: contract.AUDIT_ACTION.userProvision,
      targetType: contract.AUDIT_TARGET_TYPE.user,
      targetId: "u1",
      metadata: { role: "student" },
      source: "adminProvisionUser",
    },
    "SERVER_TS",
  );

  assert.deepEqual(
    Object.keys(entry).sort(),
    [...contract.AUDIT_REQUIRED_FIELDS].sort(),
  );
  assert.equal(entry.actorId, "admin1");
  assert.equal(entry.actorRole, "admin");
  assert.equal(entry.action, "user_provision");
  assert.equal(entry.targetType, "user");
  assert.equal(entry.targetId, "u1");
  assert.equal(entry.timestamp, "SERVER_TS");
  assert.equal(entry.source, "adminProvisionUser");
  assert.ok(entry.metadata && typeof entry.metadata === "object");
  assert.ok(!Object.prototype.hasOwnProperty.call(entry, "actorUid"));
  assert.ok(!Object.prototype.hasOwnProperty.call(entry, "createdAt"));
});

test("WA-16 metadata always exists even when empty", () => {
  const entry = write.buildAuditLogEntry(
    {
      actor: write.adminActor("admin1"),
      action: contract.AUDIT_ACTION.userProvision,
      targetType: contract.AUDIT_TARGET_TYPE.user,
      targetId: "u1",
      source: "test",
    },
    "TS",
  );
  assert.deepEqual(entry.metadata, {});
});

test("WA-16 action vocabulary is frozen", () => {
  assert.equal(contract.AUDIT_ACTION.userProvision, "user_provision");
  assert.equal(contract.AUDIT_ACTION.paymentReinstate, "payment_reinstate");
  assert.equal(contract.AUDIT_ACTION.userArchive, "user_archive");
  assert.equal(contract.AUDIT_ACTION.userUnarchive, "user_unarchive");
  assert.equal(contract.AUDIT_ACTION.invoiceCreate, "invoice_create");
  assert.equal(
    contract.AUDIT_ACTION.migrateUserPhones,
    "admin_migrate_user_phones",
  );
  assert.equal(
    contract.AUDIT_ACTION.migrateHalaqaSlotIds,
    "halaqa_schedule_slotid_migrate",
  );
  assert.equal(
    contract.AUDIT_ACTION.studentLifecycleBackfill,
    "student_lifecycle_backfill",
  );
  assert.equal(
    contract.AUDIT_ACTION.studentSearchBackfill,
    "student_search_backfill",
  );
});

test("WA-16 system actor is reserved for future scheduler hooks", () => {
  const actor = write.systemActor();
  assert.equal(actor.actorId, "system");
  assert.equal(actor.actorRole, "system");
});

test("WA-16 rejects forbidden and unknown metadata keys", () => {
  for (const key of ["email", "phone", "password", "proofDownloadUrl", "token"]) {
    assert.throws(
      () =>
        write.buildAuditLogEntry(
          {
            actor: write.adminActor("a1"),
            action: "user_provision",
            targetType: "user",
            targetId: "u1",
            metadata: { [key]: "x" },
            source: "test",
          },
          "TS",
        ),
      /forbids|allowlisted/,
    );
  }
  assert.throws(
    () =>
      write.buildAuditLogEntry(
        {
          actor: write.adminActor("a1"),
          action: "user_provision",
          targetType: "user",
          targetId: "u1",
          metadata: { unexpectedDump: {} },
          source: "test",
        },
        "TS",
      ),
    /allowlisted/,
  );
});

test("WA-16 migration target ids are deterministic", () => {
  assert.equal(
    write.migrationTargetId("lifecycle_bf", "start"),
    "lifecycle_bf_start",
  );
  assert.equal(
    write.migrationTargetId("phones_migrate", "full"),
    "phones_migrate_full",
  );
});

// ── Writer normalization (source contracts) ────────────────────────────────

test("WA-16 provision emits user_provision without email in audit metadata", () => {
  const code = stripComments(provisionSrc);
  assert.ok(code.includes("AUDIT_ACTION.userProvision"));
  assert.ok(code.includes("AUDIT_TARGET_TYPE.user"));
  assert.ok(code.includes("metadata: { role }"));
  assert.ok(code.includes("writeAuditLog("));
  // Auth still uses email; audit metadata must not.
  const auditCall = code.slice(code.indexOf("writeAuditLog("), code.indexOf("writeAuditLog(") + 400);
  assert.ok(!auditCall.includes("email"));
  assert.ok(!auditCall.includes("actorUid:"));
  assert.ok(!auditCall.includes("createdAt:"));
});

test("WA-16 reinstate is change-only and uses payment_reinstate", () => {
  const code = stripComments(billingSrc);
  assert.ok(code.includes("AUDIT_ACTION.paymentReinstate"));
  assert.ok(code.includes('if (current === "ok")'));
  assert.ok(code.includes("previousStatus"));
  assert.ok(code.includes("newStatus"));
  assert.ok(!code.includes("payment_access_reinstated"));
  assert.ok(code.includes("writeAuditLog("));
  const idx = code.indexOf("AUDIT_ACTION.paymentReinstate");
  const around = code.slice(Math.max(0, idx - 120), idx + 400);
  assert.ok(around.includes("writeAuditLog"));
  assert.ok(!around.includes("createdAt:"));
});

test("WA-16 invoice audits only when created === true path runs", () => {
  const code = stripComments(billingSrc);
  assert.ok(code.includes("AUDIT_ACTION.invoiceCreate"));
  assert.ok(code.includes("AUDIT_TARGET_TYPE.invoice"));
  const existingBlock = code.slice(
    code.indexOf("if (existing.exists)"),
    code.indexOf("const halaqaId"),
  );
  assert.ok(!existingBlock.includes("writeAuditLog"));
  const invoiceAudit = code.slice(
    code.indexOf("AUDIT_ACTION.invoiceCreate"),
    code.indexOf("AUDIT_ACTION.invoiceCreate") + 700,
  );
  assert.ok(invoiceAudit.includes("paymentId"));
  assert.ok(invoiceAudit.includes("pricingRuleVersion"));
  assert.ok(invoiceAudit.includes("amount"));
  assert.ok(invoiceAudit.includes("currency"));
});

test("WA-16 phone migrate audits only when migrated > 0", () => {
  const code = stripComments(phonesSrc);
  assert.ok(code.includes("if (migrated > 0)"));
  assert.ok(code.includes("AUDIT_ACTION.migrateUserPhones"));
  assert.ok(code.includes('migrationTargetId("phones_migrate", "full")'));
  assert.ok(code.includes("migratedCount"));
  const auditCall = code.slice(code.indexOf("writeAuditLog("), code.indexOf("writeAuditLog(") + 450);
  assert.ok(!auditCall.includes("actorUid:"));
  assert.ok(!auditCall.includes("createdAt:"));
});

test("WA-16 slot migrate audits only when work occurred", () => {
  const code = stripComments(slotsSrc);
  assert.ok(code.includes("!dryRun && halaqatUpdated > 0"));
  assert.ok(code.includes("AUDIT_ACTION.migrateHalaqaSlotIds"));
  assert.ok(code.includes("migrationTargetId"));
  const auditCall = code.slice(code.indexOf("writeAuditLog("), code.indexOf("writeAuditLog(") + 450);
  assert.ok(!auditCall.includes("createdAt:"));
});

test("WA-16 lifecycle uses shared writer and canonical actions", () => {
  const code = stripComments(lifecycleSrc);
  assert.ok(code.includes("writeAuditLog("));
  assert.ok(code.includes("LIFECYCLE_AUDIT_ACTION[action]"));
  assert.ok(code.includes("AUDIT_TARGET_TYPE.studentProfile"));
  assert.ok(code.includes("previousLifecycle"));
  assert.ok(code.includes("newLifecycle"));
  assert.equal(lifecycleContract.LIFECYCLE_AUDIT_ACTION.archive, "user_archive");
  assert.equal(
    lifecycleContract.LIFECYCLE_AUDIT_ACTION.unarchive,
    "user_unarchive",
  );
  assert.equal(typeof lifecycleTransition.buildLifecycleAuditEntry, "undefined");
});

test("WA-16 lifecycle noop still skips audit", () => {
  const noop = lifecycleTransition.decideLifecycleTransition({
    action: "archive",
    subject: { user: { role: "student" }, profile: { lifecycle: "archived" } },
  });
  assert.equal(noop.outcome, "noop");
  assert.ok(lifecycleSrc.includes("if (result.changed && result.from !== null)"));
});

test("WA-16 lifecycle transition still decides archive/unarchive", () => {
  const decision = lifecycleTransition.decideLifecycleTransition({
    action: "archive",
    subject: { user: { role: "student" }, profile: { lifecycle: "active" } },
  });
  assert.deepEqual(decision, {
    outcome: "transition",
    from: "active",
    to: "archived",
  });
});

test("WA-16 lifecycle/search backfill audit only on meaningful work", () => {
  const life = stripComments(lifecycleSrc);
  const search = stripComments(searchSrc);
  assert.ok(life.includes("!dryRun && stamped > 0"));
  assert.ok(life.includes("AUDIT_ACTION.studentLifecycleBackfill"));
  assert.ok(search.includes("created > 0 || updated > 0 || deleted > 0"));
  assert.ok(search.includes("AUDIT_ACTION.studentSearchBackfill"));
  assert.ok(search.includes("search_bf"));
});

test("WA-16 Rules keep Admin-read / client-write-denied", () => {
  const rules = readFileSync(join(repoRoot, "firestore.rules"), "utf8");
  const block = rules
    .split("match /auditLogs/{logId} {")[1]
    .split("    }")[0];
  assert.ok(block.includes("allow read: if isAdmin();"));
  assert.ok(block.includes("allow write: if false;"));
});

test("WA-16 no NEW audit path emits actorUid or createdAt", () => {
  for (const [name, src] of [
    ["provision", provisionSrc],
    ["billing", billingSrc],
    ["phones", phonesSrc],
    ["slots", slotsSrc],
    ["lifecycle", lifecycleSrc],
    ["search", searchSrc],
  ]) {
    const code = stripComments(src);
    let from = 0;
    while (true) {
      const idx = code.indexOf("writeAuditLog(", from);
      if (idx < 0) break;
      const slice = code.slice(idx, idx + 500);
      assert.ok(!slice.includes("actorUid:"), `${name} audit must not use actorUid:`);
      assert.ok(!slice.includes("createdAt:"), `${name} audit must not use createdAt:`);
      from = idx + 1;
    }
  }
});
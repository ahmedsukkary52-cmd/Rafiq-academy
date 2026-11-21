/**
 * D0 — payment proof Storage isolation (repo storage.rules).
 *
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage \
 *     "npm --prefix rules_test run test:d0:storage"
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { PROJECT_ID } from "./project_id.mjs";
import test from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";

const __dirname = dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(join(__dirname, "..", name), "utf8");

let testEnv;
const storageOf = (uid) => testEnv.authenticatedContext(uid).storage();
const put = (ref, contentType, bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9])) =>
  ref.put(bytes, { contentType });

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: read("firestore.rules") },
    storage: { rules: read("storage.rules") },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (role) => ({ name: role, role, isActive: true });
    // Unique ids avoid Storage emulator cross-service cache bleed.
    const docs = {
      "users/d0admin": user("admin"),
      "users/d0parent": user("parent"),
      "users/d0parentOther": user("parent"),
      "users/d0student": user("student"),
      "users/d0teacher": user("teacher"),
      "users/d0supervisor": user("supervisor"),
      "parentProfiles/d0parent": { childrenIds: ["d0student"] },
      "halaqat/d0h1": {
        teacherId: "d0teacher",
        supervisorId: "d0supervisor",
        studentIds: ["d0student"],
        status: "active",
        assistantTeacherIds: [],
        coverTeacherId: "",
        coverId: "",
      },
      "studentProfiles/d0student": { uid: "d0student", halaqaId: "d0h1" },
      "payments/d0pay": {
        parentId: "d0parent",
        studentId: "d0student",
        amount: 100,
        status: "due",
      },
    };
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
});

const proofPath = "payment_proofs/d0parent/d0pay/receipt.jpg";

test("D0 parent may create own payment proof jpeg", async () => {
  await assertSucceeds(put(storageOf("d0parent").ref(proofPath), "image/jpeg"));
});

test("D0 other parent cannot read or overwrite that proof", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await put(ctx.storage().ref(proofPath), "image/jpeg");
  });
  await assertFails(storageOf("d0parentOther").ref(proofPath).getDownloadURL());
  await assertFails(put(storageOf("d0parentOther").ref(proofPath), "image/jpeg"));
});

test("D0 student and teacher cannot read payment proof", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await put(ctx.storage().ref(proofPath), "image/jpeg");
  });
  await assertFails(storageOf("d0student").ref(proofPath).getDownloadURL());
  await assertFails(storageOf("d0teacher").ref(proofPath).getDownloadURL());
});

test("D0 admin may read proof; client update/delete denied", async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await put(ctx.storage().ref(proofPath), "image/jpeg");
  });
  await assertSucceeds(storageOf("d0admin").ref(proofPath).getDownloadURL());
  await assertFails(put(storageOf("d0admin").ref(proofPath), "image/jpeg"));
  await assertFails(storageOf("d0admin").ref(proofPath).delete());
});

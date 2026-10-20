/**
 * No-personal-contact policy (no Firebase emulator).
 *
 * Run: cd functions && npm run build && node --test test/contact_info_policy.test.mjs
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const policy = require("../lib/privacy/contactInfoPolicy.js");
const chat = require("../lib/chat/chatMessageContract.js");
const { sendChatMessageCore } = require("../lib/chat/chatMessageFunctions.js");
const { editChatMessageCore } = require("../lib/chat/chatAuthFunctions.js");
const { adminProvisionUser } = require("../lib/admin/adminProvisionUser.js");

const read = (...p) => readFileSync(join(repoRoot, ...p), "utf8");

const PHONE = "رقمي 0501234567";
const WA = "https://wa.me/966501234567";
const ACADEMIC = "سورة البقرة 1-20، الدرجة 95/100";
const MSG_ID = "msg_abcdefghij";

test("phone numbers are detected in common local and international forms", () => {
  for (const text of [
    "0501234567",
    "رقمي 0501234567 كلمني",
    "050 123 4567",
    "050-123-4567",
    "(050) 123-4567",
    "+966 50 123 4567",
    "+966501234567",
    "00966501234567",
    "966501234567",
    "01012345678",
    "رقم ولي الأمر 0111 234 5678",
    "+20 101 234 5678",
    "201512345678",
    "+44 20 7946 0958",
    "٠٥٠١٢٣٤٥٦٧",
    "۰۵۰۱۲۳۴۵۶۷",
    "call 0501234567 2026",
  ]) {
    assert.equal(policy.detectContactInfo(text), "phone_number", text);
  }
});

test("WhatsApp and telephone links are detected", () => {
  assert.equal(policy.detectContactInfo("https://wa.me/966501234567"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("راسلني wa.me/qr/ABC"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("https://chat.whatsapp.com/AbCdEf"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("https://api.whatsapp.com/send?phone=1"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("whatsapp://send?text=hi"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("https://wa.link/abc123"), "whatsapp_link");
  assert.equal(policy.detectContactInfo("tel:123"), "phone_link");
  assert.equal(policy.detectContactInfo("اتصل sms:5551234"), "phone_link");
  assert.equal(policy.detectContactInfo("<a href='TEL:+1'>x</a>"), "phone_link");
});

test("legitimate academic content is not rejected", () => {
  for (const text of [
    "",
    "أحسنت! الدرجة 95/100",
    "الدرجة 18 من 20",
    "احفظ الآيات 1-10 من سورة البقرة",
    "آية الكرسي 2:255",
    "سورة البقرة 2:1-5 ثم 2:6-20",
    "الواجب يوم 2026-10-15",
    "الموعد 15/10/2026 الساعة 4:30",
    "15.10.2026",
    "تمرين 3.2 صفحة 45",
    "الصفحات 12 13 14 15",
    "حل التمارين 1 2 3 4 5 6 7 8 9 10",
    "رسوم الشهر 1,500 جنيه",
    "المبلغ 1500.00",
    "الجزء 30 الحزب 60",
    "عدد الطلاب 120 والحلقات 12",
    "https://example.edu/lesson/2026/10",
    "https://youtube.com/watch?v=abc123",
    "telescope telegraph hotel: lesson",
    "whatsapp group is not allowed",
    "ISBN 978-3-16-148410-0",
  ]) {
    assert.equal(policy.detectContactInfo(text), null, text);
  }
});

test("contact field keys are recognised", () => {
  assert.equal(policy.findContactFieldKey({ email: "a@b", phone: "1" }), "phone");
  assert.equal(policy.findContactFieldKey({ phoneNumber: "" }), "phoneNumber");
  assert.equal(policy.findContactFieldKey({ whatsapp: null }), "whatsapp");
  assert.equal(policy.findContactFieldKey({ email: "a@b", name: "x" }), null);
  assert.equal(policy.findContactFieldKey(null), null);
});

test("contactInfoViolation returns the Arabic message or null", () => {
  assert.equal(
    policy.contactInfoViolation("0501234567"),
    policy.CONTACT_INFO_REJECTION_MESSAGE,
  );
  assert.equal(policy.contactInfoViolation("البقرة 1-20"), null);
  assert.equal(policy.contactInfoViolation(""), null);
  assert.equal(policy.contactInfoViolation(undefined), null);
});

// Same inputs as the matching group in test/shared/contact_info_policy_test.dart.
test("separator, case and digit-script variants", () => {
  const cases = [
    ["050\u00a0123\u00a04567", "phone_number"],
    ["050\t123\t4567", "phone_number"],
    ["050.123.4567", "phone_number"],
    ["٠٥٠ ١٢٣ ٤٥٦٧", "phone_number"],
    ["+٩٦٦ ٥٠ ١٢٣ ٤٥٦٧", "phone_number"],
    ["050 ۱۲۳ 4567", "phone_number"],
    ["HTTPS://WA.ME/1", "whatsapp_link"],
    ["Tel:1", "phone_link"],
    ["رقميwa.me/1", "whatsapp_link"],
    ["السورة ٢:٢٥٥", null],
    ["الحصة ١٥/١٠/٢٠٢٦", null],
    ["swa.me", null],
    ["hotel:5", null],
  ];
  for (const [text, expected] of cases) {
    assert.equal(policy.detectContactInfo(text), expected, JSON.stringify(text));
  }
});

// --- chat contract -------------------------------------------------------

function isContactRejection(e) {
  return (
    e.code === "invalid-argument"
    && e.message === policy.CONTACT_INFO_REJECTION_MESSAGE
  );
}

function sendInput(overrides = {}) {
  return { conversationId: "c1", messageId: MSG_ID, ...overrides };
}

function fileInput(storageName, displayName) {
  return sendInput({
    type: "file",
    media: {
      storagePath: `chat_attachments/c1/${MSG_ID}/${storageName}`,
      ...(displayName === undefined ? {} : { fileName: displayName }),
    },
  });
}

test("chat text and captions reject contact info; academic text is kept", () => {
  for (const text of [PHONE, WA, "tel:123"]) {
    assert.throws(
      () => chat.normalizeMessageText(text),
      (e) => e instanceof chat.ChatInputError && isContactRejection(e),
    );
    assert.throws(
      () => chat.parseSendChatMessageInput(sendInput({ text })),
      (e) => e instanceof chat.ChatInputError && isContactRejection(e),
    );
  }
  assert.throws(
    () => chat.parseSendChatMessageInput({ ...fileInput("file.pdf"), text: PHONE }),
    (e) => e instanceof chat.ChatInputError && isContactRejection(e),
  );
  assert.equal(chat.normalizeMessageText(`  ${ACADEMIC}  `), ACADEMIC);
});

test("attachment display names and storage object names are both checked", () => {
  for (const input of [
    fileInput("file.pdf", "0501234567.pdf"),
    fileInput("0501234567.pdf", "الواجب.pdf"),
    fileInput("0501234567.pdf"),
  ]) {
    assert.throws(
      () => chat.parseSendChatMessageInput(input),
      (e) => e instanceof chat.ChatInputError && isContactRejection(e),
    );
  }

  const named = chat.parseSendChatMessageInput(fileInput("file.pdf", "الواجب 2026-10-15.pdf"));
  assert.equal(named.media.fileName, "الواجب 2026-10-15.pdf");
  assert.equal(named.media.storagePath, `chat_attachments/c1/${MSG_ID}/file.pdf`);
  const image = chat.parseSendChatMessageInput(
    sendInput({ type: "image", media: { storagePath: `chat_media/c1/${MSG_ID}/image.jpg` } }),
  );
  assert.equal(image.media.fileName, "image.jpg");
});

// --- in-memory Firestore for the callable cores ---------------------------

function fakeDb(seed) {
  const docs = new Map(Object.entries(seed).map(([k, v]) => [k, { ...v }]));
  const log = { reads: 0, writes: [] };
  const snap = (path) => ({
    exists: docs.has(path),
    data: () => (docs.has(path) ? { ...docs.get(path) } : undefined),
  });
  const doc = (path) => ({
    path,
    async get() {
      log.reads++;
      return snap(path);
    },
    collection: (name) => col(`${path}/${name}`),
  });
  const col = (path) => ({ doc: (id) => doc(`${path}/${id}`) });
  const db = {
    collection: (name) => col(name),
    async runTransaction(fn) {
      const pending = [];
      const tx = {
        get: (ref) => ref.get(),
        create: (ref, data) => pending.push(["create", ref.path, data]),
        update: (ref, data) => pending.push(["update", ref.path, data]),
      };
      const result = await fn(tx);
      for (const [op, path, data] of pending) {
        log.writes.push([op, path]);
        docs.set(path, op === "create" ? { ...data } : { ...docs.get(path), ...data });
      }
      return result;
    },
  };
  return { db, docs, log };
}

/** Any property access throws: proves the code never reached Firestore/Storage. */
function untouchable(label) {
  return new Proxy({}, {
    get(_, prop) {
      throw new Error(`${label}.${String(prop)} must not be used`);
    },
  });
}

const CONV = "conversations/c1";
const MSG = `${CONV}/messages/${MSG_ID}`;

function chatSeed({ sentAt = new Date(), senderId = "s1", type = "text" } = {}) {
  return {
    "users/s1": { role: "student", isActive: true },
    "users/t1": { role: "teacher", isActive: true },
    "users/x1": { role: "student", isActive: true },
    [CONV]: { participantIds: ["s1", "t1"], lastMessageId: MSG_ID, lastMessage: "قبل" },
    [MSG]: { senderId, type, text: "قبل", sentAt, deleted: false },
  };
}

test("sendChatMessage rejects contact info before any Firestore or Storage access", async () => {
  const deps = { db: untouchable("db"), bucket: untouchable("bucket") };
  for (const input of [
    sendInput({ text: PHONE }),
    sendInput({ text: WA }),
    fileInput("file.pdf", "0501234567.pdf"),
    fileInput("0501234567.pdf", "الواجب.pdf"),
  ]) {
    await assert.rejects(sendChatMessageCore(deps, "s1", input), (e) => {
      assert.ok(isContactRejection(e), e.message);
      assert.ok(!e.message.includes("0501234567"));
      return true;
    });
  }
});

test("sendChatMessage persists academic text for a participant", async () => {
  const { db, docs, log } = fakeDb(chatSeed());
  const id = "msg_new_123456";
  const result = await sendChatMessageCore(
    { db, bucket: untouchable("bucket") },
    "s1",
    { conversationId: "c1", messageId: id, text: ACADEMIC },
  );
  assert.deepEqual(result, { conversationId: "c1", messageId: id, created: true });
  assert.equal(docs.get(`${CONV}/messages/${id}`).text, ACADEMIC);
  assert.equal(docs.get(CONV).lastMessage, ACADEMIC);
  assert.deepEqual(log.writes.map(([op]) => op), ["create", "update"]);
});

test("editChatMessage rejects contact info before reading or writing anything", async () => {
  for (const text of [PHONE, WA, "sms:5551234"]) {
    await assert.rejects(
      editChatMessageCore(untouchable("db"), "s1", { conversationId: "c1", messageId: MSG_ID, text }),
      (e) => {
        assert.ok(isContactRejection(e), e.message);
        assert.ok(!e.message.includes("0501234567"));
        return true;
      },
    );
  }
});

test("editChatMessage: owner edits academic text within the window", async () => {
  const { db, docs } = fakeDb(chatSeed());
  const result = await editChatMessageCore(db, "s1", {
    conversationId: "c1",
    messageId: MSG_ID,
    text: `  ${ACADEMIC} `,
  });
  assert.deepEqual(result, { conversationId: "c1", messageId: MSG_ID, edited: true });
  assert.equal(docs.get(MSG).text, ACADEMIC);
  assert.equal(docs.get(CONV).lastMessage, ACADEMIC);
});

test("editChatMessage keeps ownership, membership, window and type rules", async () => {
  const cases = [
    ["another participant", chatSeed(), "t1", "permission-denied"],
    ["a non-participant", chatSeed(), "x1", "permission-denied"],
    ["an expired window", chatSeed({ sentAt: new Date(Date.now() - 16 * 60 * 1000) }), "s1", "permission-denied"],
    ["a media message", chatSeed({ type: "image" }), "s1", "failed-precondition"],
    ["an unknown caller", chatSeed(), "nobody", "permission-denied"],
  ];
  for (const [label, seed, caller, code] of cases) {
    const { db, docs, log } = fakeDb(seed);
    const before = { ...docs.get(MSG) };
    await assert.rejects(
      editChatMessageCore(db, caller, { conversationId: "c1", messageId: MSG_ID, text: ACADEMIC }),
      (e) => e.code === code,
      label,
    );
    assert.deepEqual(docs.get(MSG), before, label);
    assert.deepEqual(log.writes, [], label);
  }
});

test("editChatMessage callable still authenticates before validating", () => {
  const source = read("functions", "src", "chat", "chatAuthFunctions.ts");
  const callable = source.slice(source.indexOf("export const editChatMessage"));
  assert.match(
    callable,
    /assertBackendAllowed\("editChatMessage"\);\s*const callerUid = requireUid\(request\.auth\?\.uid\);\s*return editChatMessageCore\(admin\.firestore\(\), callerUid, request\.data\);/,
  );
  const core = source.slice(
    source.indexOf("export async function editChatMessageCore"),
    source.indexOf("export const editChatMessage"),
  );
  assert.ok(core.indexOf("normalizeMessageText(data.text)") < core.indexOf("loadUserRole("));
  assert.ok(core.indexOf("canEditMessage(") < core.indexOf("tx.update("));
});

// --- admin provisioning ----------------------------------------------------

function withEmulatorGate(fn) {
  const keys = ["PRODUCTION_BACKEND_ENABLED", "FUNCTIONS_EMULATOR", "GCLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT", "FIREBASE_CONFIG"];
  const prev = Object.fromEntries(keys.map((k) => [k, process.env[k]]));
  for (const k of keys) delete process.env[k];
  process.env.FUNCTIONS_EMULATOR = "true";
  process.env.GCLOUD_PROJECT = "demo-rafiq-rules";
  return fn().finally(() => {
    for (const [k, v] of Object.entries(prev)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  });
}

test("adminProvisionUser: every contact field key is rejected, even when empty", () => {
  const base = { email: "a@x.test", password: "secret1", name: "طالب", role: "student" };
  assert.equal(policy.findContactFieldKey(base), null);
  for (const key of policy.CONTACT_FIELD_KEYS) {
    for (const value of ["", null, "x"]) {
      assert.equal(policy.findContactFieldKey({ ...base, [key]: value }), key);
    }
  }
});

test("adminProvisionUser: admin check first, then contact fields, then the user is created", async () => {
  await withEmulatorGate(() =>
    assert.rejects(
      adminProvisionUser.run({ data: { email: "a@x.test", phone: "x" } }),
      (e) => e.code === "unauthenticated",
    ),
  );

  const source = read("functions", "src", "admin", "adminProvisionUser.ts");
  const order = [
    "assertCallerIsAdmin(request.auth?.uid)",
    "findContactFieldKey(request.data) !== null",
    'requireNonEmptyString(request.data?.email, "email")',
    "parseProvisionRole(request.data?.role)",
    "admin.auth().createUser(",
  ].map((needle) => {
    const at = source.indexOf(needle);
    assert.ok(at >= 0, needle);
    return at;
  });
  assert.deepEqual([...order].sort((a, b) => a - b), order);
  assert.doesNotMatch(source, /\bphone\b/);
  const rejection = /findContactFieldKey\(request\.data\) !== null\) \{\s*throw new HttpsError\(\s*"invalid-argument",\s*"([^"]+)",\s*\);/.exec(source);
  assert.ok(rejection, "contact-field rejection uses a fixed message");
});

test("the Dart contact policy mirrors the TypeScript field list and message", () => {
  const dart = read("lib", "shared", "domain", "contact_info_policy.dart");
  for (const key of policy.CONTACT_FIELD_KEYS) assert.ok(dart.includes(`'${key}'`), key);
  assert.ok(dart.includes(`'${policy.CONTACT_INFO_REJECTION_MESSAGE}'`));
});

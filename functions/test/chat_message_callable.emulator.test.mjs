/**
 * Chat send / edit / soft-delete callables over HTTP through the Functions
 * emulator at the client region URL. Media objects live in the Storage
 * emulator and are verified server-side (uploader, size, MIME, signature).
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only auth,firestore,functions,storage \
 *     "node --test --test-concurrency=1 functions/test/chat_message_callable.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? "127.0.0.1:5001";

if (!FIRESTORE || !AUTH || !STORAGE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error(
    "Chat emulator suite requires auth + firestore + functions + storage emulators and a demo- project id",
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();

const CLIENT_REGION = (() => {
  const di = readFileSync(join(here, "..", "..", "lib", "core", "di", "di_module.dart"), "utf8");
  return di.match(/FirebaseFunctions\.instanceFor\(\s*region:\s*'([^']+)'/)[1];
})();

const DIRECT = "student1_teacher1";
// Halaqa id not seeded by other suites: their late syncHalaqaGroupOnWrite
// triggers would otherwise rewrite this group's participants mid-test.
const GROUP_HALAQA = "chat_h1";
const GROUP = `halaqa_group_${GROUP_HALAQA}`;

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1, 0xff, 0xd9]);
const PDF = Buffer.from("%PDF-1.7\n%âãÏÓ\n1 0 obj\n<<>>\nendobj\n", "latin1");
const M4A = Buffer.concat([
  Buffer.from([0, 0, 0, 0x20]),
  Buffer.from("ftypM4A ", "latin1"),
  Buffer.alloc(24, 1),
]);
const DOCX = Buffer.concat([Buffer.from([0x50, 0x4b, 0x03, 0x04]), Buffer.alloc(28, 2)]);

async function clearAll() {
  const fs = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(fs.ok, true, "firestore clear failed");
  const auth = await fetch(`http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: "DELETE",
  });
  assert.equal(auth.ok, true, "auth clear failed");
  const [files] = await bucket.getFiles();
  await Promise.all(files.map((f) => f.delete()));
}

const tokens = {};

async function idTokenFor(uid) {
  await admin.auth().createUser({ uid, email: `${uid}@example.test`, password: "secret123" });
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${uid}@example.test`,
        password: "secret123",
        returnSecureToken: true,
      }),
    },
  );
  const body = await res.json();
  assert.ok(body.idToken, `sign-in failed for ${uid}: ${JSON.stringify(body)}`);
  return body.idToken;
}

async function call(name, data, uid, region = CLIENT_REGION) {
  const token = uid ? tokens[uid] : null;
  const res = await fetch(`http://${FUNCTIONS}/${PROJECT_ID}/${region}/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: res.status, body, code: body.error?.status };
}

const send = (uid, data) => call("sendChatMessage", data, uid);

async function upload(path, bytes, contentType, uploaderId) {
  await bucket.file(path).save(bytes, {
    contentType,
    metadata: { metadata: { uploaderId } },
    resumable: false,
  });
}

const conv = async (id) => (await db.doc(`conversations/${id}`).get()).data();
const msg = async (convId, id) => db.doc(`conversations/${convId}/messages/${id}`).get();

let seq = 0;
const newId = () => `msg${Date.now().toString(36)}${(seq++).toString().padStart(4, "0")}`;

test.beforeEach(async () => {
  await clearAll();
  for (const uid of ["student1", "teacher1", "supervisor1", "parent1", "admin1", "student2", "inactive1"]) {
    tokens[uid] = await idTokenFor(uid);
  }
  const batch = db.batch();
  batch.set(db.doc("users/student1"), { role: "student", isActive: true });
  batch.set(db.doc("users/student2"), { role: "student", isActive: true });
  batch.set(db.doc("users/teacher1"), { role: "teacher", isActive: true });
  batch.set(db.doc("users/supervisor1"), { role: "supervisor", isActive: true });
  batch.set(db.doc("users/parent1"), { role: "parent", isActive: true });
  batch.set(db.doc("users/admin1"), { role: "admin", isActive: true });
  batch.set(db.doc("users/inactive1"), { role: "student", isActive: false });
  batch.set(db.doc(`conversations/${DIRECT}`), {
    kind: "direct",
    participantIds: ["student1", "teacher1"],
    unreadCounts: { student1: 0, teacher1: 0 },
  });
  batch.set(db.doc("conversations/inactive1_teacher1"), {
    kind: "direct",
    participantIds: ["inactive1", "teacher1"],
    unreadCounts: {},
  });
  batch.set(db.doc(`conversations/${GROUP}`), {
    kind: "halaqa_group",
    halaqaId: GROUP_HALAQA,
    participantIds: ["teacher1", "supervisor1", "student1", "student2"],
    unreadCounts: {},
  });
  await batch.commit();
});

// ── Text send ────────────────────────────────────────────────────────────────

test("text send: server identity, server timestamp, preview and unread counts", async () => {
  const id = newId();
  const res = await send("student1", { conversationId: DIRECT, messageId: id, text: "  السلام عليكم  " });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.deepEqual(res.body.result, { conversationId: DIRECT, messageId: id, created: true });

  const m = (await msg(DIRECT, id)).data();
  assert.equal(m.senderId, "student1");
  assert.equal(m.type, "text");
  assert.equal(m.text, "السلام عليكم");
  assert.equal(m.deleted, false);
  assert.ok(m.sentAt instanceof admin.firestore.Timestamp, "sentAt must be a server timestamp");
  assert.ok(Math.abs(m.sentAt.toMillis() - Date.now()) < 60_000);

  const c = await conv(DIRECT);
  assert.equal(c.lastMessage, "السلام عليكم");
  assert.equal(c.lastMessageSenderId, "student1");
  assert.equal(c.lastMessageId, id);
  assert.equal(c.lastMessageType, "text");
  assert.equal(c.unreadCounts.teacher1, 1);
  assert.equal(c.unreadCounts.student1, 0);
});

test("text send: client cannot supply senderId / sentAt; empty and oversized text rejected", async () => {
  const spoof = await send("student1", {
    conversationId: DIRECT,
    messageId: newId(),
    text: "x",
    senderId: "teacher1",
  });
  assert.equal(spoof.code, "INVALID_ARGUMENT");
  const ts = await send("student1", { conversationId: DIRECT, messageId: newId(), text: "x", sentAt: 1 });
  assert.equal(ts.code, "INVALID_ARGUMENT");
  const empty = await send("student1", { conversationId: DIRECT, messageId: newId(), text: "   " });
  assert.equal(empty.code, "INVALID_ARGUMENT");
  const long = await send("student1", { conversationId: DIRECT, messageId: newId(), text: "a".repeat(4001) });
  assert.equal(long.code, "INVALID_ARGUMENT");
  const badId = await send("student1", { conversationId: DIRECT, messageId: "../x", text: "x" });
  assert.equal(badId.code, "INVALID_ARGUMENT");
  assert.equal((await db.collection(`conversations/${DIRECT}/messages`).get()).size, 0);
});

test("authorization: outsider, Admin non-member, deactivated member and anonymous are denied", async () => {
  for (const uid of ["parent1", "student2", "admin1"]) {
    const res = await send(uid, { conversationId: DIRECT, messageId: newId(), text: "x" });
    assert.equal(res.code, "PERMISSION_DENIED", `${uid} must not send into ${DIRECT}`);
  }
  const inactive = await send("inactive1", {
    conversationId: "inactive1_teacher1",
    messageId: newId(),
    text: "x",
  });
  assert.equal(inactive.code, "PERMISSION_DENIED");
  const anon = await send(null, { conversationId: DIRECT, messageId: newId(), text: "x" });
  assert.equal(anon.code, "UNAUTHENTICATED");
  const missing = await send("student1", { conversationId: "nope_conv", messageId: newId(), text: "x" });
  assert.equal(missing.code, "NOT_FOUND");
  assert.equal((await db.collection(`conversations/${DIRECT}/messages`).get()).size, 0);
});

test("group: Parent is not a member; members increment every other member's unread", async () => {
  const parent = await send("parent1", { conversationId: GROUP, messageId: newId(), text: "x" });
  assert.equal(parent.code, "PERMISSION_DENIED");

  const res = await send("student1", { conversationId: GROUP, messageId: newId(), text: "سؤال" });
  assert.equal(res.status, 200, JSON.stringify(res.body));
  const c = await conv(GROUP);
  assert.equal(c.unreadCounts.teacher1, 1);
  assert.equal(c.unreadCounts.supervisor1, 1);
  assert.equal(c.unreadCounts.student2, 1);
  assert.equal(c.unreadCounts.student1, undefined);
  assert.equal(c.unreadCounts.parent1, undefined);
});

// ── Idempotency + concurrency ────────────────────────────────────────────────

test("retry with the same messageId is idempotent (one message, one unread)", async () => {
  const id = newId();
  const first = await send("student1", { conversationId: DIRECT, messageId: id, text: "مرة" });
  const second = await send("student1", { conversationId: DIRECT, messageId: id, text: "مرة" });
  assert.equal(first.body.result.created, true);
  assert.equal(second.status, 200);
  assert.equal(second.body.result.created, false);
  assert.equal((await db.collection(`conversations/${DIRECT}/messages`).get()).size, 1);
  assert.equal((await conv(DIRECT)).unreadCounts.teacher1, 1);

  const hijack = await send("teacher1", { conversationId: DIRECT, messageId: id, text: "x" });
  assert.equal(hijack.code, "ALREADY_EXISTS");
});

test("concurrent sends: parallel distinct messages all counted; parallel duplicates collapse", async () => {
  const ids = Array.from({ length: 6 }, newId);
  const results = await Promise.all(
    ids.map((id, i) => send(i % 2 ? "teacher1" : "student1", { conversationId: DIRECT, messageId: id, text: `m${i}` })),
  );
  results.forEach((r) => assert.equal(r.status, 200, JSON.stringify(r.body)));
  const c = await conv(DIRECT);
  assert.equal(c.unreadCounts.teacher1, 3);
  assert.equal(c.unreadCounts.student1, 3);
  assert.equal((await db.collection(`conversations/${DIRECT}/messages`).get()).size, 6);

  const dup = newId();
  const dupResults = await Promise.all(
    [0, 1, 2].map(() => send("student1", { conversationId: GROUP, messageId: dup, text: "dup" })),
  );
  dupResults.forEach((r) => assert.equal(r.status, 200, JSON.stringify(r.body)));
  assert.equal(dupResults.filter((r) => r.body.result.created).length, 1);
  assert.equal((await conv(GROUP)).unreadCounts.teacher1, 1);
});

// ── Media ────────────────────────────────────────────────────────────────────

test("image: message created only after a verified upload by the sender", async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/photo.jpg`;

  const notUploaded = await send("teacher1", {
    conversationId: DIRECT,
    messageId: id,
    type: "image",
    media: { storagePath: path },
  });
  assert.equal(notUploaded.code, "FAILED_PRECONDITION");
  assert.equal((await msg(DIRECT, id)).exists, false);

  await upload(path, JPEG, "image/jpeg", "teacher1");
  const ok = await send("teacher1", {
    conversationId: DIRECT,
    messageId: id,
    type: "image",
    media: { storagePath: path, fileName: "صورة الواجب.jpg" },
  });
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  const m = (await msg(DIRECT, id)).data();
  assert.equal(m.type, "image");
  assert.equal(m.media.storagePath, path);
  assert.equal(m.media.contentType, "image/jpeg");
  assert.equal(m.media.sizeBytes, JPEG.length);
  assert.equal(m.media.fileName, "صورة الواجب.jpg");
  assert.equal((await conv(DIRECT)).lastMessage, "صورة");
});

test("media verification: uploader mismatch, MIME spoofing, wrong path and bad type rejected", async () => {
  const stolen = newId();
  const stolenPath = `chat_media/${DIRECT}/${stolen}/a.jpg`;
  await upload(stolenPath, JPEG, "image/jpeg", "student1");
  const r1 = await send("teacher1", {
    conversationId: DIRECT,
    messageId: stolen,
    type: "image",
    media: { storagePath: stolenPath },
  });
  assert.equal(r1.code, "FAILED_PRECONDITION");

  const spoof = newId();
  const spoofPath = `chat_media/${DIRECT}/${spoof}/a.jpg`;
  await upload(spoofPath, PDF, "image/jpeg", "teacher1");
  const r2 = await send("teacher1", {
    conversationId: DIRECT,
    messageId: spoof,
    type: "image",
    media: { storagePath: spoofPath },
  });
  assert.equal(r2.code, "FAILED_PRECONDITION");

  const gif = newId();
  const gifPath = `chat_media/${DIRECT}/${gif}/a.gif`;
  await upload(gifPath, Buffer.from("GIF89a0000000000"), "image/gif", "teacher1");
  const r3 = await send("teacher1", {
    conversationId: DIRECT,
    messageId: gif,
    type: "image",
    media: { storagePath: gifPath },
  });
  assert.equal(r3.code, "FAILED_PRECONDITION");

  const other = newId();
  const r4 = await send("teacher1", {
    conversationId: DIRECT,
    messageId: other,
    type: "image",
    media: { storagePath: `chat_media/${GROUP}/${other}/a.jpg` },
  });
  assert.equal(r4.code, "INVALID_ARGUMENT");

  const wrongFolder = newId();
  const r5 = await send("teacher1", {
    conversationId: DIRECT,
    messageId: wrongFolder,
    type: "image",
    media: { storagePath: `chat_attachments/${DIRECT}/${wrongFolder}/a.jpg` },
  });
  assert.equal(r5.code, "INVALID_ARGUMENT");

  assert.equal((await db.collection(`conversations/${DIRECT}/messages`).get()).size, 0);
  assert.equal((await conv(DIRECT)).unreadCounts.student1, 0);
});

test("voice and file messages carry verified metadata", async () => {
  const voiceId = newId();
  const voicePath = `chat_voice/${DIRECT}/${voiceId}/voice.m4a`;
  await upload(voicePath, M4A, "audio/mp4", "student1");
  const noDuration = await send("student1", {
    conversationId: DIRECT,
    messageId: voiceId,
    type: "voice",
    media: { storagePath: voicePath },
  });
  assert.equal(noDuration.code, "INVALID_ARGUMENT");
  const voice = await send("student1", {
    conversationId: DIRECT,
    messageId: voiceId,
    type: "voice",
    media: { storagePath: voicePath, durationMs: 4200 },
  });
  assert.equal(voice.status, 200, JSON.stringify(voice.body));
  const vm = (await msg(DIRECT, voiceId)).data();
  assert.equal(vm.media.durationMs, 4200);
  assert.equal(vm.media.contentType, "audio/mp4");

  const fileId = newId();
  const filePath = `chat_attachments/${DIRECT}/${fileId}/plan.docx`;
  await upload(
    filePath,
    DOCX,
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "student1",
  );
  const file = await send("student1", {
    conversationId: DIRECT,
    messageId: fileId,
    type: "file",
    media: { storagePath: filePath, fileName: "خطة الحفظ.docx" },
  });
  assert.equal(file.status, 200, JSON.stringify(file.body));
  const c = await conv(DIRECT);
  assert.equal(c.lastMessage, "ملف");
  assert.equal(c.lastMessageType, "file");
  assert.equal(c.unreadCounts.teacher1, 2);
});

// ── Edit ─────────────────────────────────────────────────────────────────────

test("edit: sender only, text only, length-checked, preview follows last message", async () => {
  const id = newId();
  await send("student1", { conversationId: DIRECT, messageId: id, text: "قبل" });

  const byOther = await call("editChatMessage", { conversationId: DIRECT, messageId: id, text: "x" }, "teacher1");
  assert.equal(byOther.code, "PERMISSION_DENIED");
  const tooLong = await call(
    "editChatMessage",
    { conversationId: DIRECT, messageId: id, text: "a".repeat(4001) },
    "student1",
  );
  assert.equal(tooLong.code, "INVALID_ARGUMENT");

  const ok = await call("editChatMessage", { conversationId: DIRECT, messageId: id, text: "بعد" }, "student1");
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  const m = (await msg(DIRECT, id)).data();
  assert.equal(m.text, "بعد");
  assert.ok(m.editedAt instanceof admin.firestore.Timestamp);
  assert.equal(m.senderId, "student1");
  assert.equal((await conv(DIRECT)).lastMessage, "بعد");

  const imgId = newId();
  const path = `chat_media/${DIRECT}/${imgId}/a.jpg`;
  await upload(path, JPEG, "image/jpeg", "student1");
  await send("student1", { conversationId: DIRECT, messageId: imgId, type: "image", media: { storagePath: path } });
  const editMedia = await call(
    "editChatMessage",
    { conversationId: DIRECT, messageId: imgId, text: "caption" },
    "student1",
  );
  assert.equal(editMedia.code, "FAILED_PRECONDITION");
});

test("edit window: messages older than the window cannot be edited", async () => {
  await db.doc(`conversations/${DIRECT}/messages/oldMessage001`).set({
    senderId: "student1",
    type: "text",
    text: "old",
    deleted: false,
    sentAt: admin.firestore.Timestamp.fromMillis(Date.now() - 16 * 60 * 1000),
  });
  const res = await call(
    "editChatMessage",
    { conversationId: DIRECT, messageId: "oldMessage001", text: "new" },
    "student1",
  );
  assert.equal(res.code, "PERMISSION_DENIED");
});

// ── Soft delete ──────────────────────────────────────────────────────────────

test("delete: sender soft-deletes media; metadata stripped; preview updated; not repeatable", async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/a.jpg`;
  await upload(path, JPEG, "image/jpeg", "teacher1");
  await send("teacher1", { conversationId: DIRECT, messageId: id, type: "image", media: { storagePath: path } });

  const byOther = await call("softDeleteChatMessage", { conversationId: DIRECT, messageId: id }, "student1");
  assert.equal(byOther.code, "PERMISSION_DENIED");

  const ok = await call("softDeleteChatMessage", { conversationId: DIRECT, messageId: id }, "teacher1");
  assert.equal(ok.status, 200, JSON.stringify(ok.body));
  const m = (await msg(DIRECT, id)).data();
  assert.equal(m.deleted, true);
  assert.equal(m.deletedBy, "teacher1");
  assert.equal(m.text, "");
  assert.equal(m.media, undefined, "deleted message must not expose media metadata");
  assert.equal((await conv(DIRECT)).lastMessage, "تم حذف هذه الرسالة");
  const [stillStored] = await bucket.file(path).exists();
  assert.equal(stillStored, true, "object retained for Admin moderation (retention policy D20)");

  const again = await call("softDeleteChatMessage", { conversationId: DIRECT, messageId: id }, "teacher1");
  assert.equal(again.code, "PERMISSION_DENIED");
  const editDeleted = await call(
    "editChatMessage",
    { conversationId: DIRECT, messageId: id, text: "x" },
    "teacher1",
  );
  assert.equal(editDeleted.code, "PERMISSION_DENIED");
});

test("delete: Admin may moderate-delete; older message delete keeps the latest preview", async () => {
  const older = newId();
  const newer = newId();
  await send("student1", { conversationId: DIRECT, messageId: older, text: "أول" });
  await send("student1", { conversationId: DIRECT, messageId: newer, text: "ثاني" });
  const res = await call("softDeleteChatMessage", { conversationId: DIRECT, messageId: older }, "admin1");
  assert.equal(res.status, 200, JSON.stringify(res.body));
  assert.equal((await msg(DIRECT, older)).data().deletedBy, "admin1");
  assert.equal((await conv(DIRECT)).lastMessage, "ثاني");
});

test("sendChatMessage is served only in the client region", async () => {
  if (CLIENT_REGION === "us-central1") return;
  const res = await call(
    "sendChatMessage",
    { conversationId: DIRECT, messageId: newId(), text: "x" },
    "student1",
    "us-central1",
  );
  assert.notEqual(res.status, 200);
});

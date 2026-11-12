/**
 * Admin messaging journeys against the Firestore + Storage emulators:
 * direct conversation with replies, reactions, edit and the delete window
 * (journey 9); an Admin-managed dynamic group (10) whose media, documents
 * and links are listed from message references (11); and member removal
 * that drops the member from the group server-side (12). Storage/Firestore
 * read revocation is covered by rules_test/admin_messaging.storage.rules.test.mjs.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore,storage \
 *     "node --test --test-concurrency=1 functions/test/admin_messaging.emulator.test.mjs"
 */
import assert from "node:assert/strict";
import test from "node:test";
import { randomBytes } from "node:crypto";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const PROJECT_ID = process.env.RULES_TEST_PROJECT_ID ?? "demo-rafiq-rules";
const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;

if (!FIRESTORE || !STORAGE || !PROJECT_ID.startsWith("demo-")) {
  throw new Error("messaging suite requires firestore + storage emulators and a demo- project id");
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require("firebase-admin");
admin.initializeApp({ projectId: PROJECT_ID, storageBucket: `${PROJECT_ID}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket();
const { Timestamp } = require("firebase-admin/firestore");

const auth = require("../lib/chat/chatAuthFunctions.js");
const groups = require("../lib/chat/chatGroupFunctions.js");
const messages = require("../lib/chat/chatMessageFunctions.js");

const ADMIN = "am_admin";
const TEACHER = "am_teacher";
const PARENT = "am_parent";
const SUPERVISOR = "am_supervisor";
const STUDENT = "am_student";

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1, 0xff, 0xd9]);
const PDF = Buffer.from("%PDF-1.7\n%âãÏÓ\n1 0 obj\n<<>>\nendobj\n", "latin1");

const msgId = () => `M${randomBytes(8).toString("hex")}`;
const reqId = () => `grp_${randomBytes(8).toString("hex")}`;
const send = (uid, data) => messages.sendChatMessageCore({ db, bucket }, uid, data);
const data = async (path) => (await db.doc(path).get()).data();

async function rejects(promise, code) {
  await assert.rejects(promise, (e) => {
    assert.equal(e.code, code, `expected ${code}, got ${e.code}: ${e.message}`);
    return true;
  });
}

async function clearAll() {
  const res = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  assert.equal(res.ok, true, "firestore clear failed");
  const [files] = await bucket.getFiles();
  await Promise.all(files.map((f) => f.delete()));
}

test.beforeEach(async () => {
  await clearAll();
  const batch = db.batch();
  const user = (name, role) => ({ name, role, isActive: true });
  batch.set(db.doc(`users/${ADMIN}`), user("المدير", "admin"));
  batch.set(db.doc(`users/${TEACHER}`), user("الأستاذ أحمد", "teacher"));
  batch.set(db.doc(`users/${PARENT}`), user("ولي الأمر", "parent"));
  batch.set(db.doc(`users/${SUPERVISOR}`), user("المشرف", "supervisor"));
  batch.set(db.doc(`users/${STUDENT}`), user("الطالب", "student"));
  await batch.commit();
});

async function upload(path, bytes, contentType, uploaderId) {
  await bucket.file(path).save(bytes, {
    contentType,
    metadata: { metadata: { uploaderId } },
    resumable: false,
  });
}

test("journey 9: direct conversation with replies, reactions, edit and the delete window", async () => {
  const opened = await auth.createDirectConversationCore(db, ADMIN, { otherUid: TEACHER });
  assert.equal(opened.created, true);
  const again = await auth.createDirectConversationCore(db, TEACHER, { otherUid: ADMIN });
  assert.deepEqual([again.conversationId, again.created], [opened.conversationId, false]);
  await rejects(auth.createDirectConversationCore(db, ADMIN, { otherUid: STUDENT }), "permission-denied");
  const conv = opened.conversationId;

  const first = msgId();
  await send(TEACHER, { conversationId: conv, messageId: first, text: "السلام عليكم" });
  const reply = msgId();
  await send(ADMIN, { conversationId: conv, messageId: reply, text: "وعليكم السلام", replyToMessageId: first });
  const replyDoc = await data(`conversations/${conv}/messages/${reply}`);
  assert.deepEqual(replyDoc.replyTo, {
    messageId: first,
    senderId: TEACHER,
    type: "text",
    preview: "السلام عليكم",
  });
  await rejects(
    send(ADMIN, { conversationId: conv, messageId: msgId(), text: "x", replyToMessageId: "Mmissing00000" }),
    "not-found",
  );

  const react = (uid, reaction) =>
    groups.reactToChatMessageCore(db, uid, { conversationId: conv, messageId: first, reaction });
  await react(ADMIN, "heart");
  await react(TEACHER, "like");
  await react(ADMIN, "laugh");
  assert.deepEqual((await data(`conversations/${conv}/messages/${first}`)).reactions, {
    [ADMIN]: "laugh",
    [TEACHER]: "like",
  });
  await react(ADMIN, null);
  assert.deepEqual((await data(`conversations/${conv}/messages/${first}`)).reactions, { [TEACHER]: "like" });
  await rejects(react(ADMIN, "angry"), "invalid-argument");
  await rejects(react(PARENT, "like"), "permission-denied");

  await auth.editChatMessageCore(db, TEACHER, { conversationId: conv, messageId: first, text: "السلام عليكم ورحمة الله" });
  await rejects(
    auth.editChatMessageCore(db, ADMIN, { conversationId: conv, messageId: first, text: "تعديل" }),
    "permission-denied",
  );

  // A two-hour-old message: past the sender's delete window, Admin may still moderate.
  const old = msgId();
  await db.doc(`conversations/${conv}/messages/${old}`).set({
    senderId: TEACHER,
    type: "text",
    text: "قديمة",
    deleted: false,
    sentAt: Timestamp.fromMillis(Date.now() - 2 * 60 * 60 * 1000),
  });
  await rejects(auth.softDeleteChatMessageCore(db, TEACHER, { conversationId: conv, messageId: old }), "permission-denied");
  await rejects(
    auth.editChatMessageCore(db, TEACHER, { conversationId: conv, messageId: old, text: "تعديل" }),
    "permission-denied",
  );
  await auth.softDeleteChatMessageCore(db, ADMIN, { conversationId: conv, messageId: old });
  assert.equal((await data(`conversations/${conv}/messages/${old}`)).deleted, true);

  await auth.softDeleteChatMessageCore(db, TEACHER, { conversationId: conv, messageId: first });
  await rejects(react(ADMIN, "like"), "failed-precondition");
  const quoteDeleted = msgId();
  await send(ADMIN, { conversationId: conv, messageId: quoteDeleted, text: "رد", replyToMessageId: first });
  assert.equal(
    (await data(`conversations/${conv}/messages/${quoteDeleted}`)).replyTo.preview,
    "تم حذف هذه الرسالة",
  );
});

test("journeys 10-12: dynamic group, media by reference, member removal", async () => {
  await rejects(
    groups.adminCreateChatGroupCore(db, TEACHER, { requestId: reqId(), title: "فريق", memberIds: [PARENT] }),
    "permission-denied",
  );
  await rejects(
    groups.adminCreateChatGroupCore(db, ADMIN, { requestId: reqId(), title: "فريق", memberIds: [STUDENT] }),
    "failed-precondition",
  );

  const requestId = reqId();
  const create = {
    requestId,
    title: "أولياء أمور حلقة الفجر",
    description: "متابعة أسبوعية",
    memberIds: [TEACHER, PARENT, SUPERVISOR],
  };
  const made = await groups.adminCreateChatGroupCore(db, ADMIN, create);
  assert.equal(made.created, true);
  assert.deepEqual(await groups.adminCreateChatGroupCore(db, ADMIN, create), {
    conversationId: made.conversationId,
    created: false,
  });
  const group = made.conversationId;
  const doc = await data(`conversations/${group}`);
  assert.equal(doc.kind, "custom_group");
  assert.deepEqual([...doc.participantIds].sort(), [ADMIN, PARENT, SUPERVISOR, TEACHER].sort());
  assert.deepEqual(doc.groupAdminIds, [ADMIN]);
  assert.equal(doc.participants.find((p) => p.uid === TEACHER).name, "الأستاذ أحمد");

  await groups.adminUpdateChatGroupCore(db, ADMIN, {
    conversationId: group,
    title: "أولياء الأمور",
    imagePath: `chat_group_images/${group}/cover.jpg`,
  });
  await rejects(
    groups.adminUpdateChatGroupCore(db, ADMIN, { conversationId: group, imagePath: "profile_images/x/y.jpg" }),
    "invalid-argument",
  );
  assert.equal((await data(`conversations/${group}`)).title, "أولياء الأمور");

  // Journey 11: media, documents and links are listed from the messages
  // themselves; the library holds references, never copies.
  const imageId = msgId();
  const imagePath = `chat_media/${group}/${imageId}/photo.jpg`;
  await upload(imagePath, JPEG, "image/jpeg", TEACHER);
  await send(TEACHER, { conversationId: group, messageId: imageId, type: "image", text: "", media: { storagePath: imagePath } });
  const docId = msgId();
  const docPath = `chat_attachments/${group}/${docId}/plan.pdf`;
  await upload(docPath, PDF, "application/pdf", ADMIN);
  await send(ADMIN, { conversationId: group, messageId: docId, type: "file", text: "", media: { storagePath: docPath } });
  await send(PARENT, { conversationId: group, messageId: msgId(), text: "رابط الدرس https://example.org/lesson" });
  await send(PARENT, { conversationId: group, messageId: msgId(), text: "شكراً" });

  const msgs = db.collection(`conversations/${group}/messages`);
  const ofType = async (type) =>
    (await msgs.where("type", "==", type).orderBy("sentAt", "desc").get()).docs.map((d) => d.data());
  const media = await ofType("image");
  assert.deepEqual(media.map((m) => m.media.storagePath), [imagePath]);
  assert.deepEqual((await ofType("file")).map((m) => m.media.storagePath), [docPath]);
  const links = (await msgs.where("hasLink", "==", true).orderBy("sentAt", "desc").get()).docs;
  assert.equal(links.length, 1);
  const [files] = await bucket.getFiles();
  assert.deepEqual(files.map((f) => f.name).sort(), [docPath, imagePath].sort());

  // Journey 12: removal is server-side and immediate for new activity.
  await rejects(
    groups.adminSetChatGroupMembersCore(db, TEACHER, { conversationId: group, remove: [PARENT] }),
    "permission-denied",
  );
  const changed = await groups.adminSetChatGroupMembersCore(db, ADMIN, { conversationId: group, remove: [PARENT] });
  assert.equal(changed.participantIds.includes(PARENT), false);
  const after = await data(`conversations/${group}`);
  assert.equal(after.participantIds.includes(PARENT), false);
  assert.equal(after.participants.some((p) => p.uid === PARENT), false);
  assert.equal(Object.hasOwn(after.unreadCounts, PARENT), false);
  await rejects(send(PARENT, { conversationId: group, messageId: msgId(), text: "مرحبا" }), "permission-denied");
  await rejects(
    groups.reactToChatMessageCore(db, PARENT, { conversationId: group, messageId: imageId, reaction: "like" }),
    "permission-denied",
  );
  await rejects(
    groups.adminSetChatGroupMembersCore(db, ADMIN, { conversationId: group, add: [STUDENT] }),
    "failed-precondition",
  );
  await rejects(
    groups.adminSetChatGroupMembersCore(db, ADMIN, { conversationId: group, remove: [TEACHER, SUPERVISOR, ADMIN] }),
    "failed-precondition",
  );
  await groups.adminSetChatGroupMembersCore(db, ADMIN, { conversationId: group, add: [PARENT] });
  assert.equal((await data(`conversations/${group}`)).unreadCounts[PARENT], 0);

  const audits = (await db.collection("auditLogs").where("targetId", "==", group).get()).docs.map((d) => d.data());
  assert.deepEqual(
    audits.map((a) => a.action).sort(),
    ["chat_group_create", "chat_group_members_change", "chat_group_members_change"],
  );
});

test("halaqa groups and direct chats are not Admin-editable through group management", async () => {
  const { conversationId } = await auth.createDirectConversationCore(db, ADMIN, { otherUid: PARENT });
  await rejects(
    groups.adminSetChatGroupMembersCore(db, ADMIN, { conversationId, add: [TEACHER] }),
    "failed-precondition",
  );
  await rejects(
    groups.adminCreateChatGroupCore(db, ADMIN, { requestId: "short", title: "فريق", memberIds: [TEACHER] }),
    "invalid-argument",
  );
  await rejects(
    groups.adminCreateChatGroupCore(db, ADMIN, { requestId: reqId(), title: "اتصل 01012345678", memberIds: [TEACHER] }),
    "invalid-argument",
  );
});

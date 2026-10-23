/**
 * WA-12 Storage Rules unit tests (C10 path ownership + catch-all denial).
 *
 * Requires Java + Firebase emulators (Storage + Firestore — Storage Rules
 * call firestore.get / exists).
 *
 * Run from repo root:
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only firestore,storage \
 *     "npm --prefix rules_test run test:storage"
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROJECT_ID } from './project_id.mjs';
import test from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const storageRules = readFileSync(
  join(__dirname, '..', 'storage.rules'),
  'utf8',
);
const firestoreRules = readFileSync(
  join(__dirname, '..', 'firestore.rules'),
  'utf8',
);

let testEnv;

function authedStorage(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

function unauthStorage() {
  return testEnv.unauthenticatedContext().storage();
}

async function seedFirestore(mutate) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await mutate(ctx.firestore());
  });
}

function jpegBytes() {
  // Minimal JPEG SOI/EOI — content-type set via metadata in put.
  return new Uint8Array([0xff, 0xd8, 0xff, 0xd9, 0x00, 0x01, 0x02, 0x03]);
}

async function putImage(ref) {
  return ref.put(jpegBytes(), { contentType: 'image/jpeg' });
}

async function putAudio(ref) {
  return ref.put(new Uint8Array([0x00, 0x01, 0x02, 0x03]), {
    contentType: 'audio/mpeg',
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await seedFirestore(async (db) => {
    await db.doc('users/parent1').set({
      name: 'Parent',
      role: 'parent',
      isActive: true,
    });
    await db.doc('users/parent2').set({
      name: 'Parent2',
      role: 'parent',
      isActive: true,
    });
    await db.doc('users/admin1').set({
      name: 'Admin',
      role: 'admin',
      isActive: true,
    });
    await db.doc('users/supervisor1').set({
      name: 'Supervisor',
      role: 'supervisor',
      isActive: true,
    });
    await db.doc('users/teacher1').set({
      name: 'Teacher',
      role: 'teacher',
      isActive: true,
    });
    await db.doc('users/student1').set({
      name: 'Student',
      role: 'student',
      isActive: true,
    });
    await db.doc('users/stranger').set({
      name: 'Stranger',
      role: 'student',
      isActive: true,
    });
    await db.doc('payments/pay1').set({
      parentId: 'parent1',
      studentId: 'student1',
      status: 'unpaid',
      amount: 100,
    });
    await db.doc('payments/pay2').set({
      parentId: 'parent2',
      studentId: 'student2',
      status: 'unpaid',
      amount: 50,
    });
    await db.doc('conversations/student1_teacher1').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher1'],
    });
    await db.doc('conversations/halaqa_group_h1').set({
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1', 'student1'],
    });
  });
});

// ── Catch-all / default deny ────────────────────────────────────────────────

test('WA-12 unauthenticated cannot read/write unspecified path', async () => {
  const s = unauthStorage();
  await assertFails(s.ref('secret/x.bin').getDownloadURL());
  await assertFails(putImage(s.ref('secret/x.jpg')));
});

test('WA-12 authenticated cannot read/write unspecified path', async () => {
  const s = authedStorage('admin1');
  await assertFails(putImage(s.ref('random/path/file.jpg')));
  await assertFails(s.ref('legacy_misc/admin1/1.jpg').getDownloadURL());
  await assertFails(putImage(s.ref('orphan_uploads/admin1/1.pdf')));
});

// ── Payment proofs ──────────────────────────────────────────────────────────

test('WA-12 parent can write and read own payment proof', async () => {
  const s = authedStorage('parent1');
  const ref = s.ref('payment_proofs/parent1/pay1/a.jpg');
  await assertSucceeds(putImage(ref));
  await assertSucceeds(ref.getDownloadURL());
});

test('WA-12 parent cannot write another parent proof path', async () => {
  const s = authedStorage('parent1');
  await assertFails(putImage(s.ref('payment_proofs/parent2/pay2/a.jpg')));
});

test('WA-12 parent cannot write proof for foreign paymentId under own parentId', async () => {
  const s = authedStorage('parent1');
  // pay2 belongs to parent2 in Firestore
  await assertFails(putImage(s.ref('payment_proofs/parent1/pay2/sneak.jpg')));
});

test('WA-12 parent cannot read another parent proof', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .storage()
      .ref('payment_proofs/parent2/pay2/b.jpg')
      .put(jpegBytes(), { contentType: 'image/jpeg' });
  });
  const s = authedStorage('parent1');
  await assertFails(s.ref('payment_proofs/parent2/pay2/b.jpg').getDownloadURL());
});

test('WA-12 supervisor and admin can read payment proof', async () => {
  // PH-01 / C4.7: the supervisor must supervise the invoice's student.
  await seedFirestore(async (db) => {
    await db.doc('halaqat/h1').set({
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
    });
    await db.doc('studentProfiles/student1').set({ halaqaId: 'h1' });
  });
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .storage()
      .ref('payment_proofs/parent1/pay1/c.jpg')
      .put(jpegBytes(), { contentType: 'image/jpeg' });
  });
  await assertSucceeds(
    authedStorage('supervisor1')
      .ref('payment_proofs/parent1/pay1/c.jpg')
      .getDownloadURL(),
  );
  await assertSucceeds(
    authedStorage('admin1')
      .ref('payment_proofs/parent1/pay1/c.jpg')
      .getDownloadURL(),
  );
});

test('WA-12 unauthorized student cannot read payment proof', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .storage()
      .ref('payment_proofs/parent1/pay1/d.jpg')
      .put(jpegBytes(), { contentType: 'image/jpeg' });
  });
  await assertFails(
    authedStorage('student1')
      .ref('payment_proofs/parent1/pay1/d.jpg')
      .getDownloadURL(),
  );
});

test('WA-12 client cannot delete payment proof', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .storage()
      .ref('payment_proofs/parent1/pay1/e.jpg')
      .put(jpegBytes(), { contentType: 'image/jpeg' });
  });
  await assertFails(
    authedStorage('parent1').ref('payment_proofs/parent1/pay1/e.jpg').delete(),
  );
  await assertFails(
    authedStorage('admin1').ref('payment_proofs/parent1/pay1/e.jpg').delete(),
  );
});

test('WA-12 parent cannot upload proof for missing payment', async () => {
  await assertFails(
    putImage(
      authedStorage('parent1').ref('payment_proofs/parent1/missing/x.jpg'),
    ),
  );
});

// ── Profile images ──────────────────────────────────────────────────────────

test('WA-12 user can write own profile image; not another user', async () => {
  await assertSucceeds(
    putImage(authedStorage('teacher1').ref('profile_images/teacher1/a.jpg')),
  );
  await assertFails(
    putImage(authedStorage('teacher1').ref('profile_images/student1/a.jpg')),
  );
});

test('WA-12 signed-in users can read profile images', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .storage()
      .ref('profile_images/teacher1/a.jpg')
      .put(jpegBytes(), { contentType: 'image/jpeg' });
  });
  await assertSucceeds(
    authedStorage('student1')
      .ref('profile_images/teacher1/a.jpg')
      .getDownloadURL(),
  );
  await assertFails(
    unauthStorage().ref('profile_images/teacher1/a.jpg').getDownloadURL(),
  );
});

// ── Chat media / voice ──────────────────────────────────────────────────────

// Upload precedes sendChatMessage; reads require a live message whose
// server-written media.storagePath equals the object path.

function chatPut(uid, path, contentType, uploaderId = uid, bytes = jpegBytes()) {
  return authedStorage(uid)
    .ref(path)
    .put(bytes, { contentType, customMetadata: { uploaderId } });
}

async function seedChatObject(path, contentType, uploaderId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(path).put(jpegBytes(), {
      contentType,
      customMetadata: { uploaderId },
    });
  });
}

async function seedChatMessage(conversationId, messageId, data) {
  await seedFirestore(async (db) => {
    await db
      .doc(`conversations/${conversationId}/messages/${messageId}`)
      .set({ sentAt: new Date(), deleted: false, ...data });
  });
}

test('Chat storage: participant uploads with own uploaderId; stranger and spoofed uploader denied', async () => {
  const path = 'chat_media/student1_teacher1/upImgAaaaa01/photo.jpg';
  await assertFails(chatPut('stranger', path, 'image/jpeg'));
  await assertFails(chatPut('teacher1', path, 'image/jpeg', 'student1'));
  await assertFails(
    putImage(authedStorage('teacher1').ref(path)), // no uploaderId metadata
  );
  await assertSucceeds(chatPut('teacher1', path, 'image/jpeg'));
});

test('Chat storage: knowing conversationId alone is insufficient (Parent not in group)', async () => {
  const path = 'chat_media/halaqa_group_h1/grpImgAaaa01/x.jpg';
  await assertFails(chatPut('parent1', path, 'image/jpeg'));
  await seedChatObject(path, 'image/jpeg', 'teacher1');
  await seedChatMessage('halaqa_group_h1', 'grpImgAaaa01', {
    senderId: 'teacher1',
    type: 'image',
    media: { storagePath: path },
  });
  await assertFails(authedStorage('parent1').ref(path).getDownloadURL());
  await assertSucceeds(authedStorage('student1').ref(path).getDownloadURL());
});

test('Chat storage: unsent upload is not readable by the other participant', async () => {
  const path = 'chat_media/student1_teacher1/orphanRead01/photo.jpg';
  await seedChatObject(path, 'image/jpeg', 'teacher1');
  await assertFails(authedStorage('student1').ref(path).getDownloadURL());
  await assertSucceeds(authedStorage('admin1').ref(path).getDownloadURL());
});

test('Chat storage: message must reference this exact path', async () => {
  const path = 'chat_media/student1_teacher1/mismatch0001/real.jpg';
  const other = 'chat_media/student1_teacher1/mismatch0001/other.jpg';
  await seedChatObject(path, 'image/jpeg', 'teacher1');
  await seedChatObject(other, 'image/jpeg', 'teacher1');
  await seedChatMessage('student1_teacher1', 'mismatch0001', {
    senderId: 'teacher1',
    type: 'image',
    media: { storagePath: path },
  });
  await assertSucceeds(authedStorage('student1').ref(path).getDownloadURL());
  await assertFails(authedStorage('student1').ref(other).getDownloadURL());
  await assertFails(authedStorage('stranger').ref(path).getDownloadURL());
});

test('Chat storage: deleted message media hidden from participants; Admin retains moderation read', async () => {
  const path = 'chat_media/student1_teacher1/deletedImg01/photo.jpg';
  await seedChatObject(path, 'image/jpeg', 'teacher1');
  await seedChatMessage('student1_teacher1', 'deletedImg01', {
    senderId: 'teacher1',
    type: 'image',
    deleted: true,
    media: { storagePath: path },
  });
  await assertFails(authedStorage('student1').ref(path).getDownloadURL());
  await assertFails(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertSucceeds(authedStorage('admin1').ref(path).getDownloadURL());
});

test('Chat storage: no upload for an already-sent messageId and no overwrite', async () => {
  const sentPath = 'chat_media/student1_teacher1/alreadySent1/new.jpg';
  await seedChatMessage('student1_teacher1', 'alreadySent1', {
    senderId: 'teacher1',
    type: 'text',
    text: 'hi',
  });
  await assertFails(chatPut('teacher1', sentPath, 'image/jpeg'));

  const path = 'chat_media/student1_teacher1/overwrite001/a.jpg';
  await seedChatObject(path, 'image/jpeg', 'teacher1');
  await assertFails(chatPut('teacher1', path, 'image/jpeg'));
});

test('Chat storage: type allow-lists per folder', async () => {
  const conv = 'chat_media/student1_teacher1';
  await assertFails(chatPut('teacher1', `${conv}/typeImgGif01/a.gif`, 'image/gif'));
  await assertFails(chatPut('teacher1', `${conv}/typeImgSvg01/a.svg`, 'image/svg+xml'));
  await assertSucceeds(chatPut('teacher1', `${conv}/typeImgPng01/a.png`, 'image/png'));

  const voice = 'chat_voice/student1_teacher1';
  await assertSucceeds(chatPut('student1', `${voice}/typeVoiceM41/v.m4a`, 'audio/mp4'));
  await assertFails(chatPut('student1', `${voice}/typeVoiceTx1/v.txt`, 'text/plain'));

  const files = 'chat_attachments/student1_teacher1';
  await assertSucceeds(chatPut('student1', `${files}/typeFilePdf1/a.pdf`, 'application/pdf'));
  await assertSucceeds(
    chatPut(
      'student1',
      `${files}/typeFileDcx1/a.docx`,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ),
  );
  await assertFails(chatPut('student1', `${files}/typeFileExe1/a.exe`, 'application/x-msdownload'));
  await assertFails(chatPut('student1', `${files}/typeFileHtm1/a.html`, 'text/html'));
  await assertFails(chatPut('student1', `${files}/typeFileImg1/a.jpg`, 'image/jpeg'));
});

test('Chat storage: size ceilings enforced', async () => {
  const big = new Uint8Array(10 * 1024 * 1024);
  await assertFails(
    chatPut('teacher1', 'chat_media/student1_teacher1/bigImage0001/a.jpg', 'image/jpeg', 'teacher1', big),
  );
  await assertFails(
    chatPut('teacher1', 'chat_attachments/student1_teacher1/bigFile00001/a.pdf', 'application/pdf', 'teacher1', big),
  );
});

test('Chat storage: malformed messageId path rejected', async () => {
  await assertFails(chatPut('teacher1', 'chat_media/student1_teacher1/m1/a.jpg', 'image/jpeg'));
});

test('Chat storage: uploader deletes own orphan; not others, not once sent', async () => {
  const orphan = 'chat_voice/student1_teacher1/orphanDel001/v.m4a';
  await seedChatObject(orphan, 'audio/mp4', 'student1');
  await assertFails(authedStorage('teacher1').ref(orphan).delete());
  await assertSucceeds(authedStorage('student1').ref(orphan).delete());

  const sent = 'chat_voice/student1_teacher1/sentNoDel001/v.m4a';
  await seedChatObject(sent, 'audio/mp4', 'student1');
  await seedChatMessage('student1_teacher1', 'sentNoDel001', {
    senderId: 'student1',
    type: 'voice',
    media: { storagePath: sent },
  });
  await assertFails(authedStorage('student1').ref(sent).delete());
  await assertFails(authedStorage('admin1').ref(sent).delete());
});

test('Chat storage: nonexistent conversation and Admin non-member upload denied', async () => {
  await assertFails(
    chatPut('teacher1', 'chat_media/does_not_exist/noConvImg01/x.jpg', 'image/jpeg'),
  );
  await assertFails(
    chatPut('admin1', 'chat_voice/student1_teacher1/adminVoice01/v.m4a', 'audio/mp4'),
  );
});

test('Chat storage: deactivated Admin loses moderation read', async () => {
  const path = 'chat_media/student1_teacher1/inactiveAdm1/photo.jpg';
  await seedFirestore(async (db) => {
    await db.doc('users/admin9').set({ role: 'admin', isActive: false });
  });
  await seedChatObject(path, 'image/jpeg', 'teacher1');
  await assertFails(authedStorage('admin9').ref(path).getDownloadURL());
});

// ── Recitations gated ───────────────────────────────────────────────────────

test('WA-12 recitation write/read remain denied while gated OFF', async () => {
  const path = 'recitations/student1/asg1/task1_1.m4a';
  await assertFails(putAudio(authedStorage('student1').ref(path)));
  await assertFails(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertFails(authedStorage('admin1').ref(path).getDownloadURL());
});

// ── posts/ ──────────────────────────────────────────────────────────────────

// Legacy posts/{authorId}/… is closed for writes; Halaqa-scoped
// posts/{halaqaId}/{postId}/… is covered by media_hardening.storage.rules.test.mjs.
async function legacyPostPut(path) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(path).put(jpegBytes(), { contentType: 'image/jpeg' });
  });
}

test('WA-12 posts (legacy): no new uploads; author/Admin read only', async () => {
  const path = 'posts/teacher1/1.jpg';
  await assertFails(putImage(unauthStorage().ref(path)));
  await assertFails(putImage(authedStorage('teacher1').ref(path)));
  await legacyPostPut(path);
  await assertSucceeds(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertSucceeds(authedStorage('admin1').ref(path).getDownloadURL());
  await assertFails(authedStorage('student1').ref(path).getDownloadURL());
  await assertFails(unauthStorage().ref(path).getDownloadURL());
});

test('WA-12 posts (legacy): other user create denied; overwrite/delete denied', async () => {
  const path = 'posts/teacher1/2.jpg';
  await assertFails(putImage(authedStorage('student1').ref(path)));
  await legacyPostPut(path);
  await assertFails(
    authedStorage('teacher1').ref(path).put(jpegBytes(), { contentType: 'image/jpeg' }),
  );
  await assertFails(authedStorage('teacher1').ref(path).delete());
  await assertFails(authedStorage('admin1').ref(path).delete());
});

// ── content/ ────────────────────────────────────────────────────────────────

// P0 §8: legacy content/ is closed for writes (new uploads go to
// content_library/{halaqaId}/…, covered by p0_storage.rules.test.mjs).
async function legacyContentPut(path) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(path).put(jpegBytes(), { contentType: 'image/jpeg' });
  });
}

test('WA-12 content (legacy): no new uploads; uploader/Admin read only', async () => {
  const path = 'content/teacher1/doc1.pdf';
  await assertFails(putImage(unauthStorage().ref(path)));
  await assertFails(putImage(authedStorage('teacher1').ref(path)));
  await legacyContentPut(path);
  await assertSucceeds(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertFails(authedStorage('student1').ref(path).getDownloadURL());
  await assertFails(putImage(authedStorage('student1').ref(path)));
});

test('WA-12 content (legacy): owner delete allowed; other delete denied; overwrite denied', async () => {
  const path = 'content/teacher1/doc2.pdf';
  await legacyContentPut(path);
  await assertFails(authedStorage('student1').ref(path).delete());
  await assertFails(
    authedStorage('teacher1').ref(path).put(jpegBytes(), { contentType: 'image/jpeg' }),
  );
  await assertSucceeds(authedStorage('teacher1').ref(path).delete());
});

// ── halaqa_activities/ ──────────────────────────────────────────────────────

test('WA-12 halaqa_activities: student images allowed with assignment+roster', async () => {
  await seedFirestore(async (db) => {
    await db.doc('halaqat/h1').set({
      teacherId: 'teacher1',
      studentIds: ['student1'],
      name: 'حلقة',
    });
    await db.doc('assignments/act1').set({
      kind: 'halaqa_activity',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
    });
  });
  const path = 'halaqa_activities/act1/student1/images/a.jpg';
  await assertFails(putImage(unauthStorage().ref(path)));
  await assertSucceeds(putImage(authedStorage('student1').ref(path)));
  await assertSucceeds(authedStorage('teacher1').ref(path).getDownloadURL());
});

test('WA-12 halaqa_activities: wrong student / not on roster / missing assignment denied', async () => {
  await seedFirestore(async (db) => {
    await db.doc('halaqat/h1').set({
      teacherId: 'teacher1',
      studentIds: ['student1'],
    });
    await db.doc('assignments/act1').set({
      kind: 'halaqa_activity',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
    });
    await db.doc('halaqat/h2').set({
      teacherId: 'teacher1',
      studentIds: ['stranger'],
    });
    await db.doc('assignments/act2').set({
      kind: 'halaqa_activity',
      halaqaId: 'h2',
      assignedBy: 'teacher1',
    });
  });
  await assertFails(
    putImage(
      authedStorage('stranger').ref(
        'halaqa_activities/act1/student1/images/x.jpg',
      ),
    ),
  );
  await assertFails(
    putImage(
      authedStorage('stranger').ref(
        'halaqa_activities/act1/stranger/images/x.jpg',
      ),
    ),
  );
  await assertFails(
    putImage(
      authedStorage('student1').ref(
        'halaqa_activities/missing/student1/images/x.jpg',
      ),
    ),
  );
});

test('WA-12 halaqa_activities: missing halaqaId fail-closed; unsupported folder / audio denied', async () => {
  await seedFirestore(async (db) => {
    await db.doc('halaqat/h1').set({
      teacherId: 'teacher1',
      studentIds: ['student1'],
    });
    await db.doc('assignments/act_bad').set({
      kind: 'halaqa_activity',
      assignedBy: 'teacher1',
      // no halaqaId
    });
    await db.doc('assignments/act1').set({
      kind: 'halaqa_activity',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
    });
  });
  await assertFails(
    putImage(
      authedStorage('student1').ref(
        'halaqa_activities/act_bad/student1/images/x.jpg',
      ),
    ),
  );
  await assertFails(
    putImage(
      authedStorage('student1').ref(
        'halaqa_activities/act1/student1/other/x.jpg',
      ),
    ),
  );
  await assertFails(
    putAudio(
      authedStorage('student1').ref(
        'halaqa_activities/act1/student1/audio/x.m4a',
      ),
    ),
  );
});

test('WA-12 halaqa_activities: owner overwrite/update/delete denied; scoped read only', async () => {
  await seedFirestore(async (db) => {
    await db.doc('halaqat/h1').set({
      teacherId: 'teacher1',
      studentIds: ['student1', 'classmate'],
    });
    await db.doc('users/classmate').set({
      name: 'Classmate',
      role: 'student',
      isActive: true,
    });
    await db.doc('assignments/act1').set({
      kind: 'halaqa_activity',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
    });
  });
  const path = 'halaqa_activities/act1/student1/images/z.jpg';
  await assertSucceeds(putImage(authedStorage('student1').ref(path)));
  // PH-01: shared thread is roster-scoped, not every signed-in user.
  await assertSucceeds(authedStorage('classmate').ref(path).getDownloadURL());
  await assertSucceeds(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertFails(authedStorage('stranger').ref(path).getDownloadURL());
  await assertFails(authedStorage('student1').ref(path).delete());
  await assertFails(
    authedStorage('student1').ref(path).put(jpegBytes(), {
      contentType: 'image/jpeg',
    }),
  );
});

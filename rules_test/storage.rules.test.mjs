/**
 * WA-12 Storage Rules unit tests (C10 path ownership + catch-all denial).
 *
 * Requires Java + Firebase emulators (Storage + Firestore — Storage Rules
 * call firestore.get / exists).
 *
 * Run from repo root:
 *   npx firebase emulators:exec --project demo-rafiq-wa12 \
 *     --only firestore,storage \
 *     "npm --prefix rules_test run test:storage"
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
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
    projectId: 'demo-rafiq-wa12',
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

test('WA-12 participant can write/read chat media; stranger denied', async () => {
  const path = 'chat_media/student1_teacher1/m1/photo.jpg';
  await assertSucceeds(putImage(authedStorage('teacher1').ref(path)));
  await assertSucceeds(authedStorage('student1').ref(path).getDownloadURL());
  await assertFails(putImage(authedStorage('stranger').ref(path)));
  await assertFails(authedStorage('stranger').ref(path).getDownloadURL());
});

test('WA-12 knowing conversationId alone is insufficient for media', async () => {
  const path = 'chat_media/halaqa_group_h1/m9/x.jpg';
  await assertFails(putImage(authedStorage('parent1').ref(path)));
  await assertFails(authedStorage('parent1').ref(path).getDownloadURL());
});

test('WA-12 Admin can monitor chat media read', async () => {
  const path = 'chat_media/student1_teacher1/m2/photo.jpg';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(path).put(jpegBytes(), { contentType: 'image/jpeg' });
  });
  await assertSucceeds(authedStorage('admin1').ref(path).getDownloadURL());
  await assertFails(putImage(authedStorage('admin1').ref(path)));
});

test('WA-12 nonexistent conversation media denied', async () => {
  await assertFails(
    putImage(
      authedStorage('teacher1').ref('chat_media/does_not_exist/m1/x.jpg'),
    ),
  );
});

test('WA-12 chat voice participant write/read; stranger denied', async () => {
  const path = 'chat_voice/student1_teacher1/m1/clip.mp3';
  await assertSucceeds(putAudio(authedStorage('student1').ref(path)));
  await assertSucceeds(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertFails(putAudio(authedStorage('stranger').ref(path)));
  await assertFails(authedStorage('stranger').ref(path).getDownloadURL());
});

test('WA-12 Admin can read chat voice; cannot create as non-participant', async () => {
  const path = 'chat_voice/student1_teacher1/m2/clip.mp3';
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.storage().ref(path).put(new Uint8Array([1, 2, 3]), {
      contentType: 'audio/mpeg',
    });
  });
  await assertSucceeds(authedStorage('admin1').ref(path).getDownloadURL());
  await assertFails(putAudio(authedStorage('admin1').ref(path)));
});

// ── Recitations gated ───────────────────────────────────────────────────────

test('WA-12 recitation write/read remain denied while gated OFF', async () => {
  const path = 'recitations/student1/asg1/task1_1.m4a';
  await assertFails(putAudio(authedStorage('student1').ref(path)));
  await assertFails(authedStorage('teacher1').ref(path).getDownloadURL());
  await assertFails(authedStorage('admin1').ref(path).getDownloadURL());
});

// ── posts/ ──────────────────────────────────────────────────────────────────

test('WA-12 posts: unauthenticated create denied; owner create/read allowed', async () => {
  const path = 'posts/teacher1/1.jpg';
  await assertFails(putImage(unauthStorage().ref(path)));
  await assertSucceeds(putImage(authedStorage('teacher1').ref(path)));
  await assertSucceeds(authedStorage('student1').ref(path).getDownloadURL());
});

test('WA-12 posts: different user create denied; owner overwrite/update/delete denied', async () => {
  const path = 'posts/teacher1/2.jpg';
  await assertFails(putImage(authedStorage('student1').ref(path)));
  // Owner initial create allowed.
  await assertSucceeds(putImage(authedStorage('teacher1').ref(path)));
  // Same owner overwrite of existing object denied (create requires resource == null).
  await assertFails(
    authedStorage('teacher1').ref(path).put(jpegBytes(), { contentType: 'image/jpeg' }),
  );
  await assertFails(authedStorage('teacher1').ref(path).delete());
});

// ── content/ ────────────────────────────────────────────────────────────────

test('WA-12 content: owner create/read; other create denied', async () => {
  const path = 'content/teacher1/doc1.pdf';
  await assertFails(putImage(unauthStorage().ref(path)));
  await assertSucceeds(putImage(authedStorage('teacher1').ref(path)));
  await assertSucceeds(authedStorage('student1').ref(path).getDownloadURL());
  await assertFails(putImage(authedStorage('student1').ref(path)));
});

test('WA-12 content: owner delete allowed; other delete denied; overwrite/update denied', async () => {
  const path = 'content/teacher1/doc2.pdf';
  await assertSucceeds(putImage(authedStorage('teacher1').ref(path)));
  await assertFails(authedStorage('student1').ref(path).delete());
  // Owner may delete once.
  await assertSucceeds(authedStorage('teacher1').ref(path).delete());
  // Recreate then deny overwrite (immutable create-only aside from owner delete).
  await assertSucceeds(putImage(authedStorage('teacher1').ref(path)));
  await assertFails(
    authedStorage('teacher1').ref(path).put(jpegBytes(), { contentType: 'image/jpeg' }),
  );
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

test('WA-12 halaqa_activities: owner overwrite/update/delete denied; authenticated read allowed', async () => {
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
  });
  const path = 'halaqa_activities/act1/student1/images/z.jpg';
  await assertSucceeds(putImage(authedStorage('student1').ref(path)));
  await assertSucceeds(authedStorage('stranger').ref(path).getDownloadURL());
  await assertFails(authedStorage('student1').ref(path).delete());
  await assertFails(
    authedStorage('student1').ref(path).put(jpegBytes(), {
      contentType: 'image/jpeg',
    }),
  );
});

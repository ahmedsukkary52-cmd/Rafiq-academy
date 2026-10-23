/**
 * Media hardening — Halaqa-scoped post attachments, payment-proof path
 * ownership, and image / attachment type + size limits (Storage Rules).
 *
 * Storage Rules call firestore.get / exists, so both emulators are required:
 *   npx firebase emulators:exec --project <demo-project> \
 *     --only firestore,storage "npm --prefix rules_test run test:media:storage"
 *
 * Rules only see the declared contentType and size, never the bytes, so
 * these tests cover declared-type enforcement (content sniffing is client-side).
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROJECT_ID } from './project_id.mjs';
import assert from 'node:assert/strict';
import test from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(join(__dirname, '..', name), 'utf8');

const MB = 1024 * 1024;

let testEnv;

const storageOf = (uid) => testEnv.authenticatedContext(uid).storage();
const anonStorage = () => testEnv.unauthenticatedContext().storage();

function bytes(size = 8) {
  const b = new Uint8Array(size);
  if (size >= 3) b.set([0xff, 0xd8, 0xff]);
  return b;
}

function put(ref, contentType, { size = 8, uploaderId } = {}) {
  const metadata = {};
  if (contentType !== undefined) metadata.contentType = contentType;
  if (uploaderId !== undefined) metadata.customMetadata = { uploaderId };
  return ref.put(bytes(size), metadata);
}

async function seedObject(path, contentType, uploaderId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await put(ctx.storage().ref(path), contentType, { uploaderId });
  });
}

async function seedDocs(docs) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
}

/// 20-char alphanumeric ids, as Firestore `doc()` generates.
function postId(tag) {
  const id = `Mh${tag}`.padEnd(20, 'x');
  assert.equal(id.length, 20);
  return id;
}

function postDoc(authorId, halaqaId) {
  return {
    authorId,
    halaqaId,
    audienceTarget: halaqaId,
    content: 'x',
    attachments: [],
  };
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: read('firestore.rules') },
    storage: { rules: read('storage.rules') },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  const user = (role) => ({ name: role, role, isActive: true });
  // Doc ids are unique to this file: the Storage emulator caches
  // cross-service reads across clearFirestore() calls.
  await seedDocs({
    'users/admin1': user('admin'),
    'users/teacher1': user('teacher'),
    'users/teacher2': user('teacher'),
    'users/supervisor1': user('supervisor'),
    'users/student1': user('student'),
    'users/student2': user('student'),
    'users/parent1': user('parent'),
    'users/parent2': user('parent'),
    'users/stranger': user('student'),
    'halaqat/mhH1': {
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
    },
    'halaqat/mhH2': {
      teacherId: 'teacher2',
      studentIds: ['student2'],
    },
    'parentProfiles/parent1': { childrenIds: ['student1'] },
    'parentProfiles/parent2': { childrenIds: ['student2'] },
    'studentProfiles/student1': { halaqaId: 'mhH1' },
    'payments/mhPay1': {
      parentId: 'parent1',
      studentId: 'student1',
      status: 'unpaid',
      amount: 100,
    },
    'payments/mhPay2': {
      parentId: 'parent2',
      studentId: 'student2',
      status: 'unpaid',
      amount: 50,
    },
    'assignments/mhAct1': {
      kind: 'halaqa_activity',
      halaqaId: 'mhH1',
      assignedBy: 'teacher1',
    },
  });
});

// ── Post attachments: posts/{halaqaId}/{postId}/{att_N.ext} ─────────────────

test('Posts: Halaqa staff upload with own uploaderId; others denied', async () => {
  const id = postId('Up');
  const path = `posts/mhH1/${id}/att_0.jpg`;
  await assertFails(put(anonStorage().ref(path), 'image/jpeg', { uploaderId: 'teacher1' }));
  await assertFails(put(storageOf('student1').ref(path), 'image/jpeg', { uploaderId: 'student1' }));
  await assertFails(put(storageOf('parent1').ref(path), 'image/jpeg', { uploaderId: 'parent1' }));
  // Staff of another Halaqa cannot target mhH1 (client-supplied halaqaId).
  await assertFails(put(storageOf('teacher2').ref(path), 'image/jpeg', { uploaderId: 'teacher2' }));
  // Spoofed / missing uploader stamp.
  await assertFails(put(storageOf('teacher1').ref(path), 'image/jpeg', { uploaderId: 'teacher2' }));
  await assertFails(put(storageOf('teacher1').ref(path), 'image/jpeg'));
  await assertSucceeds(put(storageOf('teacher1').ref(path), 'image/jpeg', { uploaderId: 'teacher1' }));
  // Supervisor of the Halaqa and Admin may also publish.
  await assertSucceeds(
    put(storageOf('supervisor1').ref(`posts/mhH1/${postId('Sup')}/att_0.png`), 'image/png', {
      uploaderId: 'supervisor1',
    }),
  );
  await assertSucceeds(
    put(storageOf('admin1').ref(`posts/mhH1/${postId('Adm')}/att_0.pdf`), 'application/pdf', {
      uploaderId: 'admin1',
    }),
  );
  // Admin still needs a real Halaqa.
  await assertFails(
    put(storageOf('admin1').ref(`posts/noSuchHalaqa/${postId('Adm2')}/att_0.pdf`), 'application/pdf', {
      uploaderId: 'admin1',
    }),
  );
});

test('Posts: no overwrite, no upload into an already-published post, malformed ids rejected', async () => {
  const id = postId('Ow');
  const path = `posts/mhH1/${id}/att_0.jpg`;
  await seedObject(path, 'image/jpeg', 'teacher1');
  await assertFails(put(storageOf('teacher1').ref(path), 'image/jpeg', { uploaderId: 'teacher1' }));

  const published = postId('Pub');
  await seedDocs({ [`posts/${published}`]: postDoc('teacher1', 'mhH1') });
  await assertFails(
    put(storageOf('teacher1').ref(`posts/mhH1/${published}/att_1.jpg`), 'image/jpeg', {
      uploaderId: 'teacher1',
    }),
  );

  await assertFails(
    put(storageOf('teacher1').ref('posts/mhH1/short/att_0.jpg'), 'image/jpeg', { uploaderId: 'teacher1' }),
  );
  await assertFails(
    put(storageOf('teacher1').ref(`posts/mhH1/${postId('Nm')}/photo.jpg`), 'image/jpeg', {
      uploaderId: 'teacher1',
    }),
  );
});

test('Posts: Halaqa members + Admin read a live post attachment; unrelated users cannot', async () => {
  const id = postId('Rd');
  const path = `posts/mhH1/${id}/att_0.jpg`;
  await seedObject(path, 'image/jpeg', 'teacher1');
  await seedDocs({ [`posts/${id}`]: postDoc('teacher1', 'mhH1') });

  for (const uid of ['teacher1', 'supervisor1', 'student1', 'parent1', 'admin1']) {
    await assertSucceeds(storageOf(uid).ref(path).getMetadata());
    await assertSucceeds(storageOf(uid).ref(path).getDownloadURL());
  }
  for (const uid of ['teacher2', 'student2', 'parent2', 'stranger']) {
    await assertFails(storageOf(uid).ref(path).getMetadata());
    await assertFails(storageOf(uid).ref(path).getDownloadURL());
  }
  await assertFails(anonStorage().ref(path).getDownloadURL());
});

test('Posts: only Admin may list attachment folders', async () => {
  const id = postId('Ls');
  const path = `posts/mhH1/${id}/att_0.jpg`;
  await seedObject(path, 'image/jpeg', 'teacher1');
  await seedDocs({ [`posts/${id}`]: postDoc('teacher1', 'mhH1') });

  for (const uid of ['teacher1', 'student1', 'parent1', 'stranger']) {
    await assertFails(storageOf(uid).ref(`posts/mhH1/${id}`).listAll());
    await assertFails(storageOf(uid).ref('posts/mhH1').listAll());
  }
  await assertSucceeds(storageOf('admin1').ref(`posts/mhH1/${id}`).listAll());
});

test('Posts: deleted post / partial upload hidden from members; Admin keeps read', async () => {
  // Uploaded but no post doc (failed create, or post deleted afterwards).
  const id = postId('Orph');
  const path = `posts/mhH1/${id}/att_0.jpg`;
  await seedObject(path, 'image/jpeg', 'teacher1');
  for (const uid of ['teacher1', 'student1', 'parent1']) {
    await assertFails(storageOf(uid).ref(path).getDownloadURL());
  }
  await assertSucceeds(storageOf('admin1').ref(path).getDownloadURL());
});

test('Posts: object must match the post Halaqa and author', async () => {
  // Post targets mhH2, object sits under mhH1 → mhH1 members cannot read it.
  const wrongHalaqa = postId('WrH');
  const p1 = `posts/mhH1/${wrongHalaqa}/att_0.jpg`;
  await seedObject(p1, 'image/jpeg', 'teacher1');
  await seedDocs({ [`posts/${wrongHalaqa}`]: postDoc('teacher1', 'mhH2') });
  await assertFails(storageOf('student1').ref(p1).getDownloadURL());

  // Object uploaded by someone other than the post author.
  const wrongAuthor = postId('WrA');
  const p2 = `posts/mhH1/${wrongAuthor}/att_0.jpg`;
  await seedObject(p2, 'image/jpeg', 'stranger');
  await seedDocs({ [`posts/${wrongAuthor}`]: postDoc('teacher1', 'mhH1') });
  await assertFails(storageOf('student1').ref(p2).getDownloadURL());

  // Object with no uploader stamp.
  const noStamp = postId('NoS');
  const p3 = `posts/mhH1/${noStamp}/att_0.jpg`;
  await seedObject(p3, 'image/jpeg');
  await seedDocs({ [`posts/${noStamp}`]: postDoc('teacher1', 'mhH1') });
  await assertFails(storageOf('student1').ref(p3).getDownloadURL());
  await assertSucceeds(storageOf('admin1').ref(p3).getDownloadURL());
});

test('Posts: uploader deletes own orphan; not others, not once published', async () => {
  const orphan = `posts/mhH1/${postId('Del')}/att_0.jpg`;
  await seedObject(orphan, 'image/jpeg', 'teacher1');
  await assertFails(storageOf('supervisor1').ref(orphan).delete());
  await assertFails(storageOf('student1').ref(orphan).delete());
  await assertSucceeds(storageOf('teacher1').ref(orphan).delete());

  const id = postId('Live');
  const live = `posts/mhH1/${id}/att_0.jpg`;
  await seedObject(live, 'image/jpeg', 'teacher1');
  await seedDocs({ [`posts/${id}`]: postDoc('teacher1', 'mhH1') });
  await assertFails(storageOf('teacher1').ref(live).delete());
  await assertFails(storageOf('admin1').ref(live).delete());
});

test('Posts: allowed types must match the extension; others denied', async () => {
  const up = (tag, name, type, size) =>
    put(storageOf('teacher1').ref(`posts/mhH1/${postId(tag)}/${name}`), type, {
      uploaderId: 'teacher1',
      size,
    });
  await assertSucceeds(up('T1', 'att_0.pdf', 'application/pdf'));
  await assertSucceeds(up('T2', 'att_0.jpg', 'image/jpeg'));
  await assertSucceeds(up('T3', 'att_0.jpeg', 'image/jpeg'));
  await assertSucceeds(up('T4', 'att_0.png', 'image/png'));
  await assertSucceeds(up('T5', 'att_0.mp3', 'audio/mpeg'));
  await assertSucceeds(up('T6', 'att_0.wav', 'audio/wav'));
  await assertSucceeds(up('T7', 'att_0.mp4', 'video/mp4'));

  await assertFails(up('F1', 'att_0.jpg', 'image/png'));
  await assertFails(up('F2', 'att_0.pdf', 'image/jpeg'));
  await assertFails(up('F3', 'att_0.gif', 'image/gif'));
  await assertFails(up('F4', 'att_0.html', 'text/html'));
  await assertFails(up('F5', 'att_0.exe', 'application/x-msdownload'));
  await assertFails(up('F6', 'att_0', 'image/jpeg'));
  await assertFails(up('F7', 'att_0.jpg', 'application/octet-stream'));
  await assertFails(up('F8', 'att_0.jpg', undefined));
  await assertFails(up('F9', 'att_0.jpg.exe', 'image/jpeg'));
  await assertFails(up('FA', 'att_0.jpg', 'image/jpeg', 0));
});

test('Posts: per-type size ceilings (strictly below the limit)', async () => {
  const up = (tag, name, type, size) =>
    put(storageOf('teacher1').ref(`posts/mhH1/${postId(tag)}/${name}`), type, {
      uploaderId: 'teacher1',
      size,
    });
  await assertSucceeds(up('S1', 'att_0.jpg', 'image/jpeg', 10 * MB - 1));
  await assertFails(up('S2', 'att_0.jpg', 'image/jpeg', 10 * MB));
  await assertSucceeds(up('S3', 'att_0.pdf', 'application/pdf', 20 * MB - 1));
  await assertFails(up('S4', 'att_0.pdf', 'application/pdf', 20 * MB));
  await assertFails(up('S5', 'att_0.mp3', 'audio/mpeg', 20 * MB));
  await assertSucceeds(up('S6', 'att_0.mp4', 'video/mp4', 50 * MB - 1));
  await assertFails(up('S7', 'att_0.mp4', 'video/mp4', 50 * MB));
});

// ── Payment proofs: payment_proofs/{parentId}/{paymentId}/{name.img} ────────

test('Proofs: owner uploads JPEG / PNG / WebP for own payment', async () => {
  const s = storageOf('parent1');
  await assertSucceeds(put(s.ref('payment_proofs/parent1/mhPay1/1760000000001.jpg'), 'image/jpeg'));
  await assertSucceeds(put(s.ref('payment_proofs/parent1/mhPay1/1760000000002.jpeg'), 'image/jpeg'));
  await assertSucceeds(put(s.ref('payment_proofs/parent1/mhPay1/1760000000003.png'), 'image/png'));
  await assertSucceeds(put(s.ref('payment_proofs/parent1/mhPay1/1760000000004.webp'), 'image/webp'));
});

test('Proofs: wrong parent, wrong payment, malformed path denied', async () => {
  await assertFails(
    put(storageOf('parent1').ref('payment_proofs/parent2/mhPay2/1.jpg'), 'image/jpeg'),
  );
  await assertFails(
    put(storageOf('parent1').ref('payment_proofs/parent1/mhPay2/1.jpg'), 'image/jpeg'),
  );
  await assertFails(
    put(storageOf('parent2').ref('payment_proofs/parent1/mhPay1/1.jpg'), 'image/jpeg'),
  );
  await assertFails(
    put(storageOf('parent1').ref('payment_proofs/parent1/noSuchPay/1.jpg'), 'image/jpeg'),
  );
  await assertFails(put(storageOf('parent1').ref('payment_proofs/parent1/1.jpg'), 'image/jpeg'));
  await assertFails(
    put(storageOf('parent1').ref('payment_proofs/parent1/mhPay1/extra/1.jpg'), 'image/jpeg'),
  );
  await assertFails(put(storageOf('teacher1').ref('payment_proofs/teacher1/mhPay1/1.jpg'), 'image/jpeg'));
});

test('Proofs: type must be an allowed image matching the extension', async () => {
  const s = storageOf('parent1');
  const p = (name) => s.ref(`payment_proofs/parent1/mhPay1/${name}`);
  await assertFails(put(p('a.png'), 'image/jpeg'));
  await assertFails(put(p('a.jpg'), 'image/png'));
  await assertFails(put(p('a.gif'), 'image/gif'));
  await assertFails(put(p('a.svg'), 'image/svg+xml'));
  await assertFails(put(p('a.heic'), 'image/heic'));
  await assertFails(put(p('a.pdf'), 'application/pdf'));
  await assertFails(put(p('a'), 'image/jpeg'));
  await assertFails(put(p('a.jpg'), 'application/octet-stream'));
  await assertFails(put(p('a.jpg'), undefined));
  await assertFails(put(p('a.jpg.exe'), 'image/jpeg'));
  await assertFails(put(p('a b.jpg'), 'image/jpeg'));
});

test('Proofs: size must be non-empty and strictly below 10 MB', async () => {
  const s = storageOf('parent1');
  await assertSucceeds(
    put(s.ref('payment_proofs/parent1/mhPay1/max.jpg'), 'image/jpeg', { size: 10 * MB - 1 }),
  );
  await assertFails(
    put(s.ref('payment_proofs/parent1/mhPay1/over.jpg'), 'image/jpeg', { size: 10 * MB }),
  );
  await assertFails(
    put(s.ref('payment_proofs/parent1/mhPay1/empty.jpg'), 'image/jpeg', { size: 0 }),
  );
});

test('Proofs: unauthorized readers denied; owner and Admin read', async () => {
  const path = 'payment_proofs/parent1/mhPay1/r.jpg';
  await seedObject(path, 'image/jpeg');
  await assertSucceeds(storageOf('parent1').ref(path).getMetadata());
  await assertSucceeds(storageOf('admin1').ref(path).getMetadata());
  for (const uid of ['parent2', 'teacher1', 'student1', 'stranger']) {
    await assertFails(storageOf(uid).ref(path).getMetadata());
  }
  await assertFails(anonStorage().ref(path).getMetadata());
  await assertFails(storageOf('parent1').ref('payment_proofs/parent1/mhPay1').listAll());
});

test('Proof cycle: a stored proof can be neither overwritten nor deleted by anyone', async () => {
  const path = 'payment_proofs/parent1/mhPay1/1760000000009.jpg';
  await seedObject(path, 'image/jpeg');
  // Same name again (A → B → A re-upload) is an overwrite, so it is denied.
  await assertFails(put(storageOf('parent1').ref(path), 'image/jpeg'));
  await assertFails(put(storageOf('parent1').ref(path), 'image/jpeg', { size: 16 }));
  for (const uid of ['parent1', 'parent2', 'admin1', 'supervisor1', 'teacher1']) {
    await assertFails(storageOf(uid).ref(path).delete());
    await assertFails(
      storageOf(uid).ref(path).updateMetadata({ customMetadata: { forged: '1' } }),
    );
  }
  await assertSucceeds(storageOf('parent1').ref(path).getMetadata());
});

test('Proof cycle: an orphan upload is only an object, never the current proof', async () => {
  // Rules let the owner create a fresh object; the payment document is not
  // touched — only submitPaymentProof can point at it (firestore.rules).
  await assertSucceeds(
    put(storageOf('parent1').ref('payment_proofs/parent1/mhPay1/1760000000010.jpg'), 'image/jpeg'),
  );
  let payment;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    payment = (await ctx.firestore().doc('payments/mhPay1').get()).data();
  });
  assert.equal(payment.proofFileName, undefined);
  assert.equal(payment.proofCycleId, undefined);
});

// ── Award images: awards/{teacherId}/{name.img} ─────────────────────────────

test('Awards: JPEG / PNG / WebP matching the extension; others denied', async () => {
  const s = storageOf('teacher1');
  await assertSucceeds(put(s.ref('awards/teacher1/1.jpg'), 'image/jpeg'));
  await assertSucceeds(put(s.ref('awards/teacher1/2.png'), 'image/png'));
  await assertSucceeds(put(s.ref('awards/teacher1/3.webp'), 'image/webp'));
  await assertFails(put(s.ref('awards/teacher1/4.png'), 'image/jpeg'));
  await assertFails(put(s.ref('awards/teacher1/5.gif'), 'image/gif'));
  await assertFails(put(s.ref('awards/teacher1/6'), 'image/jpeg'));
  await assertFails(put(s.ref('awards/teacher1/7.jpg'), 'application/octet-stream'));
  await assertSucceeds(put(s.ref('awards/teacher1/8.jpg'), 'image/jpeg', { size: 10 * MB - 1 }));
  await assertFails(put(s.ref('awards/teacher1/9.jpg'), 'image/jpeg', { size: 10 * MB }));
});

// ── Activity images: halaqa_activities/{activityId}/{studentId}/images/… ────

test('Activity images: JPEG / PNG / WebP matching the extension, below 10 MB', async () => {
  const s = storageOf('student1');
  const p = (name) => s.ref(`halaqa_activities/mhAct1/student1/images/${name}`);
  await assertSucceeds(put(p('1.jpg'), 'image/jpeg'));
  await assertSucceeds(put(p('2.png'), 'image/png'));
  await assertSucceeds(put(p('3.webp'), 'image/webp'));
  await assertFails(put(p('4.png'), 'image/jpeg'));
  await assertFails(put(p('5.gif'), 'image/gif'));
  await assertFails(put(p('6'), 'image/jpeg'));
  await assertFails(put(p('7.jpg'), 'application/octet-stream'));
  await assertSucceeds(put(p('8.jpg'), 'image/jpeg', { size: 10 * MB - 1 }));
  await assertFails(put(p('9.jpg'), 'image/jpeg', { size: 10 * MB }));
});

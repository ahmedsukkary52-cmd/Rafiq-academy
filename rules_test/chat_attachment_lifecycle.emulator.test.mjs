/**
 * Chat attachment lifecycle E2E on Emulator (`demo-rafiq-rules`):
 * authenticated client Storage upload → sendChatMessage → peer download,
 * plus orphan delete, idempotent retry, spoofed uploader denial, soft-delete.
 *
 * Uses the Firebase JS client (rules apply) and HTTP callables.
 *
 * Run from repo root (after `npm --prefix functions run build`):
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only auth,firestore,functions,storage \
 *     "node --test --test-concurrency=1 rules_test/chat_attachment_lifecycle.emulator.test.mjs"
 */
import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequire } from 'node:module';
import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth,
  connectAuthEmulator,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';
import {
  getStorage,
  connectStorageEmulator,
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} from 'firebase/storage';

import { PROJECT_ID } from './project_id.mjs';
import { clientFunctionsRegion } from '../functions/test/helpers/client_region.mjs';

const require = createRequire(import.meta.url);

const FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
const FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001';
const BUCKET = `${PROJECT_ID}.appspot.com`;

if (!FIRESTORE || !AUTH || !STORAGE || !PROJECT_ID.startsWith('demo-')) {
  throw new Error(
    'Attachment lifecycle suite requires auth + firestore + functions + storage and a demo- project id',
  );
}
process.env.GCLOUD_PROJECT = PROJECT_ID;

const admin = require('firebase-admin');
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
}
const db = admin.firestore();
const adminBucket = admin.storage().bucket();

const CLIENT_REGION = clientFunctionsRegion();
const DIRECT = 'student1_teacher1';

const JPEG = Uint8Array.from([
  0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1, 1, 0, 0, 1, 0xff, 0xd9,
]);
const PDF = new TextEncoder().encode('%PDF-1.7\n1 0 obj\n<<>>\nendobj\n');

let seq = 0;
const newId = () => {
  const id = `att${Date.now().toString(36)}${(seq++).toString().padStart(4, '0')}`;
  assert.ok(id.length >= 10 && id.length <= 40);
  return id;
};

let clientApp;
let auth;
let storage;

async function clearAll() {
  const fs = await fetch(
    `http://${FIRESTORE}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  assert.equal(fs.ok, true, 'firestore clear failed');
  const authClear = await fetch(
    `http://${AUTH}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: 'DELETE' },
  );
  assert.equal(authClear.ok, true, 'auth clear failed');
  const [files] = await adminBucket.getFiles();
  await Promise.all(files.map((f) => f.delete()));
}

async function ensureUser(uid) {
  try {
    await admin.auth().createUser({
      uid,
      email: `${uid}@example.test`,
      password: 'secret123',
    });
  } catch (e) {
    if (e.code !== 'auth/uid-already-exists') throw e;
  }
}

async function signIn(uid) {
  await signInWithEmailAndPassword(auth, `${uid}@example.test`, 'secret123');
}

async function call(name, data) {
  const token = await auth.currentUser.getIdToken();
  const res = await fetch(
    `http://${FUNCTIONS}/${PROJECT_ID}/${CLIENT_REGION}/${name}`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ data }),
    },
  );
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  return { status: res.status, body, code: body.error?.status };
}

async function uploadAs(uid, path, bytes, contentType) {
  await signIn(uid);
  const storageRef = ref(storage, path);
  await uploadBytes(storageRef, bytes, {
    contentType,
    customMetadata: { uploaderId: uid },
  });
}

async function downloadAs(uid, path) {
  await signIn(uid);
  try {
    const bytes = await getBytes(ref(storage, path));
    return { ok: true, bytes: Buffer.from(bytes) };
  } catch (e) {
    return { ok: false, code: e?.code ?? String(e) };
  }
}

async function deleteAs(uid, path) {
  await signIn(uid);
  try {
    await deleteObject(ref(storage, path));
    return { ok: true };
  } catch (e) {
    return { ok: false, code: e?.code ?? String(e) };
  }
}

const msg = async (id) => db.doc(`conversations/${DIRECT}/messages/${id}`).get();

test.before(async () => {
  clientApp = initializeApp(
    {
      projectId: PROJECT_ID,
      apiKey: 'fake-api-key',
      storageBucket: BUCKET,
    },
    'chat-attach-lifecycle',
  );
  auth = getAuth(clientApp);
  storage = getStorage(clientApp);
  const [authHost, authPort] = AUTH.split(':');
  connectAuthEmulator(auth, `http://${authHost}:${authPort}`, {
    disableWarnings: true,
  });
  const [stHost, stPort] = STORAGE.split(':');
  connectStorageEmulator(storage, stHost, Number(stPort));
});

test.after(async () => {
  if (clientApp) await deleteApp(clientApp);
});

test.beforeEach(async () => {
  if (auth.currentUser) await signOut(auth);
  await clearAll();
  for (const uid of ['student1', 'teacher1', 'parent1', 'stranger1']) {
    await ensureUser(uid);
  }
  const batch = db.batch();
  batch.set(db.doc('users/student1'), {
    role: 'student',
    isActive: true,
    name: 'طالب',
  });
  batch.set(db.doc('users/teacher1'), {
    role: 'teacher',
    isActive: true,
    name: 'معلم',
  });
  batch.set(db.doc('users/parent1'), {
    role: 'parent',
    isActive: true,
    name: 'ولي',
  });
  batch.set(db.doc('users/stranger1'), {
    role: 'teacher',
    isActive: true,
    name: 'غريب',
  });
  batch.set(db.doc(`conversations/${DIRECT}`), {
    kind: 'direct',
    participantIds: ['student1', 'teacher1'],
    unreadCounts: { student1: 0, teacher1: 0 },
  });
  await batch.commit();
});

test('lifecycle: client image upload → send → peer reads message + downloads bytes', async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/photo.jpg`;

  await uploadAs('teacher1', path, JPEG, 'image/jpeg');

  const early = await downloadAs('student1', path);
  assert.equal(early.ok, false, 'peer must not read unsent orphan');

  await signIn('teacher1');
  const sent = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id,
    type: 'image',
    media: { storagePath: path, fileName: 'واجب.jpg' },
  });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.result.created, true);

  const m = (await msg(id)).data();
  assert.equal(m.senderId, 'teacher1');
  assert.equal(m.type, 'image');
  assert.equal(m.media.storagePath, path);
  assert.equal(m.media.contentType, 'image/jpeg');
  assert.equal(m.media.sizeBytes, JPEG.length);
  assert.equal(m.media.fileName, 'واجب.jpg');

  const peer = await downloadAs('student1', path);
  assert.equal(peer.ok, true, `peer download failed: ${peer.code}`);
  assert.deepEqual(peer.bytes, Buffer.from(JPEG));

  const outsider = await downloadAs('parent1', path);
  assert.equal(outsider.ok, false, 'non-member must not download by path alone');
  const stranger = await downloadAs('stranger1', path);
  assert.equal(stranger.ok, false);
});

test('lifecycle: client PDF upload → send → peer download; wrong type rejected', async () => {
  const id = newId();
  const path = `chat_attachments/${DIRECT}/${id}/plan.pdf`;

  await uploadAs('student1', path, PDF, 'application/pdf');

  await signIn('student1');
  const wrongType = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id,
    type: 'image',
    media: { storagePath: path },
  });
  assert.equal(wrongType.code, 'INVALID_ARGUMENT');

  const ok = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id,
    type: 'file',
    media: { storagePath: path, fileName: 'خطة.pdf' },
  });
  assert.equal(ok.status, 200, JSON.stringify(ok.body));

  const peer = await downloadAs('teacher1', path);
  assert.equal(peer.ok, true, peer.code);
  assert.deepEqual(peer.bytes, Buffer.from(PDF));
});

test('lifecycle: abandoned upload → uploader deletes orphan; peer never sees it', async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/abandoned.jpg`;

  await uploadAs('teacher1', path, JPEG, 'image/jpeg');

  await signIn('parent1');
  const denied = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id,
    type: 'image',
    media: { storagePath: path },
  });
  assert.equal(denied.code, 'PERMISSION_DENIED');
  assert.equal((await msg(id)).exists, false);

  assert.equal((await downloadAs('student1', path)).ok, false);
  assert.equal((await deleteAs('student1', path)).ok, false);

  const del = await deleteAs('teacher1', path);
  assert.equal(del.ok, true, `orphan delete failed: ${del.code}`);
  const [exists] = await adminBucket.file(path).exists();
  assert.equal(exists, false);

  const id2 = newId();
  const path2 = `chat_media/${DIRECT}/${id2}/retry.jpg`;
  await uploadAs('teacher1', path2, JPEG, 'image/jpeg');
  await signIn('teacher1');
  const sent = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id2,
    type: 'image',
    media: { storagePath: path2 },
  });
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal(sent.body.result.created, true);
});

test('lifecycle: retry same messageId after successful send is idempotent', async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/idem.jpg`;
  await uploadAs('teacher1', path, JPEG, 'image/jpeg');
  await signIn('teacher1');

  const first = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id,
    type: 'image',
    media: { storagePath: path, fileName: 'a.jpg' },
  });
  assert.equal(first.body.result.created, true);

  const second = await call('sendChatMessage', {
    conversationId: DIRECT,
    messageId: id,
    type: 'image',
    media: { storagePath: path, fileName: 'a.jpg' },
  });
  assert.equal(second.status, 200, JSON.stringify(second.body));
  assert.equal(second.body.result.created, false);
  assert.equal(
    (await db.collection(`conversations/${DIRECT}/messages`).get()).size,
    1,
  );

  const del = await deleteAs('teacher1', path);
  assert.equal(del.ok, false, 'sent object must not be deletable as orphan');
});

test('lifecycle: spoofed uploaderId upload denied by Storage rules', async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/spoof.jpg`;
  await signIn('teacher1');
  await assert.rejects(
    uploadBytes(ref(storage, path), JPEG, {
      contentType: 'image/jpeg',
      customMetadata: { uploaderId: 'student1' },
    }),
  );
});

test('lifecycle: soft-delete hides media from participants; object retained', async () => {
  const id = newId();
  const path = `chat_media/${DIRECT}/${id}/mod.jpg`;
  await uploadAs('teacher1', path, JPEG, 'image/jpeg');
  await signIn('teacher1');
  assert.equal(
    (
      await call('sendChatMessage', {
        conversationId: DIRECT,
        messageId: id,
        type: 'image',
        media: { storagePath: path },
      })
    ).status,
    200,
  );

  const soft = await call('softDeleteChatMessage', {
    conversationId: DIRECT,
    messageId: id,
  });
  assert.equal(soft.status, 200, JSON.stringify(soft.body));
  const m = (await msg(id)).data();
  assert.equal(m.deleted, true);
  assert.equal(m.media, undefined);

  assert.equal((await downloadAs('student1', path)).ok, false);
  const [still] = await adminBucket.file(path).exists();
  assert.equal(still, true, 'object retained for Admin moderation (D20)');
});

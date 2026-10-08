/**
 * P0 §8 — Halaqa shared content library Storage scope (ALLOW + DENY).
 *
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only firestore,storage "npm --prefix rules_test run test:p0:storage"
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
const read = (name) => readFileSync(join(__dirname, '..', name), 'utf8');

let testEnv;

const storageOf = (uid) => testEnv.authenticatedContext(uid).storage();
const anonStorage = () => testEnv.unauthenticatedContext().storage();

function put(ref, contentType, bytes = new Uint8Array([1, 2, 3, 4])) {
  return ref.put(bytes, { contentType });
}

async function adminPut(path) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await put(ctx.storage().ref(path), 'application/pdf');
  });
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
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (role) => ({ name: role, role, isActive: true });
    // Doc ids are unique to this file: the Storage emulator caches
    // cross-service reads across clearFirestore() calls.
    const docs = {
      'users/admin1': user('admin'),
      'users/supervisor1': user('supervisor'),
      'users/teacher1': user('teacher'),
      'users/teacher2': user('teacher'),
      'users/parent1': user('parent'),
      'users/parent2': user('parent'),
      'users/student1': user('student'),
      'users/student2': user('student'),
      'halaqat/p0sh1': {
        teacherId: 'teacher1',
        supervisorId: 'supervisor1',
        studentIds: ['student1'],
      },
      'halaqat/p0sh2': {
        teacherId: 'teacher2',
        supervisorId: '',
        studentIds: ['student2'],
      },
      'parentProfiles/parent1': { uid: 'parent1', childrenIds: ['student1'] },
      'parentProfiles/parent2': { uid: 'parent2', childrenIds: ['student2'] },
    };
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
});

test('P0 storage: halaqa staff/Admin upload allowed types into their halaqa', async () => {
  await assertSucceeds(
    put(storageOf('teacher1').ref('content_library/p0sh1/teacher1/a.pdf'), 'application/pdf'),
  );
  await assertSucceeds(
    put(storageOf('supervisor1').ref('content_library/p0sh1/supervisor1/a.mp3'), 'audio/mpeg'),
  );
  await assertSucceeds(
    put(storageOf('admin1').ref('content_library/p0sh2/admin1/a.png'), 'image/png'),
  );
  await assertFails(
    put(storageOf('teacher1').ref('content_library/p0sh2/teacher1/a.pdf'), 'application/pdf'),
  );
  await assertFails(
    put(storageOf('teacher1').ref('content_library/p0sh1/teacher1/a.exe'), 'application/x-msdownload'),
  );
  await assertFails(
    put(storageOf('student1').ref('content_library/p0sh1/student1/a.pdf'), 'application/pdf'),
  );
  await assertFails(
    put(storageOf('parent1').ref('content_library/p0sh1/parent1/a.pdf'), 'application/pdf'),
  );
  await assertFails(
    put(anonStorage().ref('content_library/p0sh1/anon/a.pdf'), 'application/pdf'),
  );
});

test('P0 storage: halaqa community reads; other halaqa denied', async () => {
  const path = 'content_library/p0sh1/teacher1/a.pdf';
  await adminPut(path);
  for (const uid of ['teacher1', 'supervisor1', 'student1', 'parent1', 'admin1']) {
    await assertSucceeds(storageOf(uid).ref(path).getDownloadURL());
  }
  for (const uid of ['teacher2', 'student2', 'parent2']) {
    await assertFails(storageOf(uid).ref(path).getDownloadURL());
  }
  await assertFails(anonStorage().ref(path).getDownloadURL());
});

test('P0 storage: delete by halaqa staff/Admin only; legacy content/ is closed for writes', async () => {
  const path = 'content_library/p0sh1/teacher1/b.pdf';
  await adminPut(path);
  await assertFails(storageOf('student1').ref(path).delete());
  await assertFails(storageOf('teacher2').ref(path).delete());
  await assertSucceeds(storageOf('supervisor1').ref(path).delete());

  await assertFails(put(storageOf('teacher1').ref('content/teacher1/x.pdf'), 'application/pdf'));
  await adminPut('content/teacher1/legacy.pdf');
  await assertSucceeds(storageOf('teacher1').ref('content/teacher1/legacy.pdf').getDownloadURL());
  await assertFails(storageOf('student1').ref('content/teacher1/legacy.pdf').getDownloadURL());
});

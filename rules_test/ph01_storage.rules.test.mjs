/**
 * PRODUCTION-HARDENING-01 — Storage authorization (ALLOW + DENY).
 *
 * Storage Rules call firestore.get / exists, so both emulators are required
 * and the project id must match the one the emulators run under:
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only firestore,storage "npm --prefix rules_test run test:ph01:storage"
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

function image(ref) {
  return ref.put(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), {
    contentType: 'image/jpeg',
  });
}

function audio(ref) {
  return ref.put(new Uint8Array([0, 1, 2, 3]), { contentType: 'audio/mpeg' });
}

async function adminPut(path) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await image(ctx.storage().ref(path));
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
    const docs = {
      'users/admin1': user('admin'),
      'users/supervisor1': user('supervisor'),
      'users/supervisor2': user('supervisor'),
      'users/teacher1': user('teacher'),
      'users/teacher2': user('teacher'),
      'users/parent1': user('parent'),
      'users/parent2': user('parent'),
      'users/student1': user('student'),
      'users/student2': user('student'),
      'users/classmate': user('student'),
      // Doc ids are unique to this file: the Storage emulator caches
      // cross-service reads across clearFirestore() calls.
      'halaqat/ph01h1': {
        teacherId: 'teacher1',
        supervisorId: 'supervisor1',
        studentIds: ['student1', 'classmate'],
      },
      'halaqat/ph01h2': {
        teacherId: 'teacher2',
        supervisorId: 'supervisor2',
        studentIds: ['student2'],
      },
      'studentProfiles/student1': { halaqaId: 'ph01h1' },
      'studentProfiles/student2': { halaqaId: 'ph01h2' },
      'payments/ph01pay1': { parentId: 'parent1', studentId: 'student1', amount: 1 },
      'assignments/ph01act1': {
        halaqaId: 'ph01h1',
        assignedBy: 'teacher1',
        studentId: '',
      },
    };
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
});

test('PH01 storage: catch-all and invalid paths are denied', async () => {
  for (const s of [anonStorage(), storageOf('admin1'), storageOf('student1')]) {
    await assertFails(image(s.ref('random/file.jpg')));
    await assertFails(s.ref('random/file.jpg').getDownloadURL());
    await assertFails(image(s.ref('halaqa_activities/ph01act1/student1/x.jpg')));
    await assertFails(image(s.ref('payment_proofs/parent1/x.jpg')));
  }
});

test('PH01 storage: posts / content / awards uploads are staff-only', async () => {
  await assertFails(image(storageOf('student1').ref('posts/student1/a.jpg')));
  await assertFails(image(storageOf('parent1').ref('content/parent1/a.jpg')));
  await assertFails(image(storageOf('student1').ref('awards/student1/a.jpg')));
  // Posts: legacy author folder is closed; uploads are Halaqa-scoped.
  await assertFails(image(storageOf('teacher1').ref('posts/teacher1/a.jpg')));
  await assertSucceeds(
    storageOf('teacher1')
      .ref('posts/ph01h1/Ph01PostAaaaaaaaaaaa/att_0.jpg')
      .put(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), {
        contentType: 'image/jpeg',
        customMetadata: { uploaderId: 'teacher1' },
      }),
  );
  await assertFails(
    storageOf('student1')
      .ref('posts/ph01h1/Ph01PostBbbbbbbbbbbb/att_0.jpg')
      .put(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), {
        contentType: 'image/jpeg',
        customMetadata: { uploaderId: 'student1' },
      }),
  );
  // P0 §8: new library uploads are Halaqa-scoped; legacy content/ is closed.
  await assertFails(image(storageOf('teacher1').ref('content/teacher1/a.jpg')));
  await assertSucceeds(image(storageOf('teacher1').ref('content_library/ph01h1/teacher1/a.jpg')));
  await assertSucceeds(image(storageOf('supervisor1').ref('awards/supervisor1/a.jpg')));
  // Wrong owner path.
  await assertFails(image(storageOf('teacher1').ref('posts/teacher2/b.jpg')));
  await assertFails(image(storageOf('teacher1').ref('content_library/ph01h1/teacher2/b.jpg')));
});

test('PH01 storage: activity media is roster/staff scoped; wrong student denied', async () => {
  const path = 'halaqa_activities/ph01act1/student1/images/a.jpg';
  await assertSucceeds(image(storageOf('student1').ref(path)));
  await assertFails(
    image(storageOf('classmate').ref('halaqa_activities/ph01act1/student1/images/b.jpg')),
  );
  await assertFails(
    image(storageOf('student2').ref('halaqa_activities/ph01act1/student2/images/c.jpg')),
  );
  await assertFails(
    audio(storageOf('student1').ref('halaqa_activities/ph01act1/student1/audio/a.mp3')),
  );

  await assertSucceeds(storageOf('classmate').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('teacher1').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('supervisor1').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('admin1').ref(path).getDownloadURL());
  await assertFails(storageOf('student2').ref(path).getDownloadURL());
  await assertFails(storageOf('teacher2').ref(path).getDownloadURL());
  await assertFails(storageOf('parent2').ref(path).getDownloadURL());
  await assertFails(anonStorage().ref(path).getDownloadURL());
});

test('PH01 storage: payment proof readers are owner, Admin, scoped Supervisor', async () => {
  const path = 'payment_proofs/parent1/ph01pay1/proof.jpg';
  await adminPut(path);
  await assertSucceeds(storageOf('parent1').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('admin1').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('supervisor1').ref(path).getDownloadURL());
  await assertFails(storageOf('supervisor2').ref(path).getDownloadURL());
  await assertFails(storageOf('parent2').ref(path).getDownloadURL());
  await assertFails(storageOf('teacher1').ref(path).getDownloadURL());
  await assertFails(storageOf('student1').ref(path).getDownloadURL());
  await assertFails(image(storageOf('parent2').ref('payment_proofs/parent1/ph01pay1/x.jpg')));
});

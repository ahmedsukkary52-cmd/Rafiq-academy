/**
 * Deactivated staff (isActive == false) — Storage.
 *
 * Halaqa-scoped Storage paths authorize staff through the halaqa document
 * (isStaffOfHalaqaDoc / isStaffOfAssignmentHalaqa). A deactivated
 * teacher/supervisor still named there gets nothing; active staff, linked
 * parents and Admin are unchanged.
 *
 * The Storage emulator caches cross-service reads across clearFirestore(),
 * so active and deactivated staff are separate accounts on separate halaqat
 * (ids unique to this file) instead of toggling isActive mid-test.
 *
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only firestore,storage "npm --prefix rules_test run test:deactivated:storage"
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

function image(ref, customMetadata) {
  return ref.put(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), {
    contentType: 'image/jpeg',
    ...(customMetadata ? { customMetadata } : {}),
  });
}

function pdf(ref) {
  return ref.put(new Uint8Array([0x25, 0x50, 0x44, 0x46]), {
    contentType: 'application/pdf',
  });
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
    const user = (role, isActive = true) => ({ name: role, role, isActive });
    const docs = {
      'users/daAdmin': user('admin'),
      'users/daTeacherOn': user('teacher'),
      'users/daTeacherOff': user('teacher', false),
      'users/daSvOn': user('supervisor'),
      'users/daSvOff': user('supervisor', false),
      'users/daParent': user('parent'),
      'users/daStudentA': user('student'),
      'users/daStudentB': user('student'),
      'parentProfiles/daParent': { childrenIds: ['daStudentB'] },
      'halaqat/daHOn': {
        teacherId: 'daTeacherOn',
        supervisorId: 'daSvOn',
        studentIds: ['daStudentA'],
      },
      'halaqat/daHOff': {
        teacherId: 'daTeacherOff',
        supervisorId: 'daSvOff',
        studentIds: ['daStudentB'],
      },
      'assignments/daActOn': { halaqaId: 'daHOn', assignedBy: 'daTeacherOn', studentId: '' },
      'assignments/daActOff': { halaqaId: 'daHOff', assignedBy: 'daTeacherOff', studentId: '' },
    };
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
  await adminPut('content_library/daHOn/daAdmin/a.jpg');
  await adminPut('content_library/daHOff/daAdmin/a.jpg');
  await adminPut('halaqa_activities/daActOn/daStudentA/images/a.jpg');
  await adminPut('halaqa_activities/daActOff/daStudentB/images/a.jpg');
});

test('deactivated staff cannot read their halaqa shared content', async () => {
  for (const uid of ['daTeacherOn', 'daSvOn']) {
    await assertSucceeds(
      storageOf(uid).ref('content_library/daHOn/daAdmin/a.jpg').getDownloadURL(),
    );
  }
  for (const uid of ['daTeacherOff', 'daSvOff']) {
    await assertFails(
      storageOf(uid).ref('content_library/daHOff/daAdmin/a.jpg').getDownloadURL(),
    );
  }
});

test('deactivated staff cannot upload or delete halaqa shared content', async () => {
  for (const uid of ['daTeacherOn', 'daSvOn']) {
    await assertSucceeds(pdf(storageOf(uid).ref(`content_library/daHOn/${uid}/n.pdf`)));
  }
  await assertSucceeds(
    storageOf('daTeacherOn').ref('content_library/daHOn/daAdmin/a.jpg').delete(),
  );

  for (const uid of ['daTeacherOff', 'daSvOff']) {
    await assertFails(pdf(storageOf(uid).ref(`content_library/daHOff/${uid}/n.pdf`)));
    await assertFails(
      storageOf(uid).ref('content_library/daHOff/daAdmin/a.jpg').delete(),
    );
  }
});

test('deactivated staff cannot read halaqa activity uploads', async () => {
  for (const uid of ['daTeacherOn', 'daSvOn']) {
    await assertSucceeds(
      storageOf(uid).ref('halaqa_activities/daActOn/daStudentA/images/a.jpg').getDownloadURL(),
    );
  }
  for (const uid of ['daTeacherOff', 'daSvOff']) {
    await assertFails(
      storageOf(uid).ref('halaqa_activities/daActOff/daStudentB/images/a.jpg').getDownloadURL(),
    );
  }
});

test('deactivated staff cannot upload halaqa post attachments', async () => {
  await assertSucceeds(
    image(
      storageOf('daTeacherOn').ref('posts/daHOn/DaPostAaaaaaaaaaaaaa/att_0.jpg'),
      { uploaderId: 'daTeacherOn' },
    ),
  );
  await assertFails(
    image(
      storageOf('daTeacherOff').ref('posts/daHOff/DaPostBbbbbbbbbbbbbb/att_0.jpg'),
      { uploaderId: 'daTeacherOff' },
    ),
  );
});

test('linked parent, rostered student and admin keep access on the deactivated staff halaqa', async () => {
  const path = 'content_library/daHOff/daAdmin/a.jpg';
  await assertSucceeds(storageOf('daParent').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('daStudentB').ref(path).getDownloadURL());
  await assertSucceeds(storageOf('daAdmin').ref(path).getDownloadURL());
  await assertSucceeds(
    storageOf('daAdmin').ref('halaqa_activities/daActOff/daStudentB/images/a.jpg').getDownloadURL(),
  );
});

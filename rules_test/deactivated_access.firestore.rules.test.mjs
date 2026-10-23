/**
 * Deactivated accounts (isActive == false) — Firestore.
 *
 * A teacher/supervisor still named on halaqat/{id}.teacherId / supervisorId
 * (or listed in studentSearch.visibleTo) loses that halaqa's records once
 * deactivated; reactivation restores them. Parent and Admin access is
 * unaffected. users/{uid}: self stays readable while deactivated (sign-in
 * shows the disabled message); other profiles need an active caller.
 *
 * Run (isolated emulator, both services):
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only firestore,storage "npm --prefix rules_test run test:deactivated"
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROJECT_ID } from './project_id.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

let testEnv;

function authed(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function seedAll(entries) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(entries)) {
      await db.doc(path).set(data);
    }
  });
}

async function setActive(uid, isActive) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${uid}`).update({ isActive });
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  const user = (role, extra = {}) => ({ name: role, role, isActive: true, ...extra });
  await seedAll({
    'users/admin1': user('admin', { email: 'admin1@example.test' }),
    'users/teacher1': user('teacher', { email: 'teacher1@example.test' }),
    'users/teacher2': user('teacher'),
    'users/supervisor1': user('supervisor'),
    'users/parent1': user('parent'),
    'users/student1': user('student', { email: 'student1@example.test' }),
    'halaqat/h1': {
      name: 'H1',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
      status: 'active',
    },
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor2',
      studentIds: ['student2'],
      status: 'active',
    },
    'studentProfiles/student1': { uid: 'student1', halaqaId: 'h1' },
    'parentProfiles/parent1': { uid: 'parent1', childrenIds: ['student1'] },
    'studentSearch/student1': {
      studentId: 'student1',
      visibleTo: ['teacher1', 'supervisor1'],
    },
    'attendanceRecords/s1_student1': {
      studentId: 'student1',
      halaqaId: 'h1',
      status: 'present',
    },
    // Another halaqa's record: teacher1 reaches it only via roster scope.
    'attendanceRecords/s9_student1': {
      studentId: 'student1',
      halaqaId: 'h2',
      status: 'present',
    },
    'recitationRecords/pending1': {
      studentId: 'student1',
      halaqaId: 'h1',
      teacherId: 'teacher1',
      type: 'memorization',
      reviewStatus: 'pending',
    },
    'assignments/hw1': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [],
      isSubmitted: false,
    },
    'absenceRequests/h1_student1_20261015': {
      studentId: 'student1',
      halaqaId: 'h1',
      requestedBy: 'parent1',
      date: '2026-10-15',
      reason: 'r',
      status: 'pending',
    },
    'sessions/s1': {
      halaqaId: 'h1',
      slotId: 'slot-1',
      date: '2026-10-15',
      startAt: new Date('2026-10-15T13:00:00Z'),
      endAt: new Date('2026-10-15T14:00:00Z'),
      teacherId: 'teacher1',
      status: 'scheduled',
      createdAt: new Date('2026-10-01T00:00:00Z'),
      createdBy: 'system',
    },
    'supervisorReports/r1': { supervisorId: 'supervisor1', body: 'b' },
    'posts/post1': {
      authorId: 'teacher1',
      halaqaId: 'h1',
      audienceTarget: 'h1',
      likedBy: [],
      commentsCount: 0,
      isPinned: false,
    },
    'contentLibrary/c1': {
      halaqaId: 'h1',
      uploadedBy: 'teacher1',
      storagePath: 'content_library/h1/teacher1/a.pdf',
    },
  });
});

// ── Teacher ────────────────────────────────────────────────────────────────

const TEACHER_READS = [
  'attendanceRecords/s1_student1',
  'recitationRecords/pending1',
  'assignments/hw1',
  'absenceRequests/h1_student1_20261015',
  'posts/post1',
  'contentLibrary/c1',
];

test('deactivated teacher loses reads of their halaqa records', async () => {
  for (const path of TEACHER_READS) {
    await assertSucceeds(authed('teacher1').doc(path).get());
  }
  await assertSucceeds(
    authed('teacher1').collection('attendanceRecords').where('halaqaId', '==', 'h1').get(),
  );

  await setActive('teacher1', false);
  for (const path of TEACHER_READS) {
    await assertFails(authed('teacher1').doc(path).get());
  }
  await assertFails(
    authed('teacher1').collection('attendanceRecords').where('halaqaId', '==', 'h1').get(),
  );
});

test('deactivated teacher loses roster-scoped (studentSearch.visibleTo) reads', async () => {
  const path = 'attendanceRecords/s9_student1';
  await assertSucceeds(authed('teacher1').doc(path).get());
  await assertSucceeds(
    authed('teacher1').collection('attendanceRecords').where('studentId', '==', 'student1').get(),
  );

  await setActive('teacher1', false);
  await assertFails(authed('teacher1').doc(path).get());
  await assertFails(
    authed('teacher1').collection('attendanceRecords').where('studentId', '==', 'student1').get(),
  );
});

test('deactivated teacher cannot write; reactivation restores the same writes', async () => {
  const writes = (db) => [
    () => db.doc('recitationRecords/pending1').update({ reviewStatus: 'reviewed', grade: 9 }),
    () => db.doc('absenceRequests/h1_student1_20261015').update({
      status: 'approved',
      reviewedBy: 'teacher1',
      reviewedAt: new Date(),
    }),
    () => db.doc('assignments/hw1').update({ title: 'updated' }),
    () => db.doc('assignments/hwNew').set({
      assignedBy: 'teacher1',
      halaqaId: 'h1',
      studentId: 'student1',
      kind: 'lessonHomework',
      tasks: [],
    }),
    () => db.doc('sessions/s1').update({ status: 'in_progress', updatedAt: new Date() }),
    () => db.doc('posts/postNew').set({
      authorId: 'teacher1',
      halaqaId: 'h1',
      audienceTarget: 'h1',
      likedBy: [],
      commentsCount: 0,
      isPinned: false,
    }),
    () => db.doc('contentLibrary/cNew').set({
      halaqaId: 'h1',
      uploadedBy: 'teacher1',
      storagePath: 'content_library/h1/teacher1/b.pdf',
    }),
    () => db.doc('contentLibrary/c1').delete(),
  ];

  await setActive('teacher1', false);
  for (const write of writes(authed('teacher1'))) {
    await assertFails(write());
  }

  await setActive('teacher1', true);
  for (const write of writes(authed('teacher1'))) {
    await assertSucceeds(write());
  }
});

// ── Supervisor ─────────────────────────────────────────────────────────────

const SUPERVISOR_READS = [
  'attendanceRecords/s1_student1',
  'recitationRecords/pending1',
  'assignments/hw1',
  'absenceRequests/h1_student1_20261015',
  'posts/post1',
  'contentLibrary/c1',
  'supervisorReports/r1',
];

test('deactivated supervisor loses reads of their halaqa records', async () => {
  for (const path of SUPERVISOR_READS) {
    await assertSucceeds(authed('supervisor1').doc(path).get());
  }
  await assertSucceeds(
    authed('supervisor1').collection('supervisorReports')
      .where('supervisorId', '==', 'supervisor1').get(),
  );
  await assertSucceeds(authed('supervisor1').doc('attendanceRecords/s9_student1').get());

  await setActive('supervisor1', false);
  for (const path of SUPERVISOR_READS) {
    await assertFails(authed('supervisor1').doc(path).get());
  }
  await assertFails(
    authed('supervisor1').collection('supervisorReports')
      .where('supervisorId', '==', 'supervisor1').get(),
  );
  await assertFails(authed('supervisor1').doc('attendanceRecords/s9_student1').get());
});

test('deactivated supervisor cannot write; reactivation restores the same writes', async () => {
  const writes = (db) => [
    () => db.doc('posts/postSv').set({
      authorId: 'supervisor1',
      halaqaId: 'h1',
      audienceTarget: 'h1',
      likedBy: [],
      commentsCount: 0,
      isPinned: false,
    }),
    () => db.doc('contentLibrary/cSv').set({
      halaqaId: 'h1',
      uploadedBy: 'supervisor1',
      storagePath: 'content_library/h1/supervisor1/a.pdf',
    }),
    () => db.doc('contentLibrary/c1').delete(),
  ];

  await setActive('supervisor1', false);
  for (const write of writes(authed('supervisor1'))) {
    await assertFails(write());
  }

  await setActive('supervisor1', true);
  for (const write of writes(authed('supervisor1'))) {
    await assertSucceeds(write());
  }
});

// ── Parent / Admin unaffected ──────────────────────────────────────────────

test('parent and admin access is unchanged while halaqa staff are deactivated', async () => {
  await setActive('teacher1', false);
  await setActive('supervisor1', false);

  for (const path of ['attendanceRecords/s1_student1', 'assignments/hw1', 'posts/post1']) {
    await assertSucceeds(authed('parent1').doc(path).get());
    await assertSucceeds(authed('admin1').doc(path).get());
  }
  await assertSucceeds(
    authed('parent1').collection('attendanceRecords').where('studentId', '==', 'student1').get(),
  );
  await assertSucceeds(authed('admin1').doc('supervisorReports/r1').get());
  await assertSucceeds(
    authed('admin1').doc('sessions/s1').update({ status: 'cancelled', updatedAt: new Date() }),
  );
});

// ── users/{uid} ────────────────────────────────────────────────────────────

test('users get: deactivated callers read only their own profile', async () => {
  await setActive('teacher1', false);
  await setActive('parent1', false);

  // Self stays readable so sign-in can show the disabled-account message.
  const self = await assertSucceeds(authed('teacher1').doc('users/teacher1').get());
  assert.equal(self.data().isActive, false);
  await assertSucceeds(authed('parent1').doc('users/parent1').get());

  for (const uid of ['teacher1', 'parent1']) {
    await assertFails(authed(uid).doc('users/student1').get());
    await assertFails(authed(uid).doc('users/admin1').get());
  }
});

test('users get: a caller without a profile reads only its own (missing) doc', async () => {
  const own = await assertSucceeds(authed('ghost').doc('users/ghost').get());
  assert.equal(own.exists, false);
  await assertFails(authed('ghost').doc('users/student1').get());
});

test('users get: active callers and admin keep the reads app flows need', async () => {
  // Parent child card + staff contacts, teacher roster names, chat participants.
  await assertSucceeds(authed('parent1').doc('users/student1').get());
  await assertSucceeds(authed('parent1').doc('users/teacher1').get());
  await assertSucceeds(authed('teacher1').doc('users/student1').get());
  await assertSucceeds(authed('student1').doc('users/teacher1').get());

  await setActive('student1', false);
  await assertSucceeds(authed('admin1').doc('users/student1').get());
});

// Known limitation, asserted so it is not mistaken for fixed: Firestore Rules
// cannot hide single fields, so an active caller who may read a profile also
// sees its email until email moves out of users/{uid}.
test('users get: email is still visible to other active callers (unresolved)', async () => {
  const snap = await assertSucceeds(authed('parent1').doc('users/teacher1').get());
  assert.equal(snap.data().email, 'teacher1@example.test');
});

test('users list: deactivated callers cannot list admin contacts or rosters', async () => {
  await assertSucceeds(
    authed('parent1').collection('users').where('role', '==', 'admin').get(),
  );
  await assertSucceeds(authed('teacher1').collection('users').get());

  await setActive('parent1', false);
  await setActive('teacher1', false);
  await assertFails(
    authed('parent1').collection('users').where('role', '==', 'admin').get(),
  );
  await assertFails(authed('teacher1').collection('users').get());
});

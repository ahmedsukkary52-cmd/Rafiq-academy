/**
 * PRODUCTION-HARDENING-02 — Backend authority rule changes (ALLOW + DENY).
 *
 * Every mutation moved to a callable / trigger is denied for every client
 * role here, while the client paths that legitimately remain keep working.
 *
 * Run from repo root:
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "npm --prefix rules_test run test:ph02"
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
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

const ALL_ROLES = ['admin1', 'supervisor1', 'teacher1', 'parent1', 'student1'];

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
  const user = (role) => ({ name: role, role, isActive: true });
  await seedAll({
    'users/admin1': user('admin'),
    'users/supervisor1': user('supervisor'),
    'users/teacher1': user('teacher'),
    'users/teacher2': user('teacher'),
    'users/parent1': user('parent'),
    'users/student1': user('student'),
    'users/student3': user('student'),
    'halaqat/h1': {
      name: 'H1',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
      schedule: [{ day: 0, startTime: '16:00', endTime: '17:00', slotId: 'slot-1' }],
      status: 'active',
    },
    'studentProfiles/student1': {
      uid: 'student1',
      halaqaId: 'h1',
      points: 0,
      totalStars: 0,
      coins: 50,
      avatarId: 'fox',
      unlockedAvatarIds: ['fox'],
    },
    'studentProfiles/student3': { uid: 'student3', points: 0 },
    'parentProfiles/parent1': { uid: 'parent1', childrenIds: ['student1'] },
    'payments/payDue': {
      parentId: 'parent1',
      studentId: 'student1',
      amount: 100,
      status: 'due',
    },
    'payments/payPaid': {
      parentId: 'parent1',
      studentId: 'student1',
      amount: 100,
      status: 'paid',
      reviewStatus: 'approved',
      reviewedBy: 'admin1',
    },
    'sessions/s1': { halaqaId: 'h1', teacherId: 'teacher1', status: 'scheduled' },
    'attendanceRecords/s1_student1': {
      studentId: 'student1',
      halaqaId: 'h1',
      status: 'present',
      recordedBy: 'teacher1',
      sessionId: 's1',
    },
    'recitationRecords/s1_student1_memorization': {
      studentId: 'student1',
      halaqaId: 'h1',
      teacherId: 'teacher1',
      type: 'memorization',
      sessionId: 's1',
      reviewStatus: 'reviewed',
      grade: 'x',
    },
    'recitationRecords/pending1': {
      studentId: 'student1',
      halaqaId: 'h1',
      teacherId: 'teacher1',
      type: 'memorization',
      reviewStatus: 'pending',
      assignmentId: 'hw1',
    },
    'assignments/hw1': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [{ id: 't1', isCompleted: false }],
      isSubmitted: false,
      status: 'pending',
    },
    'studentMembershipLocks/student1': { studentId: 'student1', count: 1 },
  });
});

// ── C4 / C16 payment review ────────────────────────────────────────────────

function proofSubmission(paymentId) {
  return {
    proofStoragePath: `payment_proofs/parent1/${paymentId}/1760000000000.jpg`,
    proofFileName: '1760000000000.jpg',
    proofSubmittedBy: 'parent1',
    proofSubmittedAt: firebase.firestore.FieldValue.serverTimestamp(),
    method: 'vodafone_cash',
    reviewStatus: 'pending_review',
  };
}

test('PH02 payments: no client role writes a review conclusion', async () => {
  const conclusions = [
    { status: 'paid', reviewStatus: 'approved', paidAt: new Date() },
    { reviewStatus: 'rejected' },
    { reviewStatus: 'approved' },
    { reviewedBy: 'admin1', reviewedAt: new Date() },
    { amountPaidConfirmed: 100, remainingAmount: 0 },
  ];
  for (const uid of ALL_ROLES) {
    for (const change of conclusions) {
      await assertFails(authed(uid).doc('payments/payDue').update(change));
    }
  }
});

test('PH02 payments: proof submission is callable-only, even on an unpaid invoice', async () => {
  await assertFails(
    authed('parent1').doc('payments/payDue').update(proofSubmission('payDue')),
  );
});

test('PH02 payments: a paid invoice is final for the Parent too', async () => {
  await assertFails(
    authed('parent1').doc('payments/payPaid').update(proofSubmission('payPaid')),
  );
});

// ── C6 attendance / evaluation ─────────────────────────────────────────────

test('PH02 attendance: every client role is denied create/update/delete', async () => {
  const mark = {
    studentId: 'student1',
    studentName: 's',
    halaqaId: 'h1',
    status: 'present',
    sessionId: 's1',
  };
  for (const uid of ALL_ROLES) {
    const db = authed(uid);
    await assertFails(
      db.doc('attendanceRecords/s1_student3').set({ ...mark, recordedBy: uid }),
    );
    await assertFails(db.doc('attendanceRecords/s1_student1').update({ status: 'late' }));
    await assertFails(db.doc('attendanceRecords/s1_student1').delete());
  }
});

test('PH02 attendance: reads stay scoped (student / parent / staff allowed)', async () => {
  for (const uid of ['student1', 'parent1', 'teacher1', 'supervisor1', 'admin1']) {
    await assertSucceeds(authed(uid).doc('attendanceRecords/s1_student1').get());
  }
  await assertFails(authed('teacher2').doc('attendanceRecords/s1_student1').get());
});

test('PH02 evaluation: live evaluation create/update/delete denied for clients', async () => {
  const live = {
    studentId: 'student1',
    studentName: 's',
    teacherId: 'teacher1',
    halaqaId: 'h1',
    type: 'review',
    sessionId: 's1',
    grade: 'x',
    behaviorGrade: 'x',
    reviewStatus: 'reviewed',
  };
  for (const uid of ALL_ROLES) {
    const db = authed(uid);
    await assertFails(db.doc('recitationRecords/s1_student1_review').set(live));
    await assertFails(
      db.doc('recitationRecords/s1_student1_memorization').update({ grade: 'y' }),
    );
    await assertFails(db.doc('recitationRecords/s1_student1_memorization').delete());
  }
});

test('PH02 evaluation: homework submission + teacher review of pending remain', async () => {
  await assertSucceeds(
    authed('student1').collection('recitationRecords').add({
      studentId: 'student1',
      studentName: 's',
      teacherId: 'teacher1',
      halaqaId: 'h1',
      type: 'memorization',
      assignmentId: 'hw1',
      reviewStatus: 'pending',
    }),
  );
  await assertSucceeds(
    authed('teacher1').doc('recitationRecords/pending1').update({
      reviewStatus: 'reviewed',
      grade: 'x',
      behaviorGrade: 'x',
    }),
  );
  await assertFails(
    authed('teacher2').doc('recitationRecords/pending1').update({
      reviewStatus: 'reviewed',
      grade: 'x',
    }),
  );
});

test('PH02 B1: a submission cannot squat a live-evaluation id or forge its anchor', async () => {
  const submission = {
    studentId: 'student1',
    studentName: 's',
    teacherId: 'teacher1',
    halaqaId: 'h1',
    type: 'memorization',
    assignmentId: 'hw1',
    reviewStatus: 'pending',
  };
  const s1 = authed('student1');
  for (const id of ['s2_student1_memorization', 's2_student1_review']) {
    await assertFails(s1.doc(`recitationRecords/${id}`).set(submission));
  }
  await assertFails(
    s1.collection('recitationRecords').add({ ...submission, createdAt: new Date(2030, 0, 1) }),
  );
  await assertSucceeds(s1.doc('recitationRecords/autoId123').set(submission));
  // No client — including Admin and Supervisor — moves a live evaluation's anchor.
  for (const uid of ALL_ROLES) {
    await assertFails(
      authed(uid)
        .doc('recitationRecords/s1_student1_memorization')
        .update({ createdAt: new Date() }),
    );
  }
});

// ── C11 notifications ──────────────────────────────────────────────────────

test('PH02 notifications: no client addresses a user; Admin role broadcast ok', async () => {
  const card = (audience) => ({
    audience,
    title: 't',
    body: 'b',
    type: 'general',
    readBy: [],
    hasAudioAlert: false,
  });
  for (const uid of ALL_ROLES) {
    await assertFails(
      authed(uid).doc('notifications/parent1_evt9').set(card('parent1')),
    );
  }
  for (const uid of ['supervisor1', 'teacher1', 'parent1', 'student1']) {
    await assertFails(authed(uid).collection('notifications').add(card('parent')));
  }
  await assertSucceeds(authed('admin1').collection('notifications').add(card('all')));
  await assertFails(
    authed('admin1')
      .collection('notifications')
      .add({ ...card('parent'), delivery: { status: 'sent' } }),
  );
});

// ── Halaqa membership ──────────────────────────────────────────────────────

test('PH02 halaqa: studentIds is callable-only for every role', async () => {
  for (const uid of ALL_ROLES) {
    const db = authed(uid);
    await assertFails(
      db.doc('halaqat/h1').update({ studentIds: ['student1', 'student3'] }),
    );
    await assertFails(db.doc('halaqat/h1').update({ studentIds: [] }));
  }
});

test('PH02 halaqa: client create denied (P0-04 callable); Admin edits are callable-only', async () => {
  const db = authed('admin1');
  await assertFails(
    db.doc('halaqat/h9').set({
      name: 'x',
      schedule: [{ day: 1 }],
      studentIds: ['student3'],
    }),
  );
  await assertFails(
    db.doc('halaqat/h9').set({ name: 'x', schedule: [{ day: 1 }], studentIds: [] }),
  );
  await assertFails(db.doc('halaqat/h1').update({ name: 'حلقة معدلة' }));
  await assertFails(db.doc('halaqat/h1').update({ teacherId: 'teacher2' }));
  await assertFails(authed('supervisor1').doc('halaqat/h1').update({ name: 'y' }));
});

test('B14 halaqa: meetingLink is callable-only (setHalaqaMeetingLink) for every role', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('halaqat/h1').update({ meetingLink: 'https://meet.example.test/a' });
  });
  const unauthed = testEnv.unauthenticatedContext().firestore();
  for (const db of [...ALL_ROLES.map(authed), unauthed]) {
    await assertFails(db.doc('halaqat/h1').update({ meetingLink: 'https://meet.example.test/x' }));
    await assertFails(db.doc('halaqat/h1').update({ meetingLink: '' }));
    await assertFails(
      db.doc('halaqat/h1').update({ meetingLink: firebase.firestore.FieldValue.delete() }),
    );
    await assertFails(
      db.doc('halaqat/h1').update({ name: 'y', meetingLink: 'https://meet.example.test/y' }),
    );
  }
  const admin = authed('admin1');
  await assertFails(admin.doc('halaqat/h1').update({ name: 'حلقة معدلة', status: 'active' }));
  const after = await assertSucceeds(admin.doc('halaqat/h1').get());
  if (after.data().meetingLink !== 'https://meet.example.test/a') {
    throw new Error('a denied client write changed meetingLink');
  }
});

// ── J.9 Halaqa read scope ──────────────────────────────────────────────────

async function allow(label, promise) {
  try {
    return await assertSucceeds(promise);
  } catch (error) {
    throw new Error(`expected ALLOW: ${label} (${error.code ?? error.message})`);
  }
}

async function deny(label, promise) {
  try {
    await assertFails(promise);
  } catch {
    throw new Error(`expected DENY: ${label}`);
  }
}

const H2 = {
  name: 'H2',
  teacherId: 'teacher2',
  supervisorId: 'supervisor1',
  studentIds: ['student3'],
  status: 'active',
};

async function setHalaqa(id, fields) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`halaqat/${id}`).update(fields);
  });
}

test('Halaqa reads (J.9): an active rostered student reads only their Halaqat', async () => {
  await seedAll({
    'halaqat/h2': H2,
    'users/student4': { name: 'student4', role: 'student', isActive: false },
  });

  const student1 = authed('student1');
  await allow('student1 gets own h1', student1.doc('halaqat/h1').get());
  await allow(
    'student1 queries own roster',
    student1.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await deny('student1 gets h2', student1.doc('halaqat/h2').get());
  await deny('student1 gets a missing halaqa', student1.doc('halaqat/missing').get());
  await deny('student1 lists halaqat', student1.collection('halaqat').get());
  await deny(
    'student1 queries by status',
    student1.collection('halaqat').where('status', '==', 'active').get(),
  );
  await deny(
    'student1 queries another roster',
    student1.collection('halaqat').where('studentIds', 'array-contains', 'student3').get(),
  );
  await allow('student3 gets own h2', authed('student3').doc('halaqat/h2').get());
  await deny('inactive student4 gets h1', authed('student4').doc('halaqat/h1').get());
  await deny('unauthenticated get', testEnv.unauthenticatedContext().firestore().doc('halaqat/h1').get());

  await setHalaqa('h1', { studentIds: [] });
  await deny('student1 after removal from the roster', student1.doc('halaqat/h1').get());
});

test('Halaqa reads (J.9): a legacy meetingLink makes the document Admin-only for get', async () => {
  await setHalaqa('h1', { meetingLink: 'https://meet.example.test/h1' });
  for (const uid of ['student1', 'teacher1', 'supervisor1']) {
    await deny(`${uid} gets h1 while it carries a legacy link`, authed(uid).doc('halaqat/h1').get());
  }
  const viaAdmin = await allow('admin gets h1 with a legacy link', authed('admin1').doc('halaqat/h1').get());
  if (viaAdmin.data().meetingLink !== 'https://meet.example.test/h1') throw new Error('seed missing');

  await setHalaqa('h1', { meetingLink: 42 });
  await deny('student1 gets h1 with a non-string legacy value', authed('student1').doc('halaqat/h1').get());

  await setHalaqa('h1', { meetingLink: '' });
  for (const uid of ['student1', 'teacher1', 'supervisor1']) {
    await allow(`${uid} gets h1 with an empty legacy key`, authed(uid).doc('halaqat/h1').get());
  }

  await setHalaqa('h1', { meetingLink: firebase.firestore.FieldValue.delete() });
  for (const uid of ['student1', 'teacher1', 'supervisor1']) {
    await allow(`${uid} gets h1 once the legacy key is gone`, authed(uid).doc('halaqat/h1').get());
  }
});

test('Halaqa reads (J.9): rules cannot prove field absence for queries; only the strip closes list reads', async () => {
  await setHalaqa('h1', { meetingLink: 'https://meet.example.test/h1' });
  const listed = await allow(
    'teacher1 queries own halaqat while h1 still carries a legacy link',
    authed('teacher1').collection('halaqat').where('teacherId', '==', 'teacher1').get(),
  );
  if (listed.docs[0]?.data().meetingLink !== 'https://meet.example.test/h1') {
    throw new Error('documented limitation changed: a list now hides the legacy field');
  }
});

test('Halaqa reads (J.9): deactivated and profile-less accounts read no Halaqa', async () => {
  await seedAll({
    'users/student5': { name: 'student5', role: 'student', isActive: false },
    'studentProfiles/student5': { uid: 'student5', halaqaId: 'h1', points: 0 },
    'users/teacherOff': { name: 'teacherOff', role: 'teacher', isActive: false },
    'users/supervisorOff': { name: 'supervisorOff', role: 'supervisor', isActive: false },
    'users/parentOff': { name: 'parentOff', role: 'parent', isActive: false },
    'parentProfiles/parentOff': { uid: 'parentOff', childrenIds: ['student1'] },
    'users/adminOff': { name: 'adminOff', role: 'admin', isActive: false },
    'halaqat/h2': H2,
  });
  await setHalaqa('h1', {
    studentIds: ['student1', 'student5'],
    teacherId: 'teacherOff',
    supervisorId: 'supervisorOff',
  });

  const student5 = authed('student5');
  await deny('deactivated rostered student5 gets h1', student5.doc('halaqat/h1').get());
  await deny(
    'deactivated student5 queries own roster',
    student5.collection('halaqat').where('studentIds', 'array-contains', 'student5').get(),
  );
  await deny('deactivated assigned teacher gets h1', authed('teacherOff').doc('halaqat/h1').get());
  await deny(
    'deactivated assigned teacher queries own halaqat',
    authed('teacherOff').collection('halaqat').where('teacherId', '==', 'teacherOff').get(),
  );
  await deny('deactivated assigned supervisor gets h1', authed('supervisorOff').doc('halaqat/h1').get());
  await deny('deactivated linked parent gets h1', authed('parentOff').doc('halaqat/h1').get());
  await deny('deactivated admin gets h1', authed('adminOff').doc('halaqat/h1').get());
  await deny('deactivated admin lists halaqat', authed('adminOff').collection('halaqat').get());

  const ghost = authed('ghost');
  await deny('profile-less account gets h1', ghost.doc('halaqat/h1').get());
  await deny('profile-less account lists halaqat', ghost.collection('halaqat').get());
  await deny(
    'profile-less account queries by roster',
    ghost.collection('halaqat').where('studentIds', 'array-contains', 'ghost').get(),
  );
  await deny('deactivated student5 gets h2', student5.doc('halaqat/h2').get());
  await deny('deactivated student5 lists halaqat', student5.collection('halaqat').get());

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/student5').update({ isActive: true });
  });
  await allow('reactivated student5 gets h1', student5.doc('halaqat/h1').get());
  await deny('reactivated student5 gets h2', student5.doc('halaqat/h2').get());
});

test('Halaqa reads (J.10): linked, unlinked, deactivated and profileless parents and staff read nothing', async () => {
  await seedAll({
    'halaqat/h2': H2,
    'users/parent2': { name: 'parent2', role: 'parent', isActive: true },
    'parentProfiles/parent2': { uid: 'parent2', childrenIds: ['student3'] },
    'users/parent3': { name: 'parent3', role: 'parent', isActive: true },
    'users/parentOff': { name: 'parentOff', role: 'parent', isActive: false },
    'parentProfiles/parentOff': { uid: 'parentOff', childrenIds: ['student1'] },
    'users/teacherOff': { name: 'teacherOff', role: 'teacher', isActive: false },
    'users/supervisorOff': { name: 'supervisorOff', role: 'supervisor', isActive: false },
    'users/adminOff': { name: 'adminOff', role: 'admin', isActive: false },
    'users/mystery': { name: 'mystery', role: 'guest', isActive: true },
  });

  const parent2 = authed('parent2');
  await deny('unlinked parent2 gets h1', parent2.doc('halaqat/h1').get());
  await deny(
    'unlinked parent2 queries another roster',
    parent2.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await deny('parent2 lists halaqat', parent2.collection('halaqat').get());
  await deny('linked parent2 gets own child h2', parent2.doc('halaqat/h2').get());

  await deny('parent3 without parentProfiles gets h1', authed('parent3').doc('halaqat/h1').get());

  const parentOff = authed('parentOff');
  await deny('deactivated parentOff gets h1', parentOff.doc('halaqat/h1').get());
  await deny(
    'deactivated parentOff queries child roster',
    parentOff.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );

  await deny('parent1 lists halaqat', authed('parent1').collection('halaqat').get());
  await deny('parent1 gets h2', authed('parent1').doc('halaqat/h2').get());

  for (const uid of ['teacherOff', 'supervisorOff', 'adminOff', 'mystery', 'noUsersDoc']) {
    await deny(`${uid} gets h1`, authed(uid).doc('halaqat/h1').get());
    await deny(`${uid} lists halaqat`, authed(uid).collection('halaqat').get());
  }
});

test('Halaqa reads (J.9): Admin reads all; Teacher and Supervisor only their assigned Halaqat', async () => {
  await seedAll({
    'halaqat/h2': H2,
    'halaqat/h3': { name: 'H3', teacherId: 'teacher2', supervisorId: 'supervisor2', studentIds: [], status: 'active' },
    'users/supervisor2': { name: 'supervisor2', role: 'supervisor', isActive: true },
    'users/parent2': { name: 'parent2', role: 'parent', isActive: true },
    'users/parent3': { name: 'parent3', role: 'parent', isActive: true },
    'parentProfiles/parent3': { uid: 'parent3', childrenIds: ['student3'] },
  });

  const admin = authed('admin1');
  await allow('admin gets h2', admin.doc('halaqat/h2').get());
  await allow('admin lists halaqat', admin.collection('halaqat').get());
  await allow('admin queries by status', admin.collection('halaqat').where('status', '==', 'active').get());

  const teacher = authed('teacher1');
  await allow('teacher1 gets assigned h1', teacher.doc('halaqat/h1').get());
  await deny('teacher1 gets unassigned h2', teacher.doc('halaqat/h2').get());
  await allow(
    'teacher1 queries own active halaqat (app query)',
    teacher.collection('halaqat').where('teacherId', '==', 'teacher1').where('status', '==', 'active').get(),
  );
  await deny('teacher1 queries teacher2', teacher.collection('halaqat').where('teacherId', '==', 'teacher2').get());
  await deny('teacher1 lists halaqat', teacher.collection('halaqat').get());
  await deny('teacher1 queries by status', teacher.collection('halaqat').where('status', '==', 'active').get());

  const supervisor = authed('supervisor1');
  await allow('supervisor1 gets assigned h1', supervisor.doc('halaqat/h1').get());
  await allow('supervisor1 gets assigned h2', supervisor.doc('halaqat/h2').get());
  await deny('supervisor1 gets unassigned h3', supervisor.doc('halaqat/h3').get());
  await allow(
    'supervisor1 queries own halaqat (app query)',
    supervisor.collection('halaqat').where('supervisorId', '==', 'supervisor1').get(),
  );
  const unassigned = authed('supervisor2');
  await deny('unassigned supervisor2 gets h1', unassigned.doc('halaqat/h1').get());
  await deny(
    'supervisor2 queries supervisor1',
    unassigned.collection('halaqat').where('supervisorId', '==', 'supervisor1').get(),
  );
  await deny('supervisor2 lists halaqat', unassigned.collection('halaqat').get());

});

test("Halaqa reads (J.10): Parents never read halaqat directly (getParentChildHalaqat projects it)", async () => {
  await seedAll({
    'halaqat/h2': H2,
    'users/parent3': { name: 'parent3', role: 'parent', isActive: true },
    'parentProfiles/parent3': { uid: 'parent3', childrenIds: ['student3'] },
  });
  const parent = authed('parent1');
  await deny("parent1 gets child's h1", parent.doc('halaqat/h1').get());
  await deny(
    "parent1 queries the child's roster (former app query)",
    parent.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await deny('parent1 gets h2 (no child there)', parent.doc('halaqat/h2').get());
  await deny('parent1 lists halaqat', parent.collection('halaqat').get());
  await deny("parent3 gets child's h2", authed('parent3').doc('halaqat/h2').get());
  await deny('parent1 gets the canonical link of h1', parent.doc('halaqaMeetingLinks/h1').get());

  await setHalaqa('h1', { meetingLink: 'https://meet.example.test/h1' });
  await deny(
    'parent1 queries the roster while h1 carries a legacy link',
    parent.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
});

test('J.9 related reads: sessions are scoped to the Halaqa community', async () => {
  await seedAll({
    'users/teacherOff': { name: 'teacherOff', role: 'teacher', isActive: false },
    'users/supervisor2': { name: 'supervisor2', role: 'supervisor', isActive: true },
  });
  const unauthed = testEnv.unauthenticatedContext().firestore();

  for (const uid of ['admin1', 'teacher1', 'supervisor1', 'student1', 'parent1']) {
    await allow(`${uid} reads session s1 of h1`, authed(uid).doc('sessions/s1').get());
  }
  for (const uid of ['teacher2', 'supervisor2', 'student3', 'ghost', 'teacherOff']) {
    await deny(`${uid} reads session s1 of h1`, authed(uid).doc('sessions/s1').get());
  }
  await deny('unauthenticated reads session s1', unauthed.doc('sessions/s1').get());
  await deny('teacher1 lists sessions', authed('teacher1').collection('sessions').get());
  await allow('admin lists sessions', authed('admin1').collection('sessions').get());
});

// ── J.10 teacher HR data and calendar scope ────────────────────────────────

test('J.10 teacherProfiles: HR fields readable by Admin and the Teacher only', async () => {
  await seedAll({
    'users/teacherOff': { name: 'teacherOff', role: 'teacher', isActive: false },
    'teacherProfiles/teacher1': { uid: 'teacher1', name: 'teacher1', weeklyQuota: 10, performanceRating: 4 },
    'teacherProfiles/teacher2': { uid: 'teacher2', name: 'teacher2', weeklyQuota: 8, performanceRating: 2 },
    'teacherProfiles/teacherOff': { uid: 'teacherOff', name: 'teacherOff', weeklyQuota: 1 },
  });
  const admin = authed('admin1');
  await allow('admin gets teacherProfiles/teacher2', admin.doc('teacherProfiles/teacher2').get());
  await allow('admin lists teacherProfiles (admin teachers page)', admin.collection('teacherProfiles').get());

  const teacher = authed('teacher1');
  await allow('teacher1 gets own profile', teacher.doc('teacherProfiles/teacher1').get());
  await deny('teacher1 gets teacher2 profile', teacher.doc('teacherProfiles/teacher2').get());
  await deny('teacher1 lists teacherProfiles', teacher.collection('teacherProfiles').get());

  for (const uid of ['supervisor1', 'student1', 'parent1']) {
    await deny(`${uid} gets teacherProfiles/teacher1`, authed(uid).doc('teacherProfiles/teacher1').get());
    await deny(`${uid} lists teacherProfiles`, authed(uid).collection('teacherProfiles').get());
  }
  await deny(
    'supervisor1 name lookup by documentId in (removed app query)',
    authed('supervisor1')
      .collection('teacherProfiles')
      .where(firebase.firestore.FieldPath.documentId(), 'in', ['teacher1'])
      .get(),
  );
  await deny('deactivated teacherOff gets own profile', authed('teacherOff').doc('teacherProfiles/teacherOff').get());
  await deny('profile-less account gets a teacher profile', authed('ghost').doc('teacherProfiles/teacher1').get());
  await deny(
    'unauthenticated gets a teacher profile',
    testEnv.unauthenticatedContext().firestore().doc('teacherProfiles/teacher1').get(),
  );

  await allow(
    'teacher1 still edits own non-HR fields',
    teacher.doc('teacherProfiles/teacher1').update({ bio: 'x' }),
  );
  await deny(
    'teacher1 cannot edit own weeklyQuota',
    teacher.doc('teacherProfiles/teacher1').update({ weeklyQuota: 99 }),
  );
});

test('J.10 name lookups: supervisor resolves teacher names from users, not teacherProfiles', async () => {
  const supervisor = authed('supervisor1');
  const byId = (col, ids) =>
    supervisor.collection(col).where(firebase.firestore.FieldPath.documentId(), 'in', ids).get();
  // P1-5: getUserDisplayNames reads studentProfiles one document at a time;
  // a denied or missing profile falls through to users.
  await allow('supervisor1 gets studentProfiles/student1 (getUserDisplayNames)', supervisor.doc('studentProfiles/student1').get());
  await deny('supervisor1 studentProfiles documentId in (list)', byId('studentProfiles', ['student1']));
  const users = await allow(
    'supervisor1 users documentId in (getUserDisplayNames fallback)',
    byId('users', ['teacher1', 'teacher2']),
  );
  if (users.size !== 2) throw new Error('teacher names not resolvable from users');
  await allow('teacher1 gets users/teacher2 (chat participant)', authed('teacher1').doc('users/teacher2').get());

  // Real getUserDisplayNames inputs: the day board passes teacher ids, the
  // teacher classes page passes supervisor ids; the per-id studentProfiles
  // get is denied for ids that are not served students, and the client
  // falls back to users.
  await deny('supervisor1 gets studentProfiles/teacher1 (day board, step 1)', supervisor.doc('studentProfiles/teacher1').get());
  const teacher = authed('teacher1');
  const teacherById = (col, ids) =>
    teacher.collection(col).where(firebase.firestore.FieldPath.documentId(), 'in', ids).get();
  await deny('teacher1 gets studentProfiles/supervisor1 (classes page, step 1)', teacher.doc('studentProfiles/supervisor1').get());
  const sup = await allow('teacher1 users documentId in supervisor ids (classes page, step 2)', teacherById('users', ['supervisor1']));
  if (sup.size !== 1) throw new Error('supervisor name not resolvable from users');
  await deny(
    'teacher1 teacherProfiles documentId in [self, other]',
    teacherById('teacherProfiles', ['teacher1', 'teacher2']),
  );
});

test('J.10 query-shape bypasses: in / != / not-in / array-contains-any never widen scope', async () => {
  await seedCalendar();
  const teacher = authed('teacher1');
  const events = teacher.collection('calendarEvents');
  await deny("teacher1 calendar halaqaId in ['h1','h2']", events.where('halaqaId', 'in', ['h1', 'h2']).get());
  await deny("teacher1 calendar halaqaId != 'h2'", events.where('halaqaId', '!=', 'h2').get());
  await deny("teacher1 calendar halaqaId not-in ['h2']", events.where('halaqaId', 'not-in', ['h2']).get());
  await deny("teacher1 calendar halaqaId in ['h2', null]", events.where('halaqaId', 'in', ['h2', null]).get());

  const halaqat = (uid) => authed(uid).collection('halaqat');
  await deny("teacher1 halaqat teacherId in ['teacher1','teacher2']", halaqat('teacher1').where('teacherId', 'in', ['teacher1', 'teacher2']).get());
  await deny("teacher1 halaqat teacherId != 'x'", halaqat('teacher1').where('teacherId', '!=', 'x').get());
  await deny(
    'student1 halaqat studentIds array-contains-any [student1, student3]',
    halaqat('student1').where('studentIds', 'array-contains-any', ['student1', 'student3']).get(),
  );
  await deny(
    'supervisor1 halaqaMeetingLinks list by documentId',
    authed('supervisor1').collection('halaqaMeetingLinks').where(firebase.firestore.FieldPath.documentId(), '==', 'h1').get(),
  );
});

test('J.10 calendarEvents: a general event created in the client shape is visible to every active role', async () => {
  await seedCalendar();
  await allow(
    'admin creates a general event with halaqaId: null (CalendarEventModel.toCreateData)',
    authed('admin1').collection('calendarEvents').doc('eAdminGeneral').set({
      title: 'عطلة',
      type: 'holiday',
      date: new Date('2026-10-20T10:00:00Z'),
      halaqaId: null,
      createdBy: 'admin1',
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
    }),
  );
  for (const uid of ['supervisor1', 'teacher1', 'student1', 'parent1', 'supervisor2', 'parent3']) {
    const snap = await allow(`${uid} general (isNull) month query`, monthQuery(authed(uid), null));
    const ids = snap.docs.map((d) => d.id).sort();
    if (JSON.stringify(ids) !== JSON.stringify(['eAdminGeneral', 'eNull'])) {
      throw new Error(`${uid}: unexpected general events ${ids.join(',')}`);
    }
  }
  // A general event stored without the field (pre-fix data) is still
  // readable by get but never returned by the isNull query.
  await allow('teacher1 gets the field-less general event', authed('teacher1').doc('calendarEvents/eGeneral').get());
});

test('J.10 calendarEvents / teacherProfiles writes: update denied, delete only by Admin or the creating staff', async () => {
  await seedCalendar();
  await seedAll({ 'teacherProfiles/teacher1': { uid: 'teacher1', name: 'teacher1', weeklyQuota: 10 } });
  for (const uid of ALL_ROLES) {
    await deny(`${uid} updates eH1`, authed(uid).doc('calendarEvents/eH1').update({ title: 'x' }));
  }
  for (const uid of ['teacher1', 'student1', 'parent1', 'supervisor2']) {
    await deny(`${uid} deletes eH1 created by supervisor1`, authed(uid).doc('calendarEvents/eH1').delete());
  }
  await allow('supervisor1 deletes own eH1', authed('supervisor1').doc('calendarEvents/eH1').delete());
  await allow('admin deletes eGeneral', authed('admin1').doc('calendarEvents/eGeneral').delete());

  for (const uid of ALL_ROLES) {
    await deny(`${uid} creates a teacher profile`, authed(uid).doc('teacherProfiles/teacherX').set({ name: 'x' }));
    await deny(`${uid} deletes teacherProfiles/teacher1`, authed(uid).doc('teacherProfiles/teacher1').delete());
  }
  for (const uid of ['supervisor1', 'student1', 'parent1']) {
    await deny(`${uid} updates teacherProfiles/teacher1`, authed(uid).doc('teacherProfiles/teacher1').update({ bio: 'x' }));
  }
});

const MONTH_START = new Date('2026-10-01T00:00:00Z');
const MONTH_END = new Date('2026-11-01T00:00:00Z');

/** CalendarRemoteDataSourceImpl.getMonthEvents filters. */
function monthQuery(db, halaqaId) {
  return db
    .collection('calendarEvents')
    .where('date', '>=', MONTH_START)
    .where('date', '<', MONTH_END)
    .where('halaqaId', '==', halaqaId)
    .get();
}

async function seedCalendar() {
  const date = new Date('2026-10-10T10:00:00Z');
  await seedAll({
    'halaqat/h2': H2,
    'users/supervisor2': { name: 'supervisor2', role: 'supervisor', isActive: true },
    'users/teacherOff': { name: 'teacherOff', role: 'teacher', isActive: false },
    'users/parent3': { name: 'parent3', role: 'parent', isActive: true },
    'parentProfiles/parent3': { uid: 'parent3', childrenIds: ['student3'] },
    'calendarEvents/eH1': { title: 'h1', type: 'exam', date, halaqaId: 'h1', halaqaName: 'H1', createdBy: 'supervisor1' },
    'calendarEvents/eH2': { title: 'h2', type: 'exam', date, halaqaId: 'h2', halaqaName: 'H2', createdBy: 'supervisor1' },
    'calendarEvents/eGeneral': { title: 'general', type: 'holiday', date, createdBy: 'admin1' },
    'calendarEvents/eNull': { title: 'general null', type: 'holiday', date, halaqaId: null, createdBy: 'admin1' },
  });
}

test('J.10 calendarEvents reads: Halaqa events reach only that community; general events any active profile', async () => {
  await seedCalendar();
  const admin = authed('admin1');
  await allow('admin lists all events', admin.collection('calendarEvents').get());
  await allow('admin month query h2', monthQuery(admin, 'h2'));

  const supervisor = authed('supervisor1');
  const h1 = await allow('supervisor1 month query h1 (CalendarPage)', monthQuery(supervisor, 'h1'));
  if (h1.size !== 1 || h1.docs[0].id !== 'eH1') throw new Error('unexpected h1 month result');
  await allow('supervisor1 month query h2', monthQuery(supervisor, 'h2'));
  const general = await allow('supervisor1 general (isNull) query', monthQuery(supervisor, null));
  if (general.size !== 1 || general.docs[0].id !== 'eNull') {
    throw new Error('isNull query semantics changed (events without the field are not matched)');
  }

  for (const uid of ['teacher1', 'student1', 'parent1']) {
    await allow(`${uid} month query h1`, monthQuery(authed(uid), 'h1'));
    await allow(`${uid} gets eH1`, authed(uid).doc('calendarEvents/eH1').get());
    await deny(`${uid} month query h2`, monthQuery(authed(uid), 'h2'));
    await deny(`${uid} gets eH2`, authed(uid).doc('calendarEvents/eH2').get());
    await allow(`${uid} gets general event`, authed(uid).doc('calendarEvents/eGeneral').get());
    await allow(`${uid} general (isNull) query`, monthQuery(authed(uid), null));
    await deny(`${uid} lists every event`, authed(uid).collection('calendarEvents').get());
  }
  await allow('parent3 month query h2 (child on roster)', monthQuery(authed('parent3'), 'h2'));
  await deny('parent3 month query h1', monthQuery(authed('parent3'), 'h1'));

  const other = authed('supervisor2');
  await deny('unassigned supervisor2 month query h1', monthQuery(other, 'h1'));
  await deny('unassigned supervisor2 gets eH1', other.doc('calendarEvents/eH1').get());
  await deny('supervisor1 unfiltered month query', supervisor
    .collection('calendarEvents')
    .where('date', '>=', MONTH_START)
    .where('date', '<', MONTH_END)
    .get());

  for (const [label, db] of [
    ['deactivated teacherOff', authed('teacherOff')],
    ['profile-less account', authed('ghost')],
    ['unauthenticated', testEnv.unauthenticatedContext().firestore()],
  ]) {
    await deny(`${label} gets eH1`, db.doc('calendarEvents/eH1').get());
    await deny(`${label} gets general event`, db.doc('calendarEvents/eGeneral').get());
    await deny(`${label} general query`, monthQuery(db, null));
    await deny(`${label} lists events`, db.collection('calendarEvents').get());
  }

  await setHalaqa('h1', { studentIds: [] });
  await deny('student1 after removal from the roster gets eH1', authed('student1').doc('calendarEvents/eH1').get());
});

test('J.10 calendarEvents create: Halaqa staff for their Halaqa, Admin for general events', async () => {
  await seedCalendar();
  const event = (createdBy, extra = {}) => ({
    title: 'event',
    type: 'exam',
    date: new Date('2026-10-12T10:00:00Z'),
    createdBy,
    ...extra,
  });
  const create = (uid, data) => authed(uid).collection('calendarEvents').add(data);

  await allow('supervisor1 creates for h1', create('supervisor1', event('supervisor1', { halaqaId: 'h1', halaqaName: 'H1' })));
  await allow('teacher1 creates for h1', create('teacher1', event('teacher1', { halaqaId: 'h1' })));
  await allow('admin creates a general event', create('admin1', event('admin1')));
  await allow('admin creates for h2', create('admin1', event('admin1', { halaqaId: 'h2' })));

  await deny('teacher1 creates for h2', create('teacher1', event('teacher1', { halaqaId: 'h2' })));
  await deny('supervisor2 creates for h1', create('supervisor2', event('supervisor2', { halaqaId: 'h1' })));
  await deny('supervisor1 creates a general event', create('supervisor1', event('supervisor1')));
  await deny('supervisor1 creates with halaqaId null', create('supervisor1', event('supervisor1', { halaqaId: null })));
  await deny('supervisor1 creates for a missing halaqa', create('supervisor1', event('supervisor1', { halaqaId: 'nope' })));
  await deny('supervisor1 forges createdBy', create('supervisor1', event('teacher1', { halaqaId: 'h1' })));
  await deny('student1 creates for h1', create('student1', event('student1', { halaqaId: 'h1' })));
  await deny('parent1 creates for h1', create('parent1', event('parent1', { halaqaId: 'h1' })));
  await deny(
    'supervisor1 adds a contact field',
    create('supervisor1', event('supervisor1', { halaqaId: 'h1', phone: '0100' })),
  );
  await setHalaqa('h2', { teacherId: 'teacherOff' });
  await deny('deactivated assigned teacher creates for h2', create('teacherOff', event('teacherOff', { halaqaId: 'h2' })));
  await deny('profile-less account creates', create('ghost', event('ghost', { halaqaId: 'h1' })));
});

test('J.10 legacy meetingLink: no client role can create or update halaqat with a link', async () => {
  const link = 'https://meet.example.test/new';
  const unauthed = testEnv.unauthenticatedContext().firestore();
  for (const db of [...ALL_ROLES.map(authed), unauthed]) {
    await deny('client creates a halaqa with meetingLink', db.doc('halaqat/hNew').set({
      name: 'new', teacherId: 'teacher1', studentIds: [], schedule: [], meetingLink: link,
    }));
    await deny('client adds meetingLink to h1', db.doc('halaqat/h1').update({ meetingLink: link }));
    await deny('client merges meetingLink into h1', db.doc('halaqat/h1').set({ meetingLink: link }, { merge: true }));
    await deny('client overwrites h1 with meetingLink', db.doc('halaqat/h1').set({ name: 'H1', meetingLink: link }));
  }
  await deny('admin non-link edit is callable-only too', authed('admin1').doc('halaqat/h1').update({ name: 'H1b' }));
});

test('PH02 halaqa: membership locks are server-only', async () => {
  for (const uid of ALL_ROLES) {
    const db = authed(uid);
    await assertFails(db.doc('studentMembershipLocks/student1').get());
    await assertFails(db.doc('studentMembershipLocks/student3').set({ count: 0 }));
    await assertFails(db.doc('studentMembershipLocks/student1').delete());
  }
});

// ── Economy / server-owned profile fields ──────────────────────────────────

test('PH02 profile: halaqaId / coins / avatar / credit pointer are server-owned', async () => {
  const changes = [
    { halaqaId: 'h2' },
    { coins: 999 },
    { coins: 0 },
    { avatarId: 'wizard' },
    { unlockedAvatarIds: ['fox', 'wizard'] },
    { lastCompletedHomeworkId: 'hw1' },
    { lifecycle: 'archived' },
  ];
  for (const uid of ALL_ROLES) {
    for (const change of changes) {
      await assertFails(authed(uid).doc('studentProfiles/student1').update(change));
    }
  }
});

test('PH02 profile: award counters are server-owned; Admin safe edits remain', async () => {
  for (const uid of ALL_ROLES) {
    await assertFails(
      authed(uid).doc('studentProfiles/student1').update({
        points: 10,
        totalStars: 1,
      }),
    );
    await assertFails(
      authed(uid).doc('studentProfiles/student1').update({ totalStars: 1 }),
    );
  }
  await assertFails(
    authed('teacher1').doc('studentProfiles/student1').update({
      points: 10,
      coins: 60,
    }),
  );
  await assertSucceeds(
    authed('admin1').doc('studentProfiles/student1').update({ name: 'renamed' }),
  );
  await assertFails(
    authed('student1').doc('studentProfiles/student1').update({ points: 20 }),
  );
});

test('PH02 homework: student ticks tasks but never completes directly', async () => {
  const db = authed('student1');
  await assertSucceeds(
    db.doc('assignments/hw1').update({ tasks: [{ id: 't1', isCompleted: true }] }),
  );
  await assertFails(db.doc('assignments/hw1').update({ isSubmitted: true }));
  await assertFails(db.doc('assignments/hw1').update({ status: 'completed' }));
  await assertFails(db.doc('assignments/hw1').update({ completedAt: new Date() }));
});

test('PH02 homework: a submitted homework is frozen for the student', async () => {
  await seedAll({
    'assignments/hw1': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [{ id: 't1', isCompleted: true }],
      isSubmitted: true,
      status: 'pending',
    },
  });
  await assertFails(
    authed('student1').doc('assignments/hw1').update({
      tasks: [{ id: 't1', isCompleted: false }],
    }),
  );
});

test('PH02 minimization: Student/Parent never scan the users directory', async () => {
  for (const uid of ['parent1', 'student1']) {
    await assertFails(authed(uid).collection('users').get());
    await assertFails(
      authed(uid).collection('users').where('role', '==', 'student').get(),
    );
    await assertSucceeds(
      authed(uid).collection('users').where('role', '==', 'admin').get(),
    );
  }
  for (const uid of ['admin1', 'supervisor1', 'teacher1']) {
    await assertSucceeds(authed(uid).collection('users').get());
  }
  await assertSucceeds(authed('parent1').doc('users/teacher1').get());
});

// ── C16 audit + Supervisor authority ───────────────────────────────────────

test('PH02 C16: no client forges an audit, whatever actorRole it claims', async () => {
  await seedAll({
    'auditLogs/existing': {
      actorId: 'teacher1',
      actorRole: 'teacher',
      action: 'evaluation_create_or_correct',
      targetType: 'evaluation',
      targetId: 's1_student1_memorization',
      metadata: {},
      source: 'upsertSessionEvaluation',
    },
  });
  for (const uid of ALL_ROLES) {
    const db = authed(uid);
    for (const actorRole of ['admin', 'system', 'supervisor', 'teacher']) {
      await assertFails(
        db.collection('auditLogs').add({
          actorId: uid,
          actorRole,
          action: 'evaluation_create_or_correct',
          targetType: 'evaluation',
          targetId: 's1_student1_memorization',
          metadata: {},
          source: 'client',
          timestamp: new Date(),
        }),
      );
    }
    await assertFails(db.doc('auditLogs/existing').update({ actorRole: 'admin' }));
    await assertFails(db.doc('auditLogs/existing').delete());
  }
  for (const uid of ['supervisor1', 'teacher1', 'parent1', 'student1']) {
    await assertFails(authed(uid).doc('auditLogs/existing').get());
  }
  await assertSucceeds(authed('admin1').doc('auditLogs/existing').get());
});

test('PH02 achievements: every award write is callable-only (record-only and credited)', async () => {
  await seedAll({
    'users/supervisor2': { name: 's2', role: 'supervisor', isActive: true },
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor2',
      studentIds: ['student3'],
    },
  });
  const issue = (by, overrides = {}) => ({
    studentId: 'student1',
    type: 'star',
    halaqaId: 'h1',
    title: 'متميز',
    note: 'متميز',
    grantedBy: by,
    issuedBy: by,
    grantedAt: new Date(),
    date: new Date(),
    ...overrides,
  });
  // The former record-only client path is closed too: a client-generated id
  // could not make retries idempotent, so issueAchievement writes it now.
  await assertFails(authed('supervisor1').collection('achievements').add(issue('supervisor1')));
  await assertFails(authed('admin1').collection('achievements').add(issue('admin1')));
  await assertFails(authed('teacher1').doc('achievements/op_teacher1').set(issue('teacher1')));

  const sup = authed('supervisor1').collection('achievements');
  // Off-roster student (the empty-halaqa manual id path) / unsupervised halaqa.
  await assertFails(sup.add(issue('supervisor1', { studentId: 'student3' })));
  await assertFails(sup.add(issue('supervisor1', { halaqaId: 'h2', studentId: 'student3' })));
  await assertFails(
    authed('supervisor2').collection('achievements').add(issue('supervisor2')),
  );
  // Forged actor / credited multi-recipient shape.
  await assertFails(sup.add(issue('teacher1')));
  await assertFails(sup.add(issue('supervisor1', { issuedBy: 'admin1' })));
  await assertFails(
    sup.add(issue('supervisor1', { recipientStudentIds: ['student1', 'student3'] })),
  );
  await assertFails(sup.add(issue('supervisor1', { halaqaIds: ['h1', 'h2'] })));
  for (const uid of ['parent1', 'student1']) {
    await assertFails(authed(uid).collection('achievements').add(issue(uid)));
  }
});

test('PH02 Supervisor: reviews evaluations/attendance in scope, never edits them', async () => {
  await seedAll({ 'users/supervisor2': { name: 's2', role: 'supervisor', isActive: true } });
  await assertSucceeds(
    authed('supervisor1').doc('recitationRecords/s1_student1_memorization').get(),
  );
  await assertSucceeds(authed('supervisor1').doc('attendanceRecords/s1_student1').get());
  await assertFails(
    authed('supervisor2').doc('recitationRecords/s1_student1_memorization').get(),
  );
  await assertFails(authed('supervisor2').doc('attendanceRecords/s1_student1').get());
  const sup = authed('supervisor1');
  await assertFails(
    sup.doc('recitationRecords/s1_student1_memorization').update({ grade: 'y' }),
  );
  await assertFails(sup.doc('attendanceRecords/s1_student1').update({ status: 'absent' }));
  await assertFails(sup.doc('halaqat/h1').update({ studentIds: [] }));
});

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

test('PH02 payments: Parent still submits proof on an unpaid invoice', async () => {
  await assertSucceeds(
    authed('parent1').doc('payments/payDue').update({
      reviewStatus: 'pending_review',
      proofImageUrl: 'https://example.test/p.jpg',
      proofSubmittedAt: new Date(),
    }),
  );
});

test('PH02 payments: a paid invoice is final for the Parent too', async () => {
  await assertFails(
    authed('parent1').doc('payments/payPaid').update({
      proofImageUrl: 'https://example.test/again.jpg',
    }),
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

test('PH02 halaqa: client create denied (P0-04 callable); Admin non-conflict edits allowed', async () => {
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
  await assertSucceeds(db.doc('halaqat/h1').update({ name: 'حلقة معدلة' }));
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
  await assertSucceeds(admin.doc('halaqat/h1').update({ name: 'حلقة معدلة', status: 'active' }));
  const after = await assertSucceeds(admin.doc('halaqat/h1').get());
  if (after.data().meetingLink !== 'https://meet.example.test/a') {
    throw new Error('unrelated admin edit changed meetingLink');
  }
});

test('Halaqa reads: a student reads only Halaqat whose roster lists them', async () => {
  await seedAll({
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor1',
      studentIds: ['student3'],
      status: 'active',
      meetingLink: 'https://meet.example.test/h2',
    },
    'users/student4': { name: 'student4', role: 'student', isActive: false },
  });
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('halaqat/h1').update({ meetingLink: 'https://meet.example.test/h1' });
  });

  const student1 = authed('student1');
  const own = await assertSucceeds(student1.doc('halaqat/h1').get());
  if (own.data().meetingLink !== 'https://meet.example.test/h1') {
    throw new Error('member student could not read its own meetingLink');
  }
  await assertSucceeds(
    student1.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await assertFails(student1.doc('halaqat/h2').get());
  await assertFails(student1.doc('halaqat/missing').get());
  await assertFails(student1.collection('halaqat').get());
  await assertFails(student1.collection('halaqat').where('status', '==', 'active').get());
  await assertSucceeds(authed('student3').doc('halaqat/h2').get());

  await assertFails(authed('student4').doc('halaqat/h1').get());
  await assertFails(testEnv.unauthenticatedContext().firestore().doc('halaqat/h1').get());

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('halaqat/h1').update({ studentIds: [] });
  });
  await assertFails(student1.doc('halaqat/h1').get());
});

test('Halaqa reads: a deactivated student still on the roster reads only that Halaqa', async () => {
  await seedAll({
    'users/student5': { name: 'student5', role: 'student', isActive: false },
    'studentProfiles/student5': { uid: 'student5', halaqaId: 'h1', points: 0 },
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor1',
      studentIds: ['student3'],
      status: 'active',
    },
  });
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('halaqat/h1').update({ studentIds: ['student1', 'student5'] });
  });

  const student5 = authed('student5');
  await assertSucceeds(student5.doc('halaqat/h1').get());
  await assertFails(student5.doc('halaqat/h2').get());
  await assertFails(student5.collection('halaqat').get());
});

test('Halaqa reads: admin, teacher, supervisor and parent reads and queries unchanged', async () => {
  await seedAll({
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor1',
      studentIds: ['student3'],
      status: 'active',
    },
  });

  const admin = authed('admin1');
  await assertSucceeds(admin.doc('halaqat/h2').get());
  await assertSucceeds(admin.collection('halaqat').get());
  await assertSucceeds(admin.collection('halaqat').where('status', '==', 'active').get());

  const teacher = authed('teacher1');
  await assertSucceeds(teacher.doc('halaqat/h1').get());
  await assertSucceeds(teacher.doc('halaqat/h2').get());
  await assertSucceeds(
    teacher
      .collection('halaqat')
      .where('teacherId', '==', 'teacher1')
      .where('status', '==', 'active')
      .get(),
  );

  const supervisor = authed('supervisor1');
  await assertSucceeds(supervisor.doc('halaqat/h2').get());
  await assertSucceeds(
    supervisor.collection('halaqat').where('supervisorId', '==', 'supervisor1').get(),
  );

  const parent = authed('parent1');
  await assertSucceeds(parent.doc('halaqat/h1').get());
  await assertSucceeds(
    parent.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
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

test('PH02 achievements: Supervisor record-only issue is roster-scoped; credit is callable-only', async () => {
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
  await assertSucceeds(authed('supervisor1').collection('achievements').add(issue('supervisor1')));
  await assertSucceeds(authed('admin1').collection('achievements').add(issue('admin1')));

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

/**
 * PRODUCTION-HARDENING-01 — Firestore authorization (ALLOW + DENY).
 *
 * Two halaqat with disjoint staff/rosters so every allowed operation has a
 * matching cross-scope denial. Runs against the real firestore.rules.
 *
 * Run from repo root:
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "npm --prefix rules_test run test:ph01"
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
const rules = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

const LEGACY_DAY = 'h1_20260927';
const NEXT_DAY = 'h1_20260928';

let testEnv;

function authed(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function anon() {
  return testEnv.unauthenticatedContext().firestore();
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
    'users/supervisor2': user('supervisor'),
    'users/teacher1': user('teacher'),
    'users/teacher2': user('teacher'),
    'users/parent1': user('parent'),
    'users/parent2': user('parent'),
    'users/student1': user('student'),
    'users/student2': user('student'),
    'users/student3': user('student'),
    'users/legacyPhone': { ...user('student'), phone: '01000000000' },
    'userPrivate/student1': { phone: '01111111111' },
    'userPrivate/parent1': { phone: '01222222222' },
    'halaqat/h1': {
      name: 'H1',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
      schedule: [{ day: 0, startTime: '16:00', endTime: '17:00' }],
      status: 'active',
    },
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor2',
      studentIds: ['student2'],
      schedule: [{ day: 1, startTime: '16:00', endTime: '17:00' }],
      status: 'active',
    },
    'studentProfiles/student1': {
      uid: 'student1',
      halaqaId: 'h1',
      points: 0,
      totalStars: 0,
      overallProgressPercent: 10,
    },
    'studentProfiles/student2': { uid: 'student2', halaqaId: 'h2', points: 0 },
    'studentProfiles/student3': { uid: 'student3', points: 0 },
    'parentProfiles/parent1': { uid: 'parent1', childrenIds: ['student1'] },
    'parentProfiles/parent2': { uid: 'parent2', childrenIds: ['student2'] },
    'studentSearch/student1': {
      studentId: 'student1',
      fullName: 'Student1',
      fullNameNormalized: 'student1',
      visibleTo: ['teacher1', 'supervisor1'],
    },
    'payments/pay1': {
      parentId: 'parent1',
      studentId: 'student1',
      amount: 100,
      status: 'due',
      reviewStatus: 'pending_review',
    },
    'payments/pay2': {
      parentId: 'parent2',
      studentId: 'student2',
      amount: 50,
      status: 'due',
    },
    'paymentAccess/parent1': { parentId: 'parent1', status: 'suspended' },
    'paymentAccess/parent2': { parentId: 'parent2', status: 'ok' },
    'academySettings/paymentPublic': { vodafoneCashDestination: '010999' },
    'academySettings/pricingDefaults': { gracePeriodDays: 7 },
    'sessions/s1': {
      halaqaId: 'h1',
      teacherId: 'teacher1',
      status: 'scheduled',
    },
    'sessions/s2': {
      halaqaId: 'h2',
      teacherId: 'teacher2',
      status: 'scheduled',
    },
    [`attendanceRecords/${LEGACY_DAY}_student1`]: {
      studentId: 'student1',
      halaqaId: 'h1',
      status: 'present',
      recordedBy: 'teacher1',
      sessionId: LEGACY_DAY,
    },
    'attendanceRecords/s1_student1': {
      studentId: 'student1',
      halaqaId: 'h1',
      status: 'absent',
      recordedBy: 'teacher1',
      sessionId: 's1',
    },
    'attendanceRecords/h1_student1_20260926': {
      studentId: 'student1',
      halaqaId: 'h1',
      status: 'present',
      recordedBy: 'teacher1',
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
      tasks: [],
      isSubmitted: false,
    },
    'assignments/act1': {
      studentId: '',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'halaqaActivity',
      responseCount: 0,
      respondentStudentIds: [],
    },
    'notifications/student1_evt1': {
      audience: 'student1',
      title: 't',
      body: 'b',
      type: 'assignment',
      readBy: [],
    },
    'conversations/parent1_teacher1': {
      kind: 'direct',
      participantIds: ['parent1', 'teacher1'],
    },
    'conversations/halaqa_group_h1': {
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1', 'supervisor1', 'student1'],
    },
    'posts/post1': {
      authorId: 'teacher1',
      halaqaId: 'h1',
      audienceTarget: 'h1',
      likedBy: ['student2'],
      commentsCount: 0,
      isPinned: false,
    },
  });
});

// ── 1. Authentication ──────────────────────────────────────────────────────

test('PH01 auth: anonymous is denied protected data', async () => {
  const db = anon();
  await assertFails(db.doc(`attendanceRecords/${LEGACY_DAY}_student1`).get());
  await assertFails(db.doc('payments/pay1').get());
  await assertFails(db.doc('halaqat/h1').get());
  await assertFails(db.doc('studentProfiles/student1').get());
  await assertFails(db.doc('notifications/student1_evt1').get());
  await assertFails(db.doc('conversations/parent1_teacher1').get());
  await assertFails(db.doc('userPrivate/student1').get());
  await assertFails(
    db.doc('absenceRequests/h1_student1_20260927').set({ status: 'pending' }),
  );
});

test('PH01 auth: authenticated access only where the contract allows', async () => {
  await assertSucceeds(
    authed('student1').doc(`attendanceRecords/${LEGACY_DAY}_student1`).get(),
  );
  await assertSucceeds(authed('student1').doc('halaqat/h1').get());
  await assertFails(authed('student1').doc('payments/pay1').get());
});

// ── 2. Roles / Admin-only operations ───────────────────────────────────────

test('PH01 roles: non-Admin roles are denied Admin operations', async () => {
  for (const uid of ['student1', 'parent1', 'teacher1', 'supervisor1']) {
    const db = authed(uid);
    await assertFails(
      db.doc('pricingRules/r1').set({ amount: 1, active: true }),
    );
    await assertFails(
      db.doc('academySettings/pricingDefaults').set({ gracePeriodDays: 0 }),
    );
    await assertFails(db.doc('academySettings/pricingDefaults').get());
    await assertFails(db.doc(`users/${uid}`).update({ role: 'admin' }));
    await assertFails(db.doc('users/student2').update({ role: 'teacher' }));
    await assertFails(db.doc('users/student2').update({ isActive: false }));
    await assertFails(
      db.doc('halaqat/h9').set({ name: 'x', schedule: [{ day: 1 }] }),
    );
    await assertFails(db.doc('auditLogs/x').set({ action: 'forged' }));
    await assertFails(
      db.doc('users/new').set({ name: 'x', role: 'student', isActive: true }),
    );
  }
});

// P0-04: D8 (>=1 slot) and the D9 conflict engine live in adminCreateHalaqa;
// no client — not even Admin — creates a Halaqa document directly.
test('PH01 roles: Halaqa creation is callable-only (D8 enforced server-side)', async () => {
  const db = authed('admin1');
  await assertFails(db.doc('halaqat/h9').set({ name: 'x', schedule: [] }));
  await assertFails(db.doc('halaqat/h9').set({ name: 'x' }));
  await assertFails(
    db.doc('halaqat/h9').set({ name: 'x', schedule: [{ day: 1 }] }),
  );
});

test('PH01 roles: no client may hard-delete a halaqa', async () => {
  for (const uid of ['admin1', 'supervisor1', 'teacher1']) {
    await assertFails(authed(uid).doc('halaqat/h1').delete());
  }
});

// ── 3. Phone privacy (C16 / D16) ───────────────────────────────────────────

test('PH01 phone: only Admin reads another user phone', async () => {
  // userPrivate docs that still carry a phone are closed to every client.
  await assertFails(authed('admin1').doc('userPrivate/student1').get());
  await assertSucceeds(authed('admin1').doc('users/legacyPhone').get());
  for (const uid of ['parent2', 'teacher1', 'supervisor1', 'student2']) {
    await assertFails(authed(uid).doc('userPrivate/student1').get());
    await assertFails(authed(uid).doc('userPrivate/parent1').get());
    await assertFails(authed(uid).doc('users/legacyPhone').get());
  }
});

// Rules cannot prove field *absence* for list queries, so a legacy users doc
// that still carries `phone` would be listable. Clients can never write phone
// onto users (tested above); the no-phone data cleanup must remove every
// legacy phone before deploy (PH-01 deploy gate).
test('PH01 phone: post-migration non-Admin users lists carry no phone', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/legacyPhone').delete();
  });
  const snap = await assertSucceeds(authed('teacher1').collection('users').get());
  for (const doc of snap.docs) {
    if ('phone' in doc.data()) {
      throw new Error(`phone leaked on users/${doc.id}`);
    }
  }
  await assertSucceeds(
    authed('parent1').collection('users').where('role', '==', 'admin').get(),
  );
  await assertFails(anon().collection('users').get());
});

test('PH01 phone: no client can write phone onto identity or profiles', async () => {
  await assertFails(
    authed('student1').doc('users/student1').update({ phone: '0100' }),
  );
  await assertFails(
    authed('admin1').doc('users/student1').update({ phone: '0100' }),
  );
  await assertFails(
    authed('parent1').doc('parentProfiles/parent1').update({ phone: '0100' }),
  );
  await assertFails(authed('student1').doc('userPrivate/student1').set({ phone: '1' }));
});

test('PH01 phone: no client can add any contact field (no-phone policy)', async () => {
  for (const key of ['phoneNumber', 'mobile', 'whatsapp', 'parentPhone', 'guardianPhone']) {
    await assertFails(authed('student1').doc('users/student1').update({ [key]: '0501234567' }));
    await assertFails(authed('admin1').doc('users/student1').update({ [key]: '0501234567' }));
  }
  await assertSucceeds(authed('student1').doc('users/student1').update({ name: 'Renamed' }));
});

test('PH01 phone: user-written activity replies and progress reject contact fields', async () => {
  const replies = authed('student1').collection('assignments/act1/activityResponses');
  await assertFails(replies.add({ studentId: 'student1', text: 'x', phone: '0501234567' }));
  await assertSucceeds(replies.add({ studentId: 'student1', text: 'x' }));

  const progress = authed('student1').doc('listeningProgress/student1_s1');
  await assertFails(progress.set({ userId: 'student1', whatsapp: '0501234567' }));
  await assertSucceeds(progress.set({ userId: 'student1', surahAudioId: 's1' }));
  await assertFails(progress.update({ mobile: '0501234567' }));
});

// ── 4. Payments (C2 / C3 / C4 / C5) ────────────────────────────────────────

test('PH01 payments: Parent reads only own invoice + access state', async () => {
  const db = authed('parent1');
  await assertSucceeds(db.doc('payments/pay1').get());
  await assertSucceeds(db.doc('paymentAccess/parent1').get());
  await assertSucceeds(db.doc('academySettings/paymentPublic').get());
  await assertFails(db.doc('payments/pay2').get());
  await assertFails(db.doc('paymentAccess/parent2').get());
  await assertSucceeds(
    db.collection('payments').where('parentId', '==', 'parent1').get(),
  );
  await assertFails(db.collection('payments').get());
});

test('PH01 payments: Parent cannot mutate access, pay, overdue or approve', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('paymentAccess/parent1').update({ status: 'ok' }));
  await assertFails(
    db.doc('paymentAccess/parent1').set({ parentId: 'parent1', status: 'ok' }),
  );
  await assertFails(db.doc('payments/pay1').update({ status: 'paid' }));
  await assertFails(db.doc('payments/pay1').update({ status: 'overdue' }));
  await assertFails(db.doc('payments/pay1').update({ amount: 1 }));
  await assertFails(
    db.doc('payments/pay1').update({
      reviewStatus: 'approved',
      reviewedBy: 'parent1',
    }),
  );
  await assertFails(db.doc('payments/new').set({ parentId: 'parent1', amount: 1 }));
});

test('PH01 payments: scoped Supervisor reads but reviews only via callable (PH-02)', async () => {
  await assertSucceeds(authed('supervisor1').doc('payments/pay1').get());
  await assertFails(
    authed('supervisor1').doc('payments/pay1').update({
      status: 'paid',
      reviewStatus: 'approved',
      reviewedBy: 'supervisor1',
      paidAt: new Date(),
    }),
  );
});

test('PH01 payments: unauthorized reviewer denied', async () => {
  const approve = {
    status: 'paid',
    reviewStatus: 'approved',
    reviewedBy: 'supervisor2',
  };
  await assertFails(authed('supervisor2').doc('payments/pay1').update(approve));
  await assertFails(authed('supervisor2').doc('payments/pay1').get());
  await assertFails(authed('teacher1').doc('payments/pay1').update(approve));
  await assertFails(authed('teacher1').doc('payments/pay1').get());
  await assertFails(authed('student1').doc('payments/pay1').update(approve));
});

test('PH01 payments: Supervisor cannot exceed reviewer powers', async () => {
  const db = authed('supervisor1');
  await assertFails(db.doc('payments/pay1').update({ status: 'overdue' }));
  await assertFails(db.doc('payments/pay1').update({ amount: 1 }));
  await assertFails(db.doc('payments/pay1').update({ status: 'paid' }));
  await assertFails(
    db.doc('payments/pay1').update({
      reviewStatus: 'approved',
      reviewedBy: 'admin1',
    }),
  );
  await assertFails(db.doc('paymentAccess/parent1').update({ status: 'ok' }));
  await assertFails(db.doc('paymentAccess/parent1').get());
  await assertFails(db.doc('pricingRules/r1').set({ amount: 1 }));
});

test('PH01 payments: Admin reviews; snapshot + overdue stay server-owned', async () => {
  const db = authed('admin1');
  await assertSucceeds(db.doc('payments/pay2').get());
  await assertSucceeds(db.doc('paymentAccess/parent1').get());
  // PH-02: Admin review goes through reviewPaymentProof, not a client write.
  await assertFails(
    db.doc('payments/pay1').update({
      status: 'paid',
      reviewStatus: 'approved',
      reviewedBy: 'admin1',
      paidAt: new Date(),
    }),
  );
  await assertFails(db.doc('payments/pay2').update({ amount: 999 }));
  await assertFails(db.doc('payments/pay2').update({ status: 'overdue' }));
  await assertFails(db.doc('payments/pay2').update({ parentId: 'parent1' }));
  // Reinstatement is the adminReinstatePaymentAccess CF, never a client write.
  await assertFails(db.doc('paymentAccess/parent1').update({ status: 'ok' }));
  await assertSucceeds(db.doc('pricingRules/r1').set({ amount: 1, active: true }));
});

test('PH01 settings: paymentPublic carries only the locked public fields', async () => {
  const db = authed('admin1');
  await assertSucceeds(
    db.doc('academySettings/paymentPublic').set({
      vodafoneCashDestination: '01012345678',
      updatedBy: 'admin1',
    }),
  );
  await assertFails(
    db.doc('academySettings/paymentPublic').set({
      vodafoneCashDestination: '01012345678',
      gracePeriodDays: 7,
    }),
  );
  await assertFails(
    db.doc('academySettings/paymentPublic').set({
      vodafoneCashDestination: '0101',
      adminNotes: 'internal',
    }),
  );
  for (const uid of ['teacher1', 'student1', 'supervisor1']) {
    await assertFails(authed(uid).doc('academySettings/paymentPublic').get());
  }
});

// DEVELOPMENT PLACEHOLDERS — not real academy payment details.
const DEV_WALLET = '01000000000';
const DEV_INSTAPAY = 'dev-placeholder@instapay';

test('PH01 settings: InstaPay destination is a separate, bounded field', async () => {
  const admin = authed('admin1');
  await assertSucceeds(
    admin.doc('academySettings/paymentPublic').set({ instapayDestination: DEV_INSTAPAY }),
  );
  await assertSucceeds(
    admin.doc('academySettings/paymentPublic').set(
      { vodafoneCashDestination: DEV_WALLET, updatedBy: 'admin1' },
      { merge: true },
    ),
  );
  await assertFails(
    admin.doc('academySettings/paymentPublic').set({ instapayDestination: 42 }),
  );
  await assertFails(
    admin.doc('academySettings/paymentPublic').set({ instapayDestination: 'x'.repeat(201) }),
  );
  await assertFails(
    admin.doc('academySettings/paymentPublic').set({ vodafoneCashDestination: '0'.repeat(33) }),
  );
  await assertFails(
    admin.doc('academySettings/paymentPublic').set({ instapayPhone: DEV_WALLET }),
  );
  for (const uid of ['parent1', 'teacher1', 'student1', 'supervisor1']) {
    await assertFails(
      authed(uid).doc('academySettings/paymentPublic').set(
        { instapayDestination: DEV_INSTAPAY },
        { merge: true },
      ),
    );
  }
});

// ── 5. Parent / student relationship (D12) ─────────────────────────────────

test('PH01 relationship: childrenIds and cross-family profiles are protected', async () => {
  await assertFails(
    authed('parent1').doc('parentProfiles/parent1').update({
      childrenIds: ['student1', 'student2'],
    }),
  );
  await assertFails(
    authed('parent1').doc('parentProfiles/parent2').update({ name: 'x' }),
  );
  await assertFails(authed('parent2').doc('parentProfiles/parent1').get());
  await assertFails(authed('student1').doc('parentProfiles/parent1').get());
  await assertFails(
    authed('supervisor1').doc('parentProfiles/parent1').update({
      childrenIds: ['student3'],
    }),
  );
  await assertSucceeds(authed('parent1').doc('parentProfiles/parent1').get());
  await assertSucceeds(
    authed('parent1').doc('parentProfiles/parent1').update({ name: 'Parent' }),
  );
});

test('PH01 relationship: student cannot rewrite pointer, progress or links', async () => {
  const db = authed('student1');
  await assertFails(
    db.doc('studentProfiles/student1').update({ halaqaId: 'h2' }),
  );
  await assertFails(
    db.doc('studentProfiles/student1').update({ overallProgressPercent: 100 }),
  );
  await assertFails(db.doc('studentProfiles/student1').update({ parentId: 'x' }));
  await assertFails(db.doc('studentProfiles/student2').update({ avatarId: 'a' }));
  // PH-02: avatar selection is the purchaseAvatar callable.
  await assertFails(
    db.doc('studentProfiles/student1').update({ avatarId: 'a2' }),
  );
});

test('PH01 relationship: membership links are callable-only (PH-02)', async () => {
  await assertFails(
    authed('supervisor1').doc('halaqat/h1').update({
      studentIds: ['student1', 'student3'],
    }),
  );
  await assertFails(
    authed('supervisor1').doc('studentProfiles/student3').update({
      halaqaId: 'h1',
    }),
  );
  await assertFails(
    authed('admin1').doc('studentProfiles/student3').update({
      halaqaId: 'h1',
    }),
  );
  await assertFails(
    authed('supervisor2').doc('studentProfiles/student3').update({
      halaqaId: 'h2',
    }),
  );
  await assertFails(
    authed('supervisor1').doc('studentProfiles/student2').update({
      halaqaId: 'h1',
    }),
  );
});

// PH-02 closure: award counters moved to the grantAward callable.
test('PH01 relationship: award increments are callable-only', async () => {
  await assertFails(
    authed('teacher1').doc('studentProfiles/student1').update({
      points: 10,
      totalStars: 1,
    }),
  );
  await assertFails(
    authed('teacher2').doc('studentProfiles/student1').update({ points: 20 }),
  );
  await assertFails(
    authed('teacher1').doc('studentProfiles/student1').update({
      points: 100000,
    }),
  );
  await assertFails(
    authed('teacher1').doc('studentProfiles/student1').update({
      overallProgressPercent: 99,
    }),
  );
});

// ── 6. Halaqa membership ───────────────────────────────────────────────────

test('PH01 halaqa: unauthorized membership mutations denied', async () => {
  await assertFails(
    authed('student3').doc('halaqat/h1').update({
      studentIds: ['student1', 'student3'],
    }),
  );
  await assertFails(
    authed('student1').doc('halaqat/h1').update({ studentIds: [] }),
  );
  await assertFails(
    authed('parent2').doc('halaqat/h1').update({
      studentIds: ['student1', 'student2'],
    }),
  );
  await assertFails(
    authed('teacher1').doc('halaqat/h1').update({
      studentIds: ['student1', 'student3'],
    }),
  );
  await assertFails(
    authed('teacher2').doc('halaqat/h1').update({ teacherId: 'teacher2' }),
  );
  await assertFails(authed('teacher1').doc('halaqat/h1').update({ name: 'x' }));
  await assertFails(
    authed('supervisor2').doc('halaqat/h1').update({
      studentIds: ['student1', 'student3'],
    }),
  );
});

test('PH01 halaqa: Supervisor admits one, never removes or restaffs', async () => {
  const db = authed('supervisor1');
  await assertFails(db.doc('halaqat/h1').update({ studentIds: [] }));
  await assertFails(
    db.doc('halaqat/h1').update({
      studentIds: ['student1', 'student2', 'student3'],
    }),
  );
  await assertFails(db.doc('halaqat/h1').update({ teacherId: 'teacher2' }));
  await assertFails(
    db.doc('halaqat/h1').update({ supervisorId: 'supervisor2' }),
  );
  // PH-02: admission is admitStudentToHalaqa (max-2 cap server-side).
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'student3'] }),
  );
});

// P0-04: teacherId / schedule changes bypass the weekly conflict engine, so
// they are server-only; Admin keeps supervisor / name / link edits.
test('PH01 halaqa: Admin edits non-conflict fields; roster/teacher/schedule are callable-only', async () => {
  await assertSucceeds(
    authed('admin1').doc('halaqat/h1').update({ supervisorId: 'supervisor1', name: 'y' }),
  );
  await assertFails(
    authed('admin1').doc('halaqat/h1').update({ teacherId: 'teacher2' }),
  );
  await assertFails(
    authed('admin1').doc('halaqat/h1').update({ schedule: [] }),
  );
  await assertFails(
    authed('admin1').doc('halaqat/h1').update({ studentIds: ['student3'] }),
  );
});

// ── 7. Sessions / attendance (C6 / D10) ────────────────────────────────────

function mark(studentId, sessionId, overrides = {}) {
  return {
    studentId,
    studentName: studentId,
    halaqaId: 'h1',
    date: new Date('2026-09-28T00:00:00Z'),
    status: 'present',
    recordedBy: 'teacher1',
    sessionId,
    ...overrides,
  };
}

test('PH01 attendance: even the halaqa Teacher writes only via callable (PH-02)', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc(`attendanceRecords/${NEXT_DAY}_student1`).set(mark('student1', NEXT_DAY)),
  );
  await assertFails(
    db.doc('attendanceRecords/s1_student1').set(
      mark('student1', 's1', { status: 'late' }),
      { merge: true },
    ),
  );
  await assertFails(
    authed('admin1').doc('attendanceRecords/s1_student1').update({ status: 'late' }),
  );
});

test('PH01 attendance: forged session / id / roster / marker denied', async () => {
  const db = authed('teacher1');
  // Session of another halaqa.
  await assertFails(
    db.doc('attendanceRecords/s2_student1').set(mark('student1', 's2')),
  );
  await assertFails(
    db.doc('attendanceRecords/h2_20260928_student1').set(
      mark('student1', 'h2_20260928'),
    ),
  );
  // Non-existent real session id that is not a legacy day id.
  await assertFails(
    db.doc('attendanceRecords/ghost_student1').set(mark('student1', 'ghost')),
  );
  // Doc id not bound to session + student.
  await assertFails(
    db.doc('attendanceRecords/random').set(mark('student1', NEXT_DAY)),
  );
  // Student not on this halaqa roster.
  await assertFails(
    db.doc(`attendanceRecords/${NEXT_DAY}_student2`).set(
      mark('student2', NEXT_DAY),
    ),
  );
  // recordedBy spoofing.
  await assertFails(
    db.doc(`attendanceRecords/${NEXT_DAY}_student1`).set(
      mark('student1', NEXT_DAY, { recordedBy: 'teacher2' }),
    ),
  );
  // Invalid status.
  await assertFails(
    db.doc(`attendanceRecords/${NEXT_DAY}_student1`).set(
      mark('student1', NEXT_DAY, { status: 'vip' }),
    ),
  );
});

test('PH01 attendance: other roles cannot write attendance', async () => {
  const cases = [
    ['teacher2', { recordedBy: 'teacher2' }],
    ['student1', { recordedBy: 'student1' }],
    ['parent1', { recordedBy: 'parent1' }],
    ['supervisor1', { recordedBy: 'supervisor1' }],
  ];
  for (const [uid, overrides] of cases) {
    await assertFails(
      authed(uid)
        .doc(`attendanceRecords/${NEXT_DAY}_student1`)
        .set(mark('student1', NEXT_DAY, overrides)),
    );
    await assertFails(
      authed(uid)
        .doc(`attendanceRecords/${LEGACY_DAY}_student1`)
        .update({ status: 'absent' }),
    );
  }
});

test('PH01 attendance: history is never client-deletable (PH-02)', async () => {
  await assertFails(
    authed('teacher1').doc(`attendanceRecords/${LEGACY_DAY}_student1`).delete(),
  );
  await assertFails(
    authed('admin1').doc(`attendanceRecords/${LEGACY_DAY}_student1`).delete(),
  );
  await assertFails(
    authed('teacher2').doc('attendanceRecords/h1_student1_20260926').delete(),
  );
  // Legacy duplicates are retired by recordSessionAttendance server-side.
  await assertFails(
    authed('teacher1').doc('attendanceRecords/h1_student1_20260926').delete(),
  );
});

test('PH01 attendance: reads are scoped to student / linked parent / halaqa staff', async () => {
  const path = `attendanceRecords/${LEGACY_DAY}_student1`;
  await assertSucceeds(authed('student1').doc(path).get());
  await assertSucceeds(authed('parent1').doc(path).get());
  await assertSucceeds(authed('teacher1').doc(path).get());
  await assertSucceeds(authed('supervisor1').doc(path).get());
  await assertSucceeds(authed('admin1').doc(path).get());
  await assertFails(authed('student2').doc(path).get());
  await assertFails(authed('parent2').doc(path).get());
  await assertFails(authed('teacher2').doc(path).get());

  const col = (uid) => authed(uid).collection('attendanceRecords');
  await assertSucceeds(col('teacher1').where('halaqaId', '==', 'h1').get());
  await assertFails(col('teacher2').where('halaqaId', '==', 'h1').get());
  await assertSucceeds(col('student1').where('studentId', '==', 'student1').get());
  await assertFails(col('student2').where('studentId', '==', 'student1').get());
  await assertSucceeds(col('parent1').where('studentId', '==', 'student1').get());
  await assertFails(col('parent2').where('studentId', '==', 'student1').get());
  // Teacher student-profile view (roster-derived C13 scope).
  await assertSucceeds(col('teacher1').where('studentId', '==', 'student1').get());
  await assertFails(col('teacher2').where('studentId', '==', 'student1').get());
  await assertFails(col('teacher1').get());
});

// ── 8. Evaluations (D7) ────────────────────────────────────────────────────

function evaluation(sessionId, overrides = {}) {
  return {
    studentId: 'student1',
    studentName: 'student1',
    teacherId: 'teacher1',
    halaqaId: 'h1',
    date: new Date('2026-09-27T00:00:00Z'),
    type: 'memorization',
    versesRange: '',
    sessionId,
    grade: 'ممتاز',
    behaviorGrade: 'ممتاز',
    reviewStatus: 'reviewed',
    ...overrides,
  };
}

test('PH01 evaluation: live evaluation is callable-only even when Present (PH-02)', async () => {
  await assertFails(
    authed('teacher1')
      .doc(`recitationRecords/${LEGACY_DAY}_student1_memorization`)
      .set(evaluation(LEGACY_DAY), { merge: true }),
  );
});

test('PH01 evaluation: Absent / unmarked student cannot be evaluated (D7)', async () => {
  const db = authed('teacher1');
  // s1: student1 is marked absent.
  await assertFails(
    db.doc('recitationRecords/s1_student1_memorization').set(evaluation('s1')),
  );
  // Next day: no attendance at all.
  await assertFails(
    db
      .doc(`recitationRecords/${NEXT_DAY}_student1_review`)
      .set(evaluation(NEXT_DAY, { type: 'review' })),
  );
});

test('PH01 evaluation: forged session / teacher / id denied', async () => {
  await assertFails(
    authed('teacher2')
      .doc(`recitationRecords/${LEGACY_DAY}_student1_memorization`)
      .set(evaluation(LEGACY_DAY, { teacherId: 'teacher2' })),
  );
  await assertFails(
    authed('teacher1')
      .doc('recitationRecords/s2_student1_memorization')
      .set(evaluation('s2')),
  );
  await assertFails(
    authed('teacher1')
      .doc('recitationRecords/anyid')
      .set(evaluation(LEGACY_DAY)),
  );
  await assertFails(
    authed('teacher1')
      .doc(`recitationRecords/${LEGACY_DAY}_student1_memorization`)
      .set(evaluation(LEGACY_DAY, { teacherId: 'teacher2' })),
  );
});

test('PH01 evaluation: students and parents cannot fabricate or edit grades', async () => {
  await assertFails(
    authed('student1')
      .doc(`recitationRecords/${LEGACY_DAY}_student1_memorization`)
      .set(evaluation(LEGACY_DAY, { teacherId: 'student1' })),
  );
  await assertFails(
    authed('student1').collection('recitationRecords').add({
      studentId: 'student1',
      halaqaId: 'h1',
      reviewStatus: 'pending',
      grade: 'ممتاز',
    }),
  );
  await assertFails(
    authed('student1').doc('recitationRecords/pending1').update({
      reviewStatus: 'reviewed',
      grade: 'ممتاز',
    }),
  );
  await assertFails(
    authed('parent1').doc('recitationRecords/pending1').update({
      grade: 'ممتاز',
    }),
  );
});

test('PH01 evaluation: student submits own pending homework recitation', async () => {
  await assertSucceeds(
    authed('student1').collection('recitationRecords').add({
      studentId: 'student1',
      studentName: 's',
      teacherId: 'teacher1',
      halaqaId: 'h1',
      type: 'memorization',
      versesRange: '1-5',
      assignmentId: 'hw1',
      reviewStatus: 'pending',
    }),
  );
  await assertFails(
    authed('student2').collection('recitationRecords').add({
      studentId: 'student2',
      halaqaId: 'h1',
      reviewStatus: 'pending',
    }),
  );
  await assertFails(
    authed('student1').collection('recitationRecords').add({
      studentId: 'student1',
      halaqaId: 'h1',
      reviewStatus: 'pending',
      phone: '0501234567',
    }),
  );
});

test('PH01 evaluation: only the halaqa Teacher reviews a pending submission', async () => {
  const review = {
    reviewStatus: 'reviewed',
    grade: 'جيد',
    behaviorGrade: 'جيد',
  };
  await assertFails(authed('teacher2').doc('recitationRecords/pending1').update(review));
  await assertFails(authed('supervisor1').doc('recitationRecords/pending1').update(review));
  await assertFails(authed('teacher1').doc('recitationRecords/pending1').delete());
  await assertSucceeds(authed('teacher1').doc('recitationRecords/pending1').update(review));
});

// ── 9. Absence requests ────────────────────────────────────────────────────

const absence = (overrides = {}) => ({
  studentId: 'student1',
  halaqaId: 'h1',
  requestedBy: 'parent1',
  date: new Date('2026-09-29T00:00:00Z'),
  reason: 'مرض',
  status: 'pending',
  ...overrides,
});

test('PH01 absence: linked Parent submits; Teacher of halaqa classifies', async () => {
  const id = 'absenceRequests/h1_student1_20260929';
  // First submit pre-reads a missing doc (client existence probe).
  await assertSucceeds(authed('parent1').doc(id).get());
  await assertFails(authed('teacher1').doc(id).get());
  await assertFails(
    authed('parent2').doc(id).set(absence({ requestedBy: 'parent2' })),
  );
  await assertFails(authed('parent1').doc(id).set(absence({ status: 'approved' })));
  await assertFails(
    authed('parent1').doc('absenceRequests/whatever').set(absence()),
  );
  await assertSucceeds(authed('parent1').doc(id).set(absence()));

  await assertFails(
    authed('parent1').doc(id).update({ status: 'approved', reviewedBy: 'parent1' }),
  );
  await assertFails(
    authed('teacher2').doc(id).update({ status: 'approved', reviewedBy: 'teacher2' }),
  );
  await assertFails(
    authed('student1').doc(id).update({ status: 'approved', reviewedBy: 'student1' }),
  );
  await assertSucceeds(
    authed('teacher1').doc(id).update({ status: 'approved', reviewedBy: 'teacher1' }),
  );
  await assertFails(authed('parent1').doc(id).set(absence()));
  await assertFails(authed('admin1').doc(id).delete());
});

// ── 10. Teacher homework authorization ─────────────────────────────────────

test('PH01 homework: halaqa Teacher assigns; students update only own progress', async () => {
  const hw = {
    studentId: 'student1',
    halaqaId: 'h1',
    assignedBy: 'teacher1',
    kind: 'lessonHomework',
    tasks: [],
  };
  await assertSucceeds(authed('teacher1').collection('assignments').add(hw));
  await assertFails(
    authed('teacher2').collection('assignments').add({ ...hw, assignedBy: 'teacher2' }),
  );
  await assertFails(
    authed('teacher1').collection('assignments').add({ ...hw, studentId: 'student2' }),
  );
  await assertFails(
    authed('student1').collection('assignments').add({ ...hw, assignedBy: 'student1' }),
  );

  await assertSucceeds(
    authed('student1').doc('assignments/hw1').update({
      tasks: [{ id: 't1', done: true }],
    }),
  );
  await assertFails(authed('student1').doc('assignments/hw1').update({ halaqaId: 'h2' }));
  await assertFails(authed('student2').doc('assignments/hw1').update({ tasks: [] }));
  await assertFails(authed('teacher1').doc('assignments/hw1').delete());
  await assertFails(authed('parent2').doc('assignments/hw1').get());
});

test('PH01 homework: activity responses are roster-scoped', async () => {
  await assertSucceeds(
    authed('student1')
      .collection('assignments/act1/activityResponses')
      .add({ studentId: 'student1', text: 'x', createdAt: new Date() }),
  );
  await assertSucceeds(
    authed('student1').doc('assignments/act1').set(
      { responseCount: 1, respondentStudentIds: ['student1'] },
      { merge: true },
    ),
  );
  await assertFails(
    authed('student2')
      .collection('assignments/act1/activityResponses')
      .add({ studentId: 'student2', text: 'x' }),
  );
  await assertFails(
    authed('student1')
      .collection('assignments/act1/activityResponses')
      .add({ studentId: 'student2', text: 'spoof' }),
  );
  await assertFails(
    authed('student2').collection('assignments/act1/activityResponses').get(),
  );
});

// ── 11. Notifications (C11) ────────────────────────────────────────────────

test('PH01 notifications: only the Admin role broadcast is client-created (PH-02)', async () => {
  const card = (audience) => ({
    audience,
    title: 't',
    body: 'b',
    type: 'general',
    readBy: [],
    hasAudioAlert: false,
  });
  await assertFails(authed('student1').doc('notifications/parent1_e2').set(card('parent1')));
  await assertFails(authed('parent1').doc('notifications/student2_e2').set(card('student2')));
  await assertFails(authed('teacher1').doc('notifications/parent1_e2').set(card('parent1')));
  await assertFails(authed('supervisor1').doc('notifications/parent1_e5').set(card('parent1')));
  await assertFails(authed('teacher1').doc('notifications/all_e3').set(card('all')));
  await assertFails(authed('teacher1').doc('notifications/x_e4').set(card('parent1')));
  await assertFails(authed('admin1').doc('notifications/parent1_e6').set(card('parent1')));
  await assertSucceeds(authed('admin1').collection('notifications').add(card('parent')));
});

test('PH01 notifications: audience-scoped read; reader marks only self', async () => {
  const path = 'notifications/student1_evt1';
  await assertSucceeds(authed('student1').doc(path).get());
  await assertFails(authed('student2').doc(path).get());
  await assertSucceeds(
    authed('student1')
      .collection('notifications')
      .where('audience', 'in', ['student1', 'student', 'all'])
      .get(),
  );
  await assertFails(
    authed('student2')
      .collection('notifications')
      .where('audience', 'in', ['student1'])
      .get(),
  );
  await assertFails(authed('student1').doc(path).update({ readBy: ['student2'] }));
  await assertFails(authed('student1').doc(path).update({ title: 'forged' }));
  await assertSucceeds(authed('student1').doc(path).update({ readBy: ['student1'] }));
  await assertFails(authed('student1').doc(path).delete());
});

// ── 12. Chat (C8 / C9 / D14) ───────────────────────────────────────────────

test('PH01 chat: 1:1 creation is CF-only (relationship-checked server-side)', async () => {
  await assertFails(
    authed('parent1').doc('conversations/parent1_teacher2').set({
      kind: 'direct',
      participantIds: ['parent1', 'teacher2'],
    }),
  );
  await assertFails(
    authed('parent2').doc('conversations/parent1_teacher1').update({
      participantIds: ['parent1', 'teacher1', 'parent2'],
    }),
  );
});

test('PH01 chat: authorized relationship reads; sends are callable-only; outsider denied', async () => {
  const msgs = (uid) =>
    authed(uid).collection('conversations/parent1_teacher1/messages');
  await assertSucceeds(authed('parent1').doc('conversations/parent1_teacher1').get());
  await assertSucceeds(msgs('parent1').get());
  await assertFails(
    msgs('parent1').add({ senderId: 'parent1', text: 'سلام', sentAt: new Date() }),
  );
  await assertFails(authed('parent2').doc('conversations/parent1_teacher1').get());
  await assertFails(
    msgs('parent2').add({ senderId: 'parent2', text: 'x', sentAt: new Date() }),
  );
  await assertFails(
    msgs('parent1').add({ senderId: 'teacher1', text: 'spoof', sentAt: new Date() }),
  );
  // Admin monitors (read) but cannot inject as a non-participant.
  await assertSucceeds(authed('admin1').doc('conversations/parent1_teacher1').get());
  await assertFails(
    msgs('admin1').add({ senderId: 'admin1', text: 'x', sentAt: new Date() }),
  );
});

test('PH01 chat: Parent and non-members are not Halaqa group members', async () => {
  const group = 'conversations/halaqa_group_h1';
  for (const uid of ['parent1', 'student2', 'teacher2']) {
    await assertFails(authed(uid).doc(group).get());
    await assertFails(
      authed(uid)
        .collection(`${group}/messages`)
        .add({ senderId: uid, text: 'x', sentAt: new Date() }),
    );
  }
  await assertFails(
    authed('parent1').doc(group).update({
      participantIds: ['teacher1', 'supervisor1', 'student1', 'parent1'],
    }),
  );
  await assertSucceeds(authed('student1').doc(group).get());
  await assertFails(
    authed('student1')
      .collection(`${group}/messages`)
      .add({ senderId: 'student1', text: 'x', sentAt: new Date() }),
  );
});

test('PH01 chat: messages cannot be edited or hard-deleted by clients', async () => {
  await seedAll({
    'conversations/parent1_teacher1/messages/m1': {
      senderId: 'parent1',
      text: 'original',
      sentAt: new Date(),
    },
  });
  const m = (uid) => authed(uid).doc('conversations/parent1_teacher1/messages/m1');
  await assertFails(m('teacher1').update({ text: 'tampered' }));
  await assertFails(m('parent1').update({ text: 'edited' }));
  await assertFails(m('parent1').delete());
  await assertFails(m('admin1').delete());
});

// ── 13. FCM + audit logs ───────────────────────────────────────────────────

test('PH01 FCM: own device token only', async () => {
  const token = { token: 'tok', platform: 'android', disabled: false };
  await assertSucceeds(authed('parent1').doc('fcmTokens/parent1/devices/d1').set(token));
  await assertFails(authed('parent1').doc('fcmTokens/parent2/devices/d1').set(token));
  await assertFails(authed('admin1').doc('fcmTokens/parent1/devices/d2').set(token));
  await assertFails(authed('teacher1').doc('fcmTokens/parent1/devices/d1').get());
});

test('PH01 audit logs: client writes denied for every role', async () => {
  for (const uid of ['admin1', 'supervisor1', 'teacher1', 'parent1', 'student1']) {
    await assertFails(
      authed(uid).collection('auditLogs').add({ action: 'forged', actorId: uid }),
    );
  }
});

// ── 14. Content / posts / misc collections ─────────────────────────────────

// P0 §8: the shared content library is Halaqa-scoped.
test('PH01 content: library upload is halaqa-staff-only; halaqa audience reads', async () => {
  const item = (uid, halaqaId = 'h1') => ({
    title: 'x',
    uploadedBy: uid,
    type: 'pdf',
    halaqaId,
    storagePath: `content_library/${halaqaId}/${uid}/file.pdf`,
  });
  await assertFails(authed('student1').collection('contentLibrary').add(item('student1')));
  await assertFails(authed('parent1').collection('contentLibrary').add(item('parent1')));
  await assertFails(authed('teacher1').collection('contentLibrary').add(item('teacher2')));
  await assertFails(authed('teacher2').collection('contentLibrary').add(item('teacher2', 'h1')));
  await assertFails(
    authed('teacher1').collection('contentLibrary').add({ title: 'x', uploadedBy: 'teacher1', type: 'pdf' }),
  );
  await assertSucceeds(authed('teacher1').collection('contentLibrary').add(item('teacher1')));
  await assertSucceeds(
    authed('student1').collection('contentLibrary').where('halaqaId', '==', 'h1').get(),
  );
  await assertFails(authed('student1').collection('contentLibrary').get());
});

test('PH01 posts: authored by staff for their scope; likes only toggle self', async () => {
  const post = (uid, halaqaId, target) => ({
    authorId: uid,
    halaqaId,
    audienceTarget: target,
    likedBy: [],
    commentsCount: 0,
    isPinned: false,
  });
  await assertFails(authed('student1').collection('posts').add(post('student1', 'h1', 'h1')));
  await assertFails(authed('parent1').collection('posts').add(post('parent1', null, 'all')));
  await assertFails(authed('teacher2').collection('posts').add(post('teacher2', 'h1', 'h1')));
  await assertSucceeds(authed('teacher1').collection('posts').add(post('teacher1', 'h1', 'h1')));

  await assertSucceeds(
    authed('student1').doc('posts/post1').update({ likedBy: ['student2', 'student1'] }),
  );
  await assertFails(authed('student1').doc('posts/post1').update({ likedBy: [] }));
  await assertFails(authed('student1').doc('posts/post1').update({ isPinned: true }));
  await assertFails(authed('student1').doc('posts/post1').delete());
});

test('PH01 misc: complaints, reports, catalogues and legacy paths fail closed', async () => {
  await assertFails(authed('teacher1').doc('complaints/c1').get());
  await assertFails(authed('parent1').collection('complaints').add({ text: 'x' }));
  await assertFails(
    authed('teacher1').collection('supervisorReports').add({ supervisorId: 'teacher1' }),
  );
  await assertSucceeds(
    authed('supervisor1').collection('supervisorReports').add({ supervisorId: 'supervisor1' }),
  );
  await assertFails(authed('teacher1').doc('reciters/r1').set({ name: 'x' }));
  await assertFails(authed('student1').doc('surahAudios/a1').set({ url: 'x' }));
  await assertFails(authed('student1').doc('halaqaActivity/a1').set({ x: 1 }));
  await assertFails(authed('student1').doc('unknownCollection/x').get());
});

// ── PH-01 continuation: economy, admission role, scoped reads, C15 ─────────

async function seedCompletableHomework(id, studentId = 'student1') {
  await seedAll({
    [`assignments/${id}`]: {
      studentId,
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [{ id: 't1', title: 'x', points: 20, isCompleted: true }],
      isSubmitted: false,
      status: 'pending',
    },
  });
}

function completeWithCredit(db, hwId, profileUpdate) {
  const batch = db.batch();
  batch.update(db.doc(`assignments/${hwId}`), {
    isSubmitted: true,
    status: 'completed',
  });
  batch.update(db.doc('studentProfiles/student1'), profileUpdate);
  return batch.commit();
}

test('PH01 economy: homework completion + credit are callable-only (PH-02)', async () => {
  await seedCompletableHomework('hwA');
  const db = authed('student1');
  await assertFails(
    completeWithCredit(db, 'hwA', {
      points: 20,
      coins: 20,
      lastCompletedHomeworkId: 'hwA',
    }),
  );
  await assertFails(
    db.doc('assignments/hwA').update({ isSubmitted: true, status: 'completed' }),
  );
  await seedAll({
    'assignments/hwA': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [{ id: 't1', title: 'x', points: 20, isCompleted: true }],
      isSubmitted: true,
      status: 'completed',
    },
  });
  // Completed homework is final: it cannot be reopened to farm credit.
  await assertFails(
    db.doc('assignments/hwA').update({ status: 'pending', isSubmitted: false }),
  );
  // Credit citing an already-completed homework is denied.
  await assertFails(
    db.doc('studentProfiles/student1').update({
      points: 40,
      coins: 40,
      lastCompletedHomeworkId: 'hwA',
    }),
  );
});

test('PH01 economy: credit without completion, oversized or unequal is denied', async () => {
  await seedCompletableHomework('hwB');
  await seedCompletableHomework('hwOther', 'student2');
  const db = authed('student1');
  // No assignment transition in the same batch.
  await assertFails(
    db.doc('studentProfiles/student1').update({
      points: 20,
      coins: 20,
      lastCompletedHomeworkId: 'hwB',
    }),
  );
  await assertFails(
    completeWithCredit(db, 'hwB', {
      points: 500,
      coins: 500,
      lastCompletedHomeworkId: 'hwB',
    }),
  );
  await assertFails(
    completeWithCredit(db, 'hwB', {
      points: 10,
      coins: 90,
      lastCompletedHomeworkId: 'hwB',
    }),
  );
  // Wrong owner: another student's homework cannot fund student1.
  await assertFails(
    db.doc('studentProfiles/student1').update({
      points: 20,
      coins: 20,
      lastCompletedHomeworkId: 'hwOther',
    }),
  );
});

test('PH01 economy: avatar spend is callable-only; no client mints points/coins', async () => {
  await seedAll({
    'studentProfiles/student1': {
      uid: 'student1',
      halaqaId: 'h1',
      points: 0,
      coins: 50,
      avatarId: 'a0',
      unlockedAvatarIds: ['a0'],
    },
  });
  const db = authed('student1');
  await assertFails(
    db.doc('studentProfiles/student1').update({
      avatarId: 'a1',
      unlockedAvatarIds: ['a0', 'a1'],
      coins: 30,
    }),
  );
  await assertFails(db.doc('studentProfiles/student1').update({ avatarId: 'a0' }));
  await assertFails(db.doc('studentProfiles/student1').update({ coins: 9999 }));
  await assertFails(db.doc('studentProfiles/student1').update({ coins: -5 }));
  await assertFails(db.doc('studentProfiles/student1').update({ points: 9999 }));
  await assertFails(
    db.doc('studentProfiles/student1').update({ totalStars: 50 }),
  );
});

test('PH01 halaqa: no client roster edit, whatever the added uid (PH-02)', async () => {
  const db = authed('supervisor1');
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'parent1'] }),
  );
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'teacher2'] }),
  );
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'ghost'] }),
  );
  await assertFails(db.doc('halaqat/h1').update({ studentIds: ['student3'] }));
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'student3'] }),
  );
});

test('PH01 privacy: studentProfiles are not readable student-to-student', async () => {
  await seedAll({
    'halaqat/h1': {
      name: 'H1',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1', 'student3'],
      schedule: [{ day: 0, startTime: '16:00', endTime: '17:00' }],
    },
    'studentProfiles/student3': { uid: 'student3', halaqaId: 'h1', points: 0 },
  });
  await assertSucceeds(authed('student1').doc('studentProfiles/student1').get());
  // Classmate on the same roster (group chat display).
  await assertSucceeds(authed('student3').doc('studentProfiles/student1').get());
  await assertFails(authed('student2').doc('studentProfiles/student1').get());
  await assertFails(authed('student1').doc('studentProfiles/student2').get());
  await assertSucceeds(authed('parent1').doc('studentProfiles/student1').get());
  await assertFails(authed('parent2').doc('studentProfiles/student1').get());
  await assertFails(authed('parent1').doc('studentProfiles/student2').get());
  await assertSucceeds(authed('teacher1').doc('studentProfiles/student2').get());
  await assertFails(authed('student1').collection('studentProfiles').get());
});

test('PH01 privacy: achievements are own/linked/staff scoped', async () => {
  await seedAll({
    'achievements/a1': {
      studentId: 'student1',
      recipientStudentIds: ['student1'],
      halaqaId: 'h1',
      halaqaIds: ['h1'],
      grantedBy: 'teacher1',
      title: 'x',
    },
    'achievements/a2': {
      studentId: 'student2',
      recipientStudentIds: ['student2'],
      halaqaId: 'h2',
      halaqaIds: ['h2'],
      grantedBy: 'teacher2',
      title: 'y',
    },
    // Multi-recipient grant: studentId is only the first recipient.
    'achievements/a3': {
      studentId: 'student2',
      recipientStudentIds: ['student2', 'student1'],
      halaqaId: 'h1',
      halaqaIds: ['h1'],
      grantedBy: 'admin1',
      title: 'ز',
    },
  });
  const s1 = authed('student1');
  await assertSucceeds(
    s1.collection('achievements').where('studentId', '==', 'student1').get(),
  );
  await assertSucceeds(
    s1
      .collection('achievements')
      .where('recipientStudentIds', 'array-contains', 'student1')
      .get(),
  );
  await assertFails(s1.doc('achievements/a2').get());
  await assertFails(
    s1.collection('achievements').where('studentId', '==', 'student2').get(),
  );
  await assertFails(s1.collection('achievements').get());
  await assertSucceeds(authed('parent1').doc('achievements/a1').get());
  await assertFails(authed('parent1').doc('achievements/a2').get());
  // Multi-recipient: linked parent of a non-primary recipient may get by id.
  await assertSucceeds(authed('parent1').doc('achievements/a3').get());
  await assertFails(authed('parent2').doc('achievements/a1').get());

  // Parent list queries that need get(parentProfiles)+hasAny cannot be proven
  // from query constraints alone (Firestore denies the whole list). Single-doc
  // gets above remain the ownership-preserving path until awards carry a
  // denormalized parent-visible key written by the grant callable.
  await assertFails(
    authed('parent1')
      .collection('achievements')
      .where('recipientStudentIds', 'array-contains', 'student1')
      .get(),
  );
  await assertFails(
    authed('parent1')
      .collection('achievements')
      .where('recipientStudentIds', 'array-contains', 'student2')
      .get(),
  );
  await assertFails(
    authed('parent1')
      .collection('achievements')
      .where('studentId', '==', 'student1')
      .get(),
  );
  await assertSucceeds(
    authed('teacher1')
      .collection('achievements')
      .where('halaqaIds', 'array-contains', 'h1')
      .get(),
  );
});

test('PH01 C15: Mushaf last-read is own-only and shape-checked', async () => {
  const pos = { surahNumber: 2, ayahNumber: 255, pageNumber: 42 };
  await assertSucceeds(authed('student1').doc('mushafReading/student1').set(pos));
  await assertSucceeds(authed('student1').doc('mushafReading/student1').get());
  await assertFails(authed('student2').doc('mushafReading/student1').get());
  await assertFails(authed('teacher1').doc('mushafReading/student1').get());
  await assertFails(authed('parent1').doc('mushafReading/student1').get());
  await assertFails(authed('student2').doc('mushafReading/student1').set(pos));
  await assertFails(
    authed('student1')
      .doc('mushafReading/student1')
      .set({ ...pos, pageNumber: 999 }),
  );
  await assertFails(
    authed('student1')
      .doc('mushafReading/student1')
      .set({ ...pos, overallProgressPercent: 100 }),
  );
  await assertFails(authed('student1').doc('mushafReading/student1').delete());
});

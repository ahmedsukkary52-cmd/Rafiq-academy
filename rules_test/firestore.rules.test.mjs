/**
 * WA-2 negative security Rules tests (Firestore).
 *
 * Run (requires Java for emulator + network for first firebase download):
 *   cd rules_test && npm install
 *   npx firebase emulators:exec --project demo-rafiq --only firestore \
 *     "npm test"   (from repo root with firebase-tools)
 *
 * Or with rules-unit-testing's built-in emulator bootstrap via this script alone
 * when @firebase/rules-unit-testing can start Firestore emulator.
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import test from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

let testEnv;

async function seed(db, path, data) {
  await db.doc(path).set(data);
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-rafiq-wa2',
    firestore: { rules },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await seed(db, 'users/admin1', {
      name: 'Admin',
      role: 'admin',
      email: 'a@test.com',
      isActive: true,
    });
    await seed(db, 'users/parent1', {
      name: 'Parent',
      role: 'parent',
      email: 'p@test.com',
      isActive: true,
    });
    await seed(db, 'users/teacher1', {
      name: 'Teacher',
      role: 'teacher',
      email: 't@test.com',
      isActive: true,
    });
    await seed(db, 'users/student1', {
      name: 'Student',
      role: 'student',
      email: 's@test.com',
      isActive: true,
    });
    await seed(db, 'users/supervisor1', {
      name: 'Supervisor',
      role: 'supervisor',
      email: 'sv@test.com',
      isActive: true,
    });
    await seed(db, 'users/legacyPhone', {
      name: 'Legacy',
      role: 'student',
      phone: '01000000000',
      isActive: true,
    });
    await seed(db, 'userPrivate/student1', { phone: '01111111111' });
    await seed(db, 'studentProfiles/student1', {
      uid: 'student1',
      name: 'Student',
      overallProgressPercent: 0,
    });
    await seed(db, 'parentProfiles/parent1', { uid: 'parent1', childrenIds: ['student1'] });
    await seed(db, 'halaqat/h1', {
      name: 'H1',
      teacherId: 'teacher1',
      studentIds: ['student1'],
      status: 'active',
    });
    await seed(db, 'payments/pay1', {
      parentId: 'parent1',
      studentId: 'student1',
      amount: 100,
      status: 'due',
    });
    await seed(db, 'academySettings/paymentPublic', {
      vodafoneCashDestination: '010999',
      instructionsAr: 'حوّل ثم ارفق الإيصال',
    });
    await seed(db, 'academySettings/communication', {
      conversationRetentionDays: 365,
    });
    await seed(db, 'paymentAccess/parent1', {
      parentId: 'parent1',
      status: 'ok',
    });
  });
});

function authed(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test('role escalation student → admin denied', async () => {
  const db = authed('student1');
  await assertFails(db.doc('users/student1').update({ role: 'admin' }));
});

test('role escalation teacher → admin denied', async () => {
  const db = authed('teacher1');
  await assertFails(db.doc('users/teacher1').update({ role: 'admin' }));
});

test('role escalation parent → admin denied', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('users/parent1').update({ role: 'admin' }));
});

test('Admin cannot change role via client either (CF-only)', async () => {
  const db = authed('admin1');
  await assertFails(db.doc('users/student1').update({ role: 'admin' }));
});

test('non-Admin cannot read another userPrivate phone', async () => {
  const db = authed('teacher1');
  await assertFails(db.doc('userPrivate/student1').get());
});

test('Admin can read userPrivate phone', async () => {
  const db = authed('admin1');
  await assertSucceeds(db.doc('userPrivate/student1').get());
});

test('self can read own userPrivate phone', async () => {
  const db = authed('student1');
  await assertSucceeds(db.doc('userPrivate/student1').get());
});

test('non-Admin cannot read legacy users doc with exposed phone', async () => {
  const db = authed('teacher1');
  await assertFails(db.doc('users/legacyPhone').get());
});

test('Admin can read legacy users phone doc', async () => {
  const db = authed('admin1');
  await assertSucceeds(db.doc('users/legacyPhone').get());
});

test('Parent cannot modify childrenIds', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('parentProfiles/parent1').update({
      childrenIds: ['student1', 'hacker'],
    }),
  );
});

test('Teacher cannot modify halaqa studentIds', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'x'] }),
  );
});

test('Parent cannot set payment status paid', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('payments/pay1').update({ status: 'paid' }));
});

test('Parent cannot change invoice amount', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('payments/pay1').update({ amount: 1 }));
});

test('client cannot write paymentAccess', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('paymentAccess/parent1').set({ status: 'ok', parentId: 'parent1' }),
  );
  await assertFails(
    db.doc('paymentAccess/parent1').update({ status: 'suspended' }),
  );
});

test('Parent can read paymentPublic', async () => {
  const db = authed('parent1');
  await assertSucceeds(db.doc('academySettings/paymentPublic').get());
});

test('Parent cannot write paymentPublic', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('academySettings/paymentPublic').update({ vodafoneCashDestination: 'x' }),
  );
});

test('Teacher cannot read Admin-only communication settings', async () => {
  const db = authed('teacher1');
  await assertFails(db.doc('academySettings/communication').get());
});

test('Admin can manage communication settings', async () => {
  const db = authed('admin1');
  await assertSucceeds(db.doc('academySettings/communication').get());
  await assertSucceeds(
    db.doc('academySettings/communication').update({ conversationRetentionDays: 180 }),
  );
});

test('unauthenticated users create denied', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(
    db.doc('users/new').set({ name: 'x', role: 'admin', isActive: true }),
  );
});

test('wallet client write denied', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('wallets/parent1').set({ balance: 999 }));
});

test('role escalation supervisor → admin denied', async () => {
  const db = authed('supervisor1');
  await assertFails(db.doc('users/supervisor1').update({ role: 'admin' }));
});

test('Parent cannot read another userPrivate phone', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('userPrivate/student1').get());
});

test('Supervisor cannot read another userPrivate phone', async () => {
  const db = authed('supervisor1');
  await assertFails(db.doc('userPrivate/student1').get());
});

test('Student cannot modify parent childrenIds', async () => {
  const db = authed('student1');
  await assertFails(
    db.doc('parentProfiles/parent1').update({
      childrenIds: ['student1', 'other'],
    }),
  );
});

test('Parent cannot modify halaqa studentIds', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('halaqat/h1').update({ studentIds: ['student1', 'injected'] }),
  );
});

test('Teacher cannot write phone onto studentProfiles', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('studentProfiles/student1').set(
      { phone: '01099999999' },
      { merge: true },
    ),
  );
});

test('Parent cannot set reviewNotes on payment proof', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('payments/pay1').update({
      reviewStatus: 'pending_review',
      reviewNotes: 'forged',
    }),
  );
});

test('Parent may resubmit proof fields to pending_review without privileged keys', async () => {
  const db = authed('parent1');
  await assertSucceeds(
    db.doc('payments/pay1').update({
      proofStoragePath: 'payment_proofs/parent1/pay1/a.jpg',
      proofDownloadUrl: 'https://example.com/a.jpg',
      proofFileName: 'a.jpg',
      proofSubmittedBy: 'parent1',
      method: 'vodafone_cash',
      reviewStatus: 'pending_review',
    }),
  );
});

test('Teacher cannot write academySettings/paymentPublic', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('academySettings/paymentPublic').update({
      vodafoneCashDestination: 'x',
    }),
  );
});

test('unauthenticated cannot read users', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(db.doc('users/student1').get());
});

// ── WA-3 → WA-5 ────────────────────────────────────────────────────────────

test('WA-3 Teacher cannot write paymentAccess', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('paymentAccess/parent1').update({ status: 'ok' }),
  );
});

test('WA-3 Student cannot write paymentAccess', async () => {
  const db = authed('student1');
  await assertFails(
    db.doc('paymentAccess/parent1').set({ status: 'ok', parentId: 'parent1' }),
  );
});

test('WA-3 Supervisor cannot write paymentAccess', async () => {
  const db = authed('supervisor1');
  await assertFails(
    db.doc('paymentAccess/parent1').update({ status: 'ok' }),
  );
});

test('WA-3 Parent can read own paymentAccess', async () => {
  const db = authed('parent1');
  await assertSucceeds(db.doc('paymentAccess/parent1').get());
});

test('WA-3 Teacher cannot read paymentAccess', async () => {
  const db = authed('teacher1');
  await assertFails(db.doc('paymentAccess/parent1').get());
});

test('WA-4 Supervisor cannot write paymentPublic', async () => {
  const db = authed('supervisor1');
  await assertFails(
    db.doc('academySettings/paymentPublic').update({
      vodafoneCashDestination: 'x',
    }),
  );
});

test('WA-4 Supervisor cannot read paymentPublic (Parent-only per WAVE_A)', async () => {
  const db = authed('supervisor1');
  await assertFails(db.doc('academySettings/paymentPublic').get());
});

test('WA-4 Student cannot write paymentPublic', async () => {
  const db = authed('student1');
  await assertFails(
    db.doc('academySettings/paymentPublic').update({
      vodafoneCashDestination: 'x',
    }),
  );
});

test('WA-4 non-Admin cannot write pricingDefaults', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('academySettings/pricingDefaults').set({
      gracePeriodDays: 99,
    }),
  );
});

test('WA-4 Parent cannot read pricingDefaults', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('academySettings/pricingDefaults').get());
});

test('WA-4 Admin can manage paymentPublic and pricingDefaults', async () => {
  const db = authed('admin1');
  await assertSucceeds(
    db.doc('academySettings/paymentPublic').set({
      vodafoneCashDestination: '01012345678',
      updatedBy: 'admin1',
    }),
  );
  await assertSucceeds(
    db.doc('academySettings/pricingDefaults').set({
      gracePeriodDays: 7,
      defaultCurrency: 'EGP',
    }),
  );
});

test('WA-5 Parent cannot create arbitrary invoice', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('payments/forged').set({
      parentId: 'parent1',
      studentId: 'student1',
      amount: 1,
      status: 'due',
    }),
  );
});

test('WA-5 Parent cannot set pricingRuleId/version', async () => {
  const db = authed('parent1');
  await assertFails(
    db.doc('payments/pay1').update({
      pricingRuleId: 'hack',
      pricingRuleVersion: 99,
    }),
  );
});

test('WA-5 Parent cannot set paid / privileged status', async () => {
  const db = authed('parent1');
  await assertFails(db.doc('payments/pay1').update({ status: 'paid' }));
  await assertFails(db.doc('payments/pay1').update({ amount: 1 }));
});

test('WA-5 Parent cannot read pricingRules', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('pricingRules/r1').set({
      scope: 'academy_default',
      amount: 200,
      active: true,
      version: 1,
    });
  });
  const db = authed('parent1');
  await assertFails(db.doc('pricingRules/r1').get());
});

test('WA-5 Teacher cannot write pricingRules', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('pricingRules/r1').set({
      scope: 'academy_default',
      amount: 1,
      active: true,
      version: 1,
    }),
  );
});

test('WA-5 Admin can write pricingRules', async () => {
  const db = authed('admin1');
  await assertSucceeds(
    db.doc('pricingRules/r1').set({
      scope: 'academy_default',
      amount: 250,
      currency: 'EGP',
      active: true,
      version: 1,
    }),
  );
});

test('WA-8 client cannot create sessions', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('sessions/sess_x').set({
      halaqaId: 'h1',
      slotId: 'slot-1',
      date: '2026-09-13',
      status: 'scheduled',
      teacherId: 'teacher1',
      createdBy: 'teacher1',
    }),
  );
});

test('WA-8 Teacher of session can update status only', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('sessions/sess_1').set({
      halaqaId: 'h1',
      slotId: 'slot-1',
      date: '2026-09-13',
      startAt: new Date('2026-09-13T13:00:00Z'),
      endAt: new Date('2026-09-13T14:00:00Z'),
      status: 'scheduled',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      createdAt: new Date('2026-09-01T00:00:00Z'),
      createdBy: 'teacher1',
      updatedAt: new Date('2026-09-01T00:00:00Z'),
    });
  });
  const db = authed('teacher1');
  await assertSucceeds(
    db.doc('sessions/sess_1').update({
      status: 'in_progress',
      updatedAt: new Date(),
    }),
  );

  const forbidden = [
    { teacherId: 'other' },
    { supervisorId: 'other-sv' },
    { halaqaId: 'h2' },
    { slotId: 'slot-x' },
    { date: '2026-09-20' },
    { startAt: new Date('2026-09-13T15:00:00Z') },
    { endAt: new Date('2026-09-13T16:00:00Z') },
    { createdAt: new Date('2026-01-01T00:00:00Z') },
    { createdBy: 'forged' },
  ];
  for (const patch of forbidden) {
    await assertFails(
      db.doc('sessions/sess_1').update({
        ...patch,
        status: 'completed',
        updatedAt: new Date(),
      }),
    );
  }
});

test('WA-8 Admin cannot mutate session identity via status update', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('sessions/sess_admin').set({
      halaqaId: 'h1',
      slotId: 'slot-1',
      date: '2026-09-13',
      startAt: new Date('2026-09-13T13:00:00Z'),
      endAt: new Date('2026-09-13T14:00:00Z'),
      status: 'scheduled',
      teacherId: 'teacher1',
      createdAt: new Date('2026-09-01T00:00:00Z'),
      createdBy: 'teacher1',
      updatedAt: new Date('2026-09-01T00:00:00Z'),
    });
  });
  const db = authed('admin1');
  await assertSucceeds(
    db.doc('sessions/sess_admin').update({
      status: 'cancelled',
      updatedAt: new Date(),
    }),
  );
  await assertFails(
    db.doc('sessions/sess_admin').update({
      teacherId: 'admin1',
      status: 'cancelled',
      updatedAt: new Date(),
    }),
  );
});

test('WA-8 other Teacher cannot update session status', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/teacher2').set({
      name: 'T2',
      role: 'teacher',
      email: 't2@test.com',
      isActive: true,
    });
    await ctx.firestore().doc('sessions/sess_2').set({
      halaqaId: 'h1',
      slotId: 'slot-1',
      date: '2026-09-13',
      startAt: new Date('2026-09-13T13:00:00Z'),
      endAt: new Date('2026-09-13T14:00:00Z'),
      status: 'scheduled',
      teacherId: 'teacher1',
      createdAt: new Date('2026-09-01T00:00:00Z'),
      createdBy: 'teacher1',
      updatedAt: new Date('2026-09-01T00:00:00Z'),
    });
  });
  const db = authed('teacher2');
  await assertFails(
    db.doc('sessions/sess_2').update({
      status: 'cancelled',
      updatedAt: new Date(),
    }),
  );
});

test('WA-9 client cannot write sessionConflictLocks', async () => {
  const db = authed('admin1');
  await assertFails(
    db.doc('sessionConflictLocks/cairo_2026-09-13').set({
      date: '2026-09-13',
    }),
  );
  const teacherDb = authed('teacher1');
  await assertFails(
    teacherDb.doc('sessionConflictLocks/cairo_2026-09-13').set({
      date: '2026-09-13',
    }),
  );
});

test('WA-10 client cannot create halaqa_group conversation', async () => {
  const db = authed('teacher1');
  await assertFails(
    db.doc('conversations/halaqa_group_h1').set({
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1', 'student1'],
    }),
  );
  await assertFails(
    db.doc('conversations/random_id').set({
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1'],
    }),
  );
});

test('WA-10 client cannot mutate group participantIds', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/halaqa_group_h1').set({
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1', 'student1'],
      createdAt: new Date('2026-01-01T00:00:00Z'),
      createdBy: 'system',
    });
  });
  const db = authed('teacher1');
  await assertFails(
    db.doc('conversations/halaqa_group_h1').update({
      participantIds: ['teacher1', 'student1', 'parent1'],
    }),
  );
  await assertFails(
    db.doc('conversations/halaqa_group_h1').update({
      participantIds: ['teacher1'],
    }),
  );
  // Non-membership fields (e.g. lastMessage) remain updatable for messaging.
  await assertSucceeds(
    db.doc('conversations/halaqa_group_h1').update({
      lastMessage: 'مرحبا',
      lastMessageAt: new Date(),
    }),
  );
});

test('WA-10 client cannot delete halaqa_group conversation', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/halaqa_group_h1').set({
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1'],
    });
  });
  const db = authed('admin1');
  await assertFails(db.doc('conversations/halaqa_group_h1').delete());
});

// ── WA-11 chat authorization + soft-delete ───────────────────────────────────

test('WA-11 client cannot create arbitrary 1:1 conversation', async () => {
  const db = authed('student1');
  await assertFails(
    db.doc('conversations/student1_teacher2').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher2'],
      createdAt: new Date(),
    }),
  );
});

test('WA-11 unauthorized user cannot read conversation', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/student1_teacher1').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher1'],
    });
  });
  const stranger = authed('parent1');
  await assertFails(stranger.doc('conversations/student1_teacher1').get());
});

test('WA-11 participant can read conversation; Admin can monitor', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/student1_teacher1').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher1'],
    });
  });
  await assertSucceeds(
    authed('student1').doc('conversations/student1_teacher1').get(),
  );
  await assertSucceeds(
    authed('teacher1').doc('conversations/student1_teacher1').get(),
  );
  await assertSucceeds(
    authed('admin1').doc('conversations/student1_teacher1').get(),
  );
});

test('WA-11 participantIds cannot be client-mutated on direct chat', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/student1_teacher1').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher1'],
      createdAt: new Date('2026-01-01T00:00:00Z'),
      createdBy: 'student1',
    });
  });
  const db = authed('student1');
  await assertFails(
    db.doc('conversations/student1_teacher1').update({
      participantIds: ['student1', 'teacher1', 'parent1'],
    }),
  );
});

test('WA-11 group participant can write message; non-member cannot', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/halaqa_group_h1').set({
      kind: 'halaqa_group',
      halaqaId: 'h1',
      participantIds: ['teacher1', 'student1'],
    });
  });
  await assertSucceeds(
    authed('teacher1')
      .doc('conversations/halaqa_group_h1/messages/m1')
      .set({
        senderId: 'teacher1',
        text: 'hello',
        sentAt: new Date(),
        deleted: false,
      }),
  );
  await assertFails(
    authed('parent1')
      .doc('conversations/halaqa_group_h1/messages/m2')
      .set({
        senderId: 'parent1',
        text: 'sneak',
        sentAt: new Date(),
        deleted: false,
      }),
  );
});

test('WA-11 unauthorized cannot create message in foreign conversation', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/student1_teacher1').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher1'],
    });
  });
  await assertFails(
    authed('parent1')
      .doc('conversations/student1_teacher1/messages/x1')
      .set({
        senderId: 'parent1',
        text: 'nope',
        sentAt: new Date(),
      }),
  );
});

test('WA-11 client cannot update/delete message docs (soft-delete via CF)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('conversations/student1_teacher1').set({
      kind: 'direct',
      participantIds: ['student1', 'teacher1'],
    });
    await ctx
      .firestore()
      .doc('conversations/student1_teacher1/messages/m1')
      .set({
        senderId: 'student1',
        text: 'hi',
        sentAt: new Date(),
        deleted: false,
      });
  });
  const db = authed('student1');
  await assertFails(
    db.doc('conversations/student1_teacher1/messages/m1').update({
      deleted: true,
      deletedBy: 'student1',
      deletedAt: new Date(),
      text: '',
    }),
  );
  await assertFails(
    db.doc('conversations/student1_teacher1/messages/m1').delete(),
  );
  // Participant can still read the message document.
  await assertSucceeds(
    db.doc('conversations/student1_teacher1/messages/m1').get(),
  );
});

// ── WA-13 / C11 — FCM tokens + server-owned notification send state ────────

function deviceDoc(overrides = {}) {
  return {
    token: 'tok-1',
    platform: 'android',
    disabled: false,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  };
}

async function seedParentDevice() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx
      .firestore()
      .doc('fcmTokens/parent1/devices/dev_a')
      .set(deviceDoc());
  });
}

test('WA-13 user can create, update, read and delete own device token', async () => {
  const ref = authed('parent1').doc('fcmTokens/parent1/devices/dev_a');

  await assertSucceeds(ref.set(deviceDoc()));
  await assertSucceeds(ref.update({ token: 'tok-2', updatedAt: new Date() }));
  await assertSucceeds(ref.get());
  await assertSucceeds(ref.delete());
});

test('WA-13 user cannot read another user device token', async () => {
  await seedParentDevice();

  await assertFails(
    authed('student1').doc('fcmTokens/parent1/devices/dev_a').get(),
  );
  await assertFails(
    authed('student1').collection('fcmTokens/parent1/devices').get(),
  );
  // Admin has no client-side token read path either — Admin SDK only.
  await assertFails(
    authed('admin1').doc('fcmTokens/parent1/devices/dev_a').get(),
  );
});

test('WA-13 user cannot create, update or delete another user token', async () => {
  await assertFails(
    authed('student1').doc('fcmTokens/parent1/devices/dev_b').set(deviceDoc()),
  );

  await seedParentDevice();

  await assertFails(
    authed('student1')
      .doc('fcmTokens/parent1/devices/dev_a')
      .update({ token: 'stolen', updatedAt: new Date() }),
  );
  await assertFails(
    authed('student1').doc('fcmTokens/parent1/devices/dev_a').delete(),
  );
});

test('WA-13 unauthenticated device token access denied', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(db.doc('fcmTokens/parent1/devices/dev_a').get());
  await assertFails(db.doc('fcmTokens/parent1/devices/dev_a').set(deviceDoc()));
});

test('WA-13 client cannot write server-owned token fields', async () => {
  const ref = authed('parent1').doc('fcmTokens/parent1/devices/dev_a');

  await assertFails(
    ref.set(deviceDoc({ disabledReason: 'unregistered_token' })),
  );
  await assertFails(ref.set(deviceDoc({ lastSendAt: new Date() })));

  await assertSucceeds(ref.set(deviceDoc()));
  await assertFails(ref.update({ disabledReason: 'spoofed' }));
  await assertFails(ref.update({ lastErrorCode: 'messaging/internal' }));
});

test('WA-13 malformed device token documents denied', async () => {
  const ref = authed('parent1').doc('fcmTokens/parent1/devices/dev_a');

  await assertFails(ref.set({ platform: 'android', disabled: false }));
  await assertFails(ref.set(deviceDoc({ token: '' })));
  await assertFails(ref.set(deviceDoc({ platform: 'desktop' })));
  await assertFails(ref.set(deviceDoc({ disabled: 'false' })));
});

test('WA-13 fcmTokens parent document is not client writable', async () => {
  await assertFails(authed('parent1').doc('fcmTokens/parent1').set({ x: 1 }));
  await assertSucceeds(authed('parent1').doc('fcmTokens/parent1').get());
});

test('WA-13 notificationDeliveries are CF-only send state', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('notificationDeliveries/parent1_evt1').set({
      notificationId: 'parent1_evt1',
      recipientId: 'parent1',
      status: 'sent',
    });
  });

  await assertFails(
    authed('parent1').doc('notificationDeliveries/parent1_evt1').get(),
  );
  await assertFails(
    authed('parent1')
      .doc('notificationDeliveries/parent1_evt1')
      .update({ status: 'failed' }),
  );
  await assertFails(
    authed('parent1')
      .doc('notificationDeliveries/parent1_evt2')
      .set({ status: 'sent' }),
  );
  await assertSucceeds(
    authed('admin1').doc('notificationDeliveries/parent1_evt1').get(),
  );
});

test('WA-13 client cannot forge server-owned push fields on notifications', async () => {
  const db = authed('student1');

  await assertFails(
    db.doc('notifications/spoof1').set({
      audience: 'parent1',
      title: 'x',
      body: 'y',
      type: 'assignment',
      readBy: [],
      hasAudioAlert: false,
      data: { kind: 'evaluation', evaluationId: 'rec1' },
    }),
  );

  // Existing W4/W5 in-app fan-out shape stays allowed.
  await assertSucceeds(
    db.doc('notifications/parent1_homework_reviewed_rec1').set({
      audience: 'parent1',
      title: 'تم تقييم التسميع',
      body: 'تم تقييم تسميع الطالب',
      type: 'assignment',
      readBy: [],
      hasAudioAlert: false,
    }),
  );

  await assertFails(
    db
      .doc('notifications/parent1_homework_reviewed_rec1')
      .update({ delivery: { status: 'sent' } }),
  );
});

// ── WA-14 / C13 — studentSearch role-scoped directory projection ───────────

function searchDoc(overrides = {}) {
  return {
    studentId: 'student1',
    fullName: 'أحمد',
    fullNameNormalized: 'احمد',
    halaqaId: 'h1',
    halaqaName: 'H1',
    halaqaIds: ['h1'],
    visibleTo: ['teacher1', 'supervisor1'],
    normalizationVersion: 1,
    updatedAt: new Date(),
    ...overrides,
  };
}

/** student1 is in teacher1/supervisor1 scope; student2 is in nobody's. */
async function seedStudentSearch() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('studentSearch/student1').set(searchDoc());
    await db.doc('studentSearch/student2').set(
      searchDoc({
        studentId: 'student2',
        fullName: 'بلال',
        fullNameNormalized: 'بلال',
        halaqaId: 'h2',
        halaqaName: 'H2',
        halaqaIds: ['h2'],
        visibleTo: ['teacherOther', 'supervisorOther'],
      }),
    );
  });
}

function scopedQuery(db, uid) {
  return db
    .collection('studentSearch')
    .where('visibleTo', 'array-contains', uid)
    .orderBy('fullNameNormalized')
    .limit(25);
}

test('WA-14 admin reads any studentSearch document and the whole directory', async () => {
  await seedStudentSearch();
  const db = authed('admin1');

  await assertSucceeds(db.doc('studentSearch/student1').get());
  await assertSucceeds(db.doc('studentSearch/student2').get());
  await assertSucceeds(
    db.collection('studentSearch').orderBy('fullNameNormalized').limit(25).get(),
  );
});

test('WA-14 authorized teacher reads only students inside visibleTo', async () => {
  await seedStudentSearch();
  const db = authed('teacher1');

  await assertSucceeds(db.doc('studentSearch/student1').get());

  const scoped = await assertSucceeds(scopedQuery(db, 'teacher1').get());
  assert.deepEqual(
    scoped.docs.map((d) => d.id),
    ['student1'],
  );
});

test('WA-14 authorized supervisor reads only students inside visibleTo', async () => {
  await seedStudentSearch();
  const db = authed('supervisor1');

  await assertSucceeds(db.doc('studentSearch/student1').get());
  await assertSucceeds(scopedQuery(db, 'supervisor1').get());
});

test('WA-14 teacher outside visibleTo is denied', async () => {
  await seedStudentSearch();
  const db = authed('teacher1');

  await assertFails(db.doc('studentSearch/student2').get());
  await assertFails(
    db.collection('studentSearch').where('halaqaIds', 'array-contains', 'h2').get(),
  );
});

test('WA-14 supervisor outside visibleTo is denied', async () => {
  await seedStudentSearch();
  await assertFails(authed('supervisor1').doc('studentSearch/student2').get());
});

test('WA-14 an unscoped or spoofed-scope staff query is denied', async () => {
  await seedStudentSearch();
  const db = authed('teacher1');

  // No scope filter — student2 is not readable, so the query fails.
  await assertFails(db.collection('studentSearch').get());
  await assertFails(
    db.collection('studentSearch').orderBy('fullNameNormalized').limit(25).get(),
  );
  // Scoping to somebody else's uid does not grant their scope.
  await assertFails(scopedQuery(db, 'teacherOther').get());
  await assertFails(scopedQuery(db, 'admin1').get());
});

test('WA-14 parent has no studentSearch access, even for their own child', async () => {
  await seedStudentSearch();
  const db = authed('parent1');

  await assertFails(db.doc('studentSearch/student1').get());
  await assertFails(db.collection('studentSearch').get());

  // A parent uid is never written into visibleTo, so the only query shape a
  // parent can run resolves to zero rows — no directory row is reachable.
  const scoped = await scopedQuery(db, 'parent1').get();
  assert.equal(scoped.size, 0);
});

test('WA-14 student has no studentSearch access, not even their own row', async () => {
  await seedStudentSearch();
  const db = authed('student1');

  await assertFails(db.doc('studentSearch/student1').get());
  await assertFails(db.collection('studentSearch').get());
});

test('WA-14 unauthenticated studentSearch access is denied', async () => {
  await seedStudentSearch();
  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(db.doc('studentSearch/student1').get());
  await assertFails(db.collection('studentSearch').get());
  await assertFails(db.doc('studentSearch/student1').set(searchDoc()));
});

test('WA-14 every client write to studentSearch is denied', async () => {
  await seedStudentSearch();

  for (const uid of ['admin1', 'teacher1', 'supervisor1', 'parent1', 'student1']) {
    const db = authed(uid);
    await assertFails(db.doc('studentSearch/forged').set(searchDoc()));
    await assertFails(
      db.doc('studentSearch/student1').update({ fullName: 'مزور' }),
    );
    await assertFails(db.doc('studentSearch/student1').delete());
  }
});

test('WA-14 a client cannot add itself to visibleTo to widen its scope', async () => {
  await seedStudentSearch();

  await assertFails(
    authed('teacher1')
      .doc('studentSearch/student2')
      .update({ visibleTo: ['teacher1'] }),
  );
  await assertFails(
    authed('student1')
      .doc('studentSearch/student1')
      .set(searchDoc({ visibleTo: ['student1'] })),
  );
});

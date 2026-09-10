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

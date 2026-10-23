/**
 * Private email — userPrivate/{uid} (Firestore).
 *
 * Only an active owner or an active Admin may `get` a private email; nobody
 * lists the collection or writes it from a client. A document that still
 * carries a legacy contact field (phone, whatsapp, …) is unreadable by every
 * client. users/{uid} can no longer gain, change or lose `email` from a
 * client, while public profile reads keep working.
 *
 * Synthetic data only; assertions compare emails as booleans so no address
 * is ever printed.
 *
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "npm --prefix rules_test run test:private-email"
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

const OWNER_EMAIL = 'owner1@example.test';

let testEnv;

const authed = (uid) => testEnv.authenticatedContext(uid).firestore();
const anon = () => testEnv.unauthenticatedContext().firestore();

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
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const docs = {
      'users/admin1': user('admin'),
      'users/adminOff': user('admin', { isActive: false }),
      'users/teacher1': user('teacher'),
      'users/parent1': user('parent'),
      'users/owner1': user('student', { email: 'legacy-owner1@example.test' }),
      'users/ownerOff': user('student', { isActive: false }),
      'users/student2': user('student'),
      'userPrivate/owner1': { email: OWNER_EMAIL, emailSource: 'auth' },
      'userPrivate/ownerOff': { email: 'off@example.test', emailSource: 'auth' },
      'userPrivate/teacher1': { email: 't1@example.test', emailSource: 'auth' },
      'userPrivate/legacyPhone': { email: 'lp@example.test', phone: '01011111111' },
      'userPrivate/legacyWhatsapp': { email: 'lw@example.test', whatsapp: '01022222222' },
    };
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
});

test('owner reads their own private email', async () => {
  const snap = await assertSucceeds(authed('owner1').doc('userPrivate/owner1').get());
  assert.equal(snap.data().email === OWNER_EMAIL, true);
});

test('admin may get a private email but never list the collection', async () => {
  const snap = await assertSucceeds(authed('admin1').doc('userPrivate/owner1').get());
  assert.equal(snap.data().email === OWNER_EMAIL, true);
  // Missing doc (not yet migrated): readable as "absent", so the admin
  // reader can fall back to the legacy users.email.
  const missing = await assertSucceeds(authed('admin1').doc('userPrivate/student2').get());
  assert.equal(missing.exists, false);

  await assertFails(authed('admin1').collection('userPrivate').get());
  await assertFails(authed('owner1').collection('userPrivate').get());
});

test('other active users cannot read anyone else\'s private email', async () => {
  for (const uid of ['teacher1', 'parent1', 'student2']) {
    await assertFails(authed(uid).doc('userPrivate/owner1').get());
    await assertFails(authed(uid).doc('userPrivate/admin1').get());
  }
  await assertFails(authed('owner1').doc('userPrivate/teacher1').get());
  await assertFails(anon().doc('userPrivate/owner1').get());
});

test('deactivated owner and deactivated admin cannot read private email', async () => {
  await assertFails(authed('ownerOff').doc('userPrivate/ownerOff').get());
  await assertFails(authed('adminOff').doc('userPrivate/owner1').get());
  await assertFails(authed('ownerOff').doc('userPrivate/owner1').get());
});

test('a doc still carrying a legacy contact field is unreadable by every client', async () => {
  for (const path of ['userPrivate/legacyPhone', 'userPrivate/legacyWhatsapp']) {
    await assertFails(authed('admin1').doc(path).get());
  }
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/legacyPhone').set({ name: 'x', role: 'student', isActive: true });
  });
  await assertFails(authed('legacyPhone').doc('userPrivate/legacyPhone').get());
});

test('no client can create, update or delete private email', async () => {
  for (const uid of ['owner1', 'admin1']) {
    const db = authed(uid);
    await assertFails(db.doc('userPrivate/owner1').update({ email: 'new@example.test' }));
    await assertFails(db.doc('userPrivate/owner1').set({ email: 'new@example.test' }));
    await assertFails(db.doc('userPrivate/owner1').delete());
    await assertFails(db.doc('userPrivate/student2').set({ email: 'new@example.test' }));
  }
});

test('users/{uid}: no client may add, change or remove email', async () => {
  // Owner with a legacy email cannot change or drop it; another owner cannot add one.
  await assertFails(authed('owner1').doc('users/owner1').update({ email: 'x@example.test' }));
  await assertFails(
    authed('owner1').doc('users/owner1').update({ email: null }),
  );
  await assertFails(authed('student2').doc('users/student2').update({ email: 'x@example.test' }));
  // Admin client cannot write email onto users either.
  await assertFails(authed('admin1').doc('users/student2').update({ email: 'x@example.test' }));
  await assertFails(authed('admin1').doc('users/owner1').update({ email: 'x@example.test' }));
});

test('users/{uid}: unrelated profile writes and public reads still work', async () => {
  // Owner edits their name; Admin toggles status on a doc that still has a legacy email.
  await assertSucceeds(authed('owner1').doc('users/owner1').update({ name: 'renamed' }));
  await assertSucceeds(authed('admin1').doc('users/owner1').update({ isActive: false }));
  // Public profile reads used by chat, rosters and parent pages.
  await assertSucceeds(authed('parent1').doc('users/teacher1').get());
  await assertSucceeds(authed('teacher1').doc('users/student2').get());
  await assertSucceeds(authed('student2').doc('users/teacher1').get());
  await assertSucceeds(authed('parent1').collection('users').where('role', '==', 'admin').get());
});

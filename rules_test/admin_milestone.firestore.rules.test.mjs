/**
 * Admin milestone — complaints threads, absence-request review by halaqa
 * staff (list queries included) and the CF-only halaqa name index.
 *
 * Run (isolated emulator):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test rules_test/admin_milestone.firestore.rules.test.mjs"
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PROJECT_ID } from './project_id.mjs';
import test from 'node:test';
import {
  collection,
  count,
  deleteField as FieldDelete,
  documentId,
  getAggregateFromServer,
  getCountFromServer,
  query,
  sum,
  where,
} from 'firebase/firestore';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, '..', 'firestore.rules'), 'utf8');

let testEnv;
const authed = (uid) => testEnv.authenticatedContext(uid).firestore();

async function seedAll(entries) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [path, data] of Object.entries(entries)) await db.doc(path).set(data);
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({ projectId: PROJECT_ID, firestore: { rules } });
});
test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  const user = (role, extra = {}) => ({ name: role, role, isActive: true, ...extra });
  await seedAll({
    'users/admin1': user('admin'),
    'users/teacher1': user('teacher'),
    'users/teacher2': user('teacher'),
    'users/supervisor1': user('supervisor'),
    'users/supervisor2': user('supervisor'),
    'users/parent1': user('parent'),
    'users/parent2': user('parent'),
    'users/parentOff': user('parent', { isActive: false }),
    'users/student1': user('student'),
    'parentProfiles/parent1': { childrenIds: ['student1'] },
    'halaqat/h1': {
      name: 'H1',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
      status: 'active',
    },
    'complaints/c1': { senderId: 'parent1', senderRole: 'parent', subject: 's', message: 'm', status: 'open' },
    'complaints/c1/history/e1': { authorId: 'admin1', authorRole: 'admin', message: 'r' },
    'complaints/c2': { senderId: 'teacher1', senderRole: 'teacher', subject: 's', message: 'm', status: 'open' },
    'complaints/cOff': { senderId: 'parentOff', senderRole: 'parent', subject: 's', message: 'm', status: 'open' },
    'absenceRequests/h1_student1_20261103': {
      studentId: 'student1',
      halaqaId: 'h1',
      requestedBy: 'parent1',
      date: new Date('2026-11-03T08:00:00Z'),
      reason: 'r',
      status: 'pending',
    },
    'halaqaNameIndex/حلقه h1': { halaqaId: 'h1' },
  });
});

test('complainant reads own complaint and its history; others cannot', async () => {
  await assertSucceeds(authed('parent1').doc('complaints/c1').get());
  await assertSucceeds(authed('parent1').doc('complaints/c1/history/e1').get());
  await assertSucceeds(authed('parent1').collection('complaints/c1/history').orderBy('createdAt').get());
  await assertSucceeds(
    authed('parent1').collection('complaints').where('senderId', '==', 'parent1').get(),
  );
  await assertFails(authed('parent2').doc('complaints/c1').get());
  await assertFails(authed('parent2').doc('complaints/c1/history/e1').get());
  await assertFails(authed('teacher1').doc('complaints/c1').get());
  await assertFails(authed('parent1').collection('complaints').get());
  await assertFails(authed('parentOff').doc('complaints/cOff').get());
  await assertSucceeds(authed('teacher1').doc('complaints/c2').get());
});

test('admin reads all complaints and histories', async () => {
  await assertSucceeds(authed('admin1').collection('complaints').orderBy('createdAt', 'desc').limit(20).get());
  await assertSucceeds(authed('admin1').doc('complaints/c1/history/e1').get());
});

test('complaints and history are never written by clients (callables only)', async () => {
  await assertFails(authed('parent1').collection('complaints').add({ senderId: 'parent1', subject: 's' }));
  await assertFails(authed('parent1').doc('complaints/c1').update({ status: 'resolved' }));
  await assertFails(authed('admin1').doc('complaints/c1').update({ status: 'resolved' }));
  await assertFails(authed('admin1').doc('complaints/c1').delete());
  await assertFails(authed('parent1').collection('complaints/c1/history').add({ message: 'x' }));
  await assertFails(authed('admin1').collection('complaints/c1/history').add({ message: 'x' }));
});

test('only the halaqa teacher decides an absence request (supervisor stays read-only, W7)', async () => {
  const path = 'absenceRequests/h1_student1_20261103';
  await assertFails(
    authed('supervisor1').doc(path).update({ status: 'approved', reviewedBy: 'supervisor1', reviewedAt: new Date() }),
  );
  await assertFails(
    authed('teacher2').doc(path).update({ status: 'approved', reviewedBy: 'teacher2', reviewedAt: new Date() }),
  );
  await assertFails(
    authed('teacher1').doc(path).update({ status: 'approved', reviewedBy: 'teacher2', reviewedAt: new Date() }),
  );
  await assertSucceeds(
    authed('teacher1').doc(path).update({ status: 'approved', reviewedBy: 'teacher1', reviewedAt: new Date() }),
  );
  await assertFails(
    authed('teacher1').doc(path).update({ status: 'rejected', reviewedBy: 'teacher1', reviewedAt: new Date() }),
  );
});

test('absence request list queries used by staff and parent screens are allowed', async () => {
  const from = new Date('2026-11-01T00:00:00Z');
  await assertSucceeds(
    authed('teacher1').collection('absenceRequests').where('halaqaId', '==', 'h1')
      .where('status', '==', 'pending').where('date', '>=', from).orderBy('date').limit(100).get(),
  );
  await assertSucceeds(
    authed('supervisor1').collection('absenceRequests').where('halaqaId', '==', 'h1')
      .where('date', '>=', from).orderBy('date').limit(100).get(),
  );
  await assertFails(
    authed('supervisor2').collection('absenceRequests').where('halaqaId', '==', 'h1')
      .where('date', '>=', from).orderBy('date').limit(100).get(),
  );
  await assertSucceeds(
    authed('parent1').collection('absenceRequests').where('requestedBy', '==', 'parent1').get(),
  );
  await assertFails(
    authed('teacher2').collection('absenceRequests').where('halaqaId', '==', 'h1').get(),
  );
});

test('admin finance ledger: aggregates, keyset pages, names and review history', async () => {
  await seedAll({
    'payments/pay1': { parentId: 'parent1', studentId: 'student1', amount: 300, status: 'paid', dueDate: new Date('2026-10-01') },
    'payments/pay2': { parentId: 'parent1', studentId: 'student1', amount: 200, status: 'due', reviewStatus: 'pending_review', dueDate: new Date('2026-11-01') },
    'auditLogs/payment_review_pay1_initial': { actorId: 'supervisor1', targetType: 'payment', targetId: 'pay1', metadata: { decision: 'approve' } },
  });
  const a = authed('admin1');
  // Compat contexts wrap a modular instance; aggregates are modular-only.
  const m = (db) => db._delegate ?? db;
  const paid = await assertSucceeds(
    getAggregateFromServer(query(collection(m(a), 'payments'), where('status', '==', 'paid')), {
      count: count(),
      amount: sum('amount'),
    }),
  );
  if (paid.data().count !== 1 || paid.data().amount !== 300) throw new Error('paid aggregate mismatch');
  await assertSucceeds(
    getCountFromServer(query(collection(m(a), 'payments'), where('reviewStatus', '==', 'pending_review'))),
  );
  await assertSucceeds(
    a.collection('payments').where('status', '==', 'due').orderBy('dueDate', 'desc').limit(20).get(),
  );
  await assertSucceeds(
    a.collection('payments').where('reviewStatus', '==', 'pending_review').orderBy('dueDate', 'desc').limit(20).get(),
  );
  await assertSucceeds(
    getAggregateFromServer(
      query(collection(m(a), 'users'), where(documentId(), 'in', ['parent1', 'student1'])),
      { n: count() },
    ),
  );
  await assertSucceeds(a.collection('auditLogs').where('targetId', '==', 'pay1').limit(20).get());

  // Nobody else can total or list the academy's payments.
  for (const uid of ['supervisor1', 'teacher1', 'parent1']) {
    await assertFails(
      getAggregateFromServer(query(collection(m(authed(uid)), 'payments'), where('status', '==', 'paid')), {
        amount: sum('amount'),
      }),
    );
    await assertFails(authed(uid).collection('payments').orderBy('dueDate', 'desc').limit(20).get());
  }
  await assertFails(authed('supervisor1').collection('auditLogs').where('targetId', '==', 'pay1').get());
});

test('onboarding: username index and progress are server-owned; first-login flag cannot be self-cleared', async () => {
  await seedAll({
    'loginUsernames/st000001': { uid: 'student1', role: 'student', status: 'active' },
    'onboardingRequests/admin1_req': { actorId: 'admin1', status: 'completed' },
    'userPrivate/student1': { loginUsername: 'st000001', mustChangePassword: true },
    'users/parent1': { name: 'أحمد', nameNormalized: 'احمد', role: 'parent', isActive: true },
  });
  for (const path of ['loginUsernames/st000001', 'onboardingRequests/admin1_req']) {
    await assertSucceeds(authed('admin1').doc(path).get());
    await assertFails(authed('student1').doc(path).get());
    await assertFails(authed('parent1').doc(path).get());
    await assertFails(authed('admin1').doc(path).set({ uid: 'x' }));
  }
  await assertFails(authed('student1').collection('loginUsernames').where('uid', '==', 'student1').get());
  await assertSucceeds(authed('student1').doc('userPrivate/student1').get());
  await assertFails(authed('student1').doc('userPrivate/student1').update({ mustChangePassword: false }));
  await assertFails(authed('admin1').doc('userPrivate/student1').update({ mustChangePassword: false }));
  await assertSucceeds(
    authed('admin1')
      .collection('users')
      .where('role', '==', 'parent')
      .orderBy('nameNormalized')
      .startAt('احم')
      .endAt('احم\uf8ff')
      .limit(20)
      .get(),
  );
});

test('a newly provisioned Admin holds no authority until the server clears passwordChangeRequired', async () => {
  await seedAll({
    'users/admin2': { name: 'new', role: 'admin', isActive: true, passwordChangeRequired: true },
    'userPrivate/admin2': { email: 'a2@academy.test', emailSource: 'auth', mustChangePassword: true },
    'userPrivate/parent1': { email: 'p1@academy.test', emailSource: 'auth' },
    'payments/pay9': { parentId: 'parent1', studentId: 'student1', amount: 10, status: 'pending' },
    'notifications/n_admins': { audience: 'admin', title: 't', body: 'b' },
  });
  const pending = authed('admin2');
  // Sign-in still loads the own profile and private flag.
  await assertSucceeds(pending.doc('users/admin2').get());
  await assertSucceeds(pending.doc('userPrivate/admin2').get());
  // No Admin reads or writes.
  await assertFails(pending.doc('userPrivate/parent1').get());
  await assertFails(pending.collection('users').get());
  await assertFails(pending.doc('users/parent1').get());
  await assertFails(pending.doc('payments/pay9').get());
  await assertFails(pending.doc('users/parent1').update({ name: 'x' }));
  await assertFails(pending.doc('notifications/n_admins').get());
  // Nobody can clear (or set) the flag from a client.
  await assertFails(pending.doc('users/admin2').update({ passwordChangeRequired: false }));
  await assertFails(pending.doc('users/admin2').update({ passwordChangeRequired: FieldDelete() }));
  await assertFails(authed('admin1').doc('users/admin2').update({ passwordChangeRequired: false }));
  await assertFails(authed('admin1').doc('users/teacher1').update({ passwordChangeRequired: true }));
  await assertFails(pending.doc('userPrivate/admin2').update({ mustChangePassword: false }));
  // Existing Admins (no flag) are unaffected.
  await assertSucceeds(authed('admin1').doc('payments/pay9').get());
  await assertSucceeds(authed('admin1').doc('notifications/n_admins').get());
  // Once the server clears the flag, the role applies.
  await seedAll({ 'users/admin2': { name: 'new', role: 'admin', isActive: true, passwordChangeRequired: false } });
  await assertSucceeds(authed('admin2').doc('payments/pay9').get());
  await assertSucceeds(authed('admin2').doc('userPrivate/parent1').get());
});

test('staff status is server-owned: Admin cannot flip staff isActive or staffStatus from the client', async () => {
  await assertFails(authed('admin1').doc('users/teacher1').update({ isActive: false }));
  await assertFails(authed('admin1').doc('users/supervisor1').update({ isActive: false }));
  await assertFails(authed('admin1').doc('users/teacher1').update({ staffStatus: 'archived' }));
  await assertFails(authed('admin1').doc('users/parent1').update({ staffStatus: 'deleted' }));
  await assertFails(authed('teacher1').doc('users/teacher1').update({ staffStatus: 'active' }));
  await assertFails(authed('teacher1').doc('users/teacher1').update({ deletedAt: new Date() }));
  // Non-staff accounts keep the existing Admin activation path.
  await assertSucceeds(authed('admin1').doc('users/parent1').update({ isActive: false }));
  await assertSucceeds(authed('admin1').doc('users/teacher1').update({ name: 'أ. أحمد' }));
});

test('halaqa name index is admin-readable and never client-written', async () => {
  await assertSucceeds(authed('admin1').doc('halaqaNameIndex/حلقه h1').get());
  await assertFails(authed('teacher1').doc('halaqaNameIndex/حلقه h1').get());
  await assertFails(authed('admin1').doc('halaqaNameIndex/x').set({ halaqaId: 'h9' }));
});

test('admin report queries (date-ranged, bounded) are allowed only for Admin', async () => {
  await seedAll({
    'attendanceRecords/a1': { studentId: 'student1', halaqaId: 'h1', status: 'present', date: new Date('2026-10-05T00:00:00Z') },
    'sessions/s1': { halaqaId: 'h1', teacherId: 'teacher1', status: 'completed', date: '2026-10-05', startAt: new Date('2026-10-05T16:00:00Z') },
    'payments/p1': { parentId: 'parent1', studentId: 'student1', amount: 300, status: 'paid', dueDate: new Date('2026-10-01T00:00:00Z') },
  });
  const from = new Date('2026-10-01T00:00:00Z');
  const to = new Date('2026-11-01T00:00:00Z');
  const attendance = (db, halaqaId) => {
    let q = db.collection('attendanceRecords');
    if (halaqaId) q = q.where('halaqaId', '==', halaqaId);
    return q.where('date', '>=', from).where('date', '<', to).orderBy('date').limit(5000).get();
  };
  const sessions = (db) => db.collection('sessions')
    .where('date', '>=', '2026-10-01').where('date', '<=', '2026-10-31').orderBy('date').limit(5000).get();
  const payments = (db) => db.collection('payments').where('status', '==', 'paid')
    .where('dueDate', '>=', from).where('dueDate', '<', to).orderBy('dueDate', 'desc').limit(2000).get();

  const a = authed('admin1');
  const rows = await assertSucceeds(attendance(a));
  if (rows.size !== 1) throw new Error('attendance range');
  await assertSucceeds(attendance(a, 'h1'));
  await assertSucceeds(sessions(a));
  const paid = await assertSucceeds(payments(a));
  if (paid.size !== 1) throw new Error('payments range');
  await assertFails(attendance(authed('teacher2')));
  await assertFails(payments(authed('supervisor1')));
});

test('admin halaqa details: halaqa doc, roster profiles, attendance and recitations are readable', async () => {
  await seedAll({
    'studentProfiles/student1': { name: 'S1', halaqaId: 'h1', overallProgressPercent: 10 },
    'attendanceRecords/a1': { studentId: 'student1', halaqaId: 'h1', status: 'present', date: new Date('2026-10-05T00:00:00Z') },
    'recitationRecords/r1': { studentId: 'student1', halaqaId: 'h1', teacherId: 'teacher1', grade: 'excellent' },
  });
  const a = authed('admin1');
  await assertSucceeds(a.doc('halaqat/h1').get());
  const profiles = await assertSucceeds(
    a.collection('studentProfiles').where(documentId(), 'in', ['student1']).get(),
  );
  if (profiles.size !== 1) throw new Error('roster profile');
  await assertSucceeds(
    a.collection('attendanceRecords').where('halaqaId', '==', 'h1')
      .where('date', '>=', new Date('2026-09-01T00:00:00Z')).get(),
  );
  await assertSucceeds(a.collection('recitationRecords').where('halaqaId', '==', 'h1').get());
});

test('reward history: admin lists recent awards; clients never write them', async () => {
  await seedAll({
    'achievements/a1': { studentId: 'student1', recipientStudentIds: ['student1'], title: 'T', type: 'achievement', date: new Date('2026-10-05T00:00:00Z') },
  });
  const recent = (db) => db.collection('achievements').orderBy('date', 'desc').limit(30).get();
  const rows = await assertSucceeds(recent(authed('admin1')));
  if (rows.size !== 1) throw new Error('history');
  await assertFails(recent(authed('parent1')));
  await assertFails(authed('admin1').collection('achievements').add({ title: 'x' }));
});

test('broadcast: idempotent id, sender must be the caller, admin can count the audience', async () => {
  const a = authed('admin1');
  const fields = (extra = {}) => ({
    channel: 'admin_ops_broadcast', audience: 'parent', title: 't', body: 'b',
    type: 'general', readBy: [], hasAudioAlert: false, createdAt: new Date(), ...extra,
  });
  const ref = a.collection('notifications').doc('req123');
  // The transaction reads the request id first; absent docs are readable by Admin.
  await assertSucceeds(ref.get());
  await assertSucceeds(ref.set(fields({ senderId: 'admin1' })));
  await assertFails(a.collection('notifications').doc('req124').set(fields({ senderId: 'teacher1' })));
  await assertSucceeds(a.collection('notifications').doc('legacy').set(fields()));
  // A replay of the same id is an update, which Admin cannot perform.
  await assertFails(ref.set(fields({ senderId: 'admin1', title: 'again' })));

  const parentFeed = await assertSucceeds(
    authed('parent1').collection('notifications').where('audience', 'in', ['parent1', 'parent', 'all']).get(),
  );
  if (parentFeed.size !== 2) throw new Error(`parent sees ${parentFeed.size}`);

  const users = (db) => getCountFromServer(query(collection(db, 'users'), where('role', '==', 'parent')));
  const counted = await assertSucceeds(users(a));
  if (counted.data().count !== 3) throw new Error(`count ${counted.data().count}`);
});

test('group libraries list only the caller\'s own groups', async () => {
  await seedAll({
    'conversations/g1': { kind: 'custom_group', title: 'G1', participantIds: ['admin1', 'parent1'] },
    'conversations/g2': { kind: 'halaqa_group', title: 'G2', participantIds: ['teacher1', 'admin1'] },
  });
  const groupsOf = (uid, member = uid) =>
    authed(uid).collection('conversations')
      .where('participantIds', 'array-contains', member)
      .where('kind', 'in', ['halaqa_group', 'custom_group'])
      .limit(200)
      .get();
  const mine = await assertSucceeds(groupsOf('admin1'));
  if (mine.size !== 2) throw new Error(`expected 2 groups, got ${mine.size}`);
  const parent = await assertSucceeds(groupsOf('parent1'));
  if (parent.size !== 1) throw new Error('parent sees only g1');
  await assertFails(groupsOf('parent1', 'admin1'));
});

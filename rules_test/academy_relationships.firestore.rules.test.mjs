/**
 * Academy relationships — assistant teachers, temporary cover, relationship
 * history, academy reference codes and server-owned assignment fields.
 *
 * Run (isolated emulator):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test rules_test/academy_relationships.firestore.rules.test.mjs"
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

const halaqa = (extra = {}) => ({
  name: 'H',
  teacherId: 'teacher1',
  supervisorId: 'supervisor1',
  studentIds: ['student1'],
  assistantTeacherIds: [],
  coverTeacherId: '',
  coverId: '',
  status: 'active',
  ...extra,
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  const user = (role, extra = {}) => ({ name: role, role, isActive: true, ...extra });
  await seedAll({
    'users/admin1': user('admin', { academyRef: null }),
    'users/teacher1': user('teacher', { academyRef: 'T-001' }),
    'users/teacher2': user('teacher', { academyRef: 'T-002' }),
    'users/supervisor1': user('supervisor', { academyRef: 'V-001' }),
    'users/assistant1': user('assistant_teacher', { academyRef: 'A-001' }),
    'users/assistant2': user('assistant_teacher', { academyRef: 'A-002' }),
    'users/assistantOff': user('assistant_teacher', { isActive: false }),
    'users/parent1': user('parent', { academyRef: 'P-001' }),
    'users/student1': user('student', { academyRef: 'S-001' }),
    'users/student2': user('student', { academyRef: 'S-002' }),
    'parentProfiles/parent1': { childrenIds: ['student1'] },
    'halaqat/h1': halaqa({ assistantTeacherIds: ['assistant1', 'assistantOff'] }),
    'halaqat/h2': halaqa({ name: 'H2', teacherId: 'teacher2', studentIds: ['student2'] }),
    'attendanceRecords/a1': { studentId: 'student1', halaqaId: 'h1', status: 'present', date: new Date('2026-10-05T00:00:00Z') },
    'attendanceRecords/a2': { studentId: 'student2', halaqaId: 'h2', status: 'present', date: new Date('2026-10-05T00:00:00Z') },
    'recitationRecords/r1': { studentId: 'student1', halaqaId: 'h1', teacherId: 'teacher1', grade: 'excellent' },
    'sessions/s1': { halaqaId: 'h1', teacherId: 'teacher1', status: 'scheduled', date: '2026-11-02' },
    'halaqaCoverPeriods/cv1': { halaqaId: 'h1', coverTeacherId: 'assistant1', status: 'completed' },
    'relationshipHistory/e1': { kind: 'parent_child', operation: 'link', subjectIds: ['parent1', 'student1'], at: new Date() },
    'academyRefCounters/student': { last: 2 },
  });
});

test('an assigned assistant reads its halaqa only; inactive assistants read nothing', async () => {
  await assertSucceeds(authed('assistant1').doc('halaqat/h1').get());
  await assertSucceeds(
    authed('assistant1').collection('halaqat').where('assistantTeacherIds', 'array-contains', 'assistant1').get(),
  );
  await assertFails(authed('assistant1').doc('halaqat/h2').get());
  await assertFails(authed('assistant1').collection('halaqat').get());
  await assertFails(authed('assistant2').doc('halaqat/h1').get());
  await assertFails(authed('assistantOff').doc('halaqat/h1').get());
});

test('a non-cover assistant cannot read student records or sessions', async () => {
  await assertFails(authed('assistant1').doc('attendanceRecords/a1').get());
  await assertFails(authed('assistant1').doc('recitationRecords/r1').get());
  await assertFails(authed('assistant1').doc('sessions/s1').get());
});

test('the active cover reads the covered halaqa, its sessions and records; never another halaqa', async () => {
  await seedAll({ 'halaqat/h1': halaqa({ assistantTeacherIds: ['assistant1'], coverTeacherId: 'assistant1', coverId: 'cv2' }) });
  const cover = authed('assistant1');
  await assertSucceeds(cover.doc('halaqat/h1').get());
  const covered = await assertSucceeds(
    cover.collection('halaqat').where('coverTeacherId', '==', 'assistant1').where('coverId', '!=', '').get(),
  );
  if (covered.size !== 1) throw new Error(`covered ${covered.size}`);
  await assertFails(cover.collection('halaqat').where('coverTeacherId', '==', 'assistant1').get());
  await assertSucceeds(cover.doc('sessions/s1').get());
  await assertSucceeds(cover.doc('attendanceRecords/a1').get());
  await assertSucceeds(cover.doc('recitationRecords/r1').get());
  await assertFails(cover.doc('attendanceRecords/a2').get());
  await assertFails(cover.doc('halaqat/h2').get());
  // Records stay callable-only for the cover as well.
  await assertFails(cover.collection('attendanceRecords').add({ studentId: 'student1', halaqaId: 'h1', status: 'present' }));
  await assertFails(cover.doc('sessions/s1').update({ status: 'in_progress', updatedAt: new Date() }));
});

test('a teacher covering another halaqa reads it only while the cover is active', async () => {
  await seedAll({ 'halaqat/h1': halaqa({ coverTeacherId: 'teacher2', coverId: 'cv3' }) });
  await assertSucceeds(authed('teacher2').doc('halaqat/h1').get());
  await assertSucceeds(authed('teacher2').doc('attendanceRecords/a1').get());
  await assertSucceeds(authed('teacher2').doc('sessions/s1').get());
  // Cover completed: the server clears coverId/coverTeacherId and access ends.
  await seedAll({ 'halaqat/h1': halaqa({ coverTeacherId: '', coverId: '' }) });
  await assertFails(authed('teacher2').doc('halaqat/h1').get());
  await assertFails(authed('teacher2').doc('attendanceRecords/a1').get());
  await assertFails(authed('teacher2').doc('sessions/s1').get());
  // A stale coverTeacherId without an active coverId grants nothing.
  await seedAll({ 'halaqat/h1': halaqa({ coverTeacherId: 'teacher2', coverId: '' }) });
  await assertFails(authed('teacher2').doc('attendanceRecords/a1').get());
  // The primary teacher keeps access throughout.
  await assertSucceeds(authed('teacher1').doc('attendanceRecords/a1').get());
});

test('cover periods, relationship history and academy counters are Admin-read and never client-written', async () => {
  for (const path of ['halaqaCoverPeriods/cv1', 'relationshipHistory/e1', 'academyRefCounters/student']) {
    await assertSucceeds(authed('admin1').doc(path).get());
    for (const uid of ['teacher1', 'supervisor1', 'assistant1', 'parent1', 'student1']) {
      await assertFails(authed(uid).doc(path).get());
    }
    await assertFails(authed('admin1').doc(path).set({ x: 1 }));
    await assertFails(authed('admin1').doc(path).delete());
  }
  await assertSucceeds(
    authed('admin1').collection('relationshipHistory')
      .where('subjectIds', 'array-contains', 'student1').orderBy('at', 'desc').limit(20).get(),
  );
  await assertFails(authed('admin1').collection('relationshipHistory').add({ kind: 'parent_child' }));
});

test('Admin cannot change staff, assistant, cover or academy codes on a halaqa from the client', async () => {
  const a = authed('admin1');
  await assertFails(a.doc('halaqat/h1').update({ supervisorId: 'supervisor2' }));
  await assertFails(a.doc('halaqat/h1').update({ teacherId: 'teacher2' }));
  await assertFails(a.doc('halaqat/h1').update({ assistantTeacherIds: ['assistant2'] }));
  await assertFails(a.doc('halaqat/h1').update({ coverTeacherId: 'teacher2', coverId: 'x' }));
  await assertFails(a.doc('halaqat/h1').update({ academyRef: 'H-009' }));
  // P2-3: name (bound to halaqaNameIndex) and status are server-owned too.
  await assertFails(a.doc('halaqat/h1').update({ name: 'حلقة النور' }));
  await assertFails(a.doc('halaqat/h1').update({ name: 'H2' }));
  await assertFails(a.doc('halaqat/h1').update({ status: 'closed' }));
  await assertFails(a.doc('halaqat/h1').update({ status: 'active', updatedAt: new Date() }));
  await assertSucceeds(a.doc('halaqat/h1').get());
});

test('halaqa codes come only from the server: no client halaqa creation, counter or ledger writes', async () => {
  await seedAll({
    'halaqat/h1': halaqa({ academyRef: 'H-001' }),
    'academyRefCounters/halaqa': { last: 1 },
    'importRows/H-001': { kind: 'halaqa', id: 'h1', status: 'done', origin: 'manual' },
  });
  const a = authed('admin1');
  await assertFails(a.doc('halaqat/h9').set(halaqa({ academyRef: 'H-002' })));
  await assertFails(a.doc('halaqat/h9').set(halaqa()));
  await assertFails(a.doc('halaqat/h1').update({ academyRef: 'H-002' }));
  await assertFails(a.doc('halaqat/h1').update({ academyRef: '' }));
  await assertFails(a.doc('academyRefCounters/halaqa').set({ last: 0 }));
  await assertFails(a.doc('importRows/H-002').set({ kind: 'halaqa', id: 'h9', status: 'done' }));
  await assertFails(a.doc('importRows/H-001').delete());
  await assertSucceeds(a.doc('academyRefCounters/halaqa').get());
  await assertSucceeds(a.doc('importRows/H-001').get());
  await assertSucceeds(a.collection('halaqat').where('academyRef', '==', 'H-001').limit(10).get());
  await assertFails(authed('teacher1').doc('importRows/H-001').get());
  await assertFails(authed('teacher1').doc('academyRefCounters/halaqa').get());
});

test('academy codes and roles are server-owned: no self-promotion, no client code edits', async () => {
  await assertFails(authed('teacher1').doc('users/teacher1').update({ role: 'admin' }));
  await assertFails(authed('assistant1').doc('users/assistant1').update({ role: 'teacher' }));
  await assertFails(authed('assistant1').doc('users/assistant1').update({ academyRef: 'T-009' }));
  await assertFails(authed('parent1').doc('users/parent1').update({ academyRef: 'P-002' }));
  await assertFails(authed('admin1').doc('users/parent1').update({ academyRef: 'P-002' }));
  await assertFails(authed('admin1').doc('users/parent1').update({ role: 'admin' }));
  await assertFails(authed('admin1').collection('users').doc('newAdmin').set({ role: 'admin', name: 'x', isActive: true }));
  await assertSucceeds(authed('admin1').doc('users/parent1').update({ name: 'أبو عمر' }));
});

test('P2-1 / P2-2: login state and lifecycle are server-owned for every role', async () => {
  const a = authed('admin1');
  for (const uid of ['parent1', 'student1', 'teacher1', 'assistant1']) {
    await assertFails(a.doc(`users/${uid}`).update({ isActive: false }));
  }
  await assertFails(a.doc('users/student1').update({ lifecycle: 'archived' }));
  await assertFails(a.doc('users/student1').update({ lifecycle: 'active', isActive: true }));
  await assertFails(authed('student1').doc('users/student1').update({ isActive: false }));
  await assertSucceeds(a.doc('users/student1').update({ name: 'سالم' }));
});

test('assistants hold no directory, assignment or Admin authority', async () => {
  const as = authed('assistant1');
  await assertFails(as.collection('users').where('role', '==', 'student').get());
  await assertFails(as.doc('halaqat/h1').update({ assistantTeacherIds: [] }));
  await assertFails(as.doc('halaqat/h1').update({ name: 'x' }));
  await assertFails(as.doc('parentProfiles/parent1').get());
  await assertFails(as.collection('studentSearch').get());
  await assertFails(as.doc('payments/none').get());
  // Assistant status is server-owned like other staff.
  await assertFails(authed('admin1').doc('users/assistant1').update({ isActive: false }));
  await assertFails(authed('admin1').doc('users/assistant1').update({ staffStatus: 'archived' }));
});

test('Admin directory queries: role pages, academy code lookup and relationship lookups', async () => {
  const a = authed('admin1');
  await assertSucceeds(a.collection('users').where('role', '==', 'assistant_teacher').orderBy('name').limit(20).get());
  await assertSucceeds(a.collection('users').where('academyRef', '==', 'S-001').limit(5).get());
  await assertSucceeds(a.collection('halaqat').where('assistantTeacherIds', 'array-contains', 'assistant1').get());
  await assertSucceeds(a.collection('halaqat').where('coverTeacherId', '==', 'teacher2').get());
  await assertSucceeds(a.collection('parentProfiles').where('childrenIds', 'array-contains', 'student1').get());
  await assertSucceeds(a.collection('halaqaCoverPeriods').where('halaqaId', '==', 'h1').limit(20).get());
  for (const uid of ['parent1', 'student1', 'assistant1']) {
    await assertFails(authed(uid).collection('parentProfiles').where('childrenIds', 'array-contains', 'student1').get());
  }
});

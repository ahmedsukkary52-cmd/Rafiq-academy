/**
 * P1-5 — family and student privacy: staff read only the students they
 * serve, never the parent ↔ child graph, and never list achievements outside
 * their own halaqa.
 *
 * Run (isolated emulator):
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test rules_test/profile_privacy.firestore.rules.test.mjs"
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

const halaqa = (extra) => ({
  name: 'H',
  studentIds: [],
  assistantTeacherIds: [],
  coverTeacherId: '',
  coverId: '',
  status: 'active',
  ...extra,
});

// h1: teacher1 / supervisor1 — student1 (primary), student3 (second halaqa)
// h2: teacher2 / supervisor2 — student2 (primary), student3 (primary)
test.beforeEach(async () => {
  await testEnv.clearFirestore();
  const user = (role, extra = {}) => ({ name: role, role, isActive: true, ...extra });
  await seedAll({
    'users/admin1': user('admin'),
    'users/teacher1': user('teacher'),
    'users/teacher2': user('teacher'),
    'users/teacherOff': user('teacher', { isActive: false }),
    'users/supervisor1': user('supervisor'),
    'users/supervisor2': user('supervisor'),
    'users/assistant1': user('assistant_teacher'),
    'users/parent1': user('parent'),
    'users/parent2': user('parent'),
    'users/student1': user('student'),
    'users/student2': user('student'),
    'users/student3': user('student'),
    'users/student4': user('student'),
    'halaqat/h1': halaqa({ teacherId: 'teacher1', supervisorId: 'supervisor1', studentIds: ['student1', 'student3', 'student4'] }),
    'halaqat/h2': halaqa({ teacherId: 'teacher2', supervisorId: 'supervisor2', studentIds: ['student2', 'student3'] }),
    'halaqat/hOff': halaqa({ teacherId: 'teacherOff', supervisorId: 'supervisor2', studentIds: ['student1'] }),
    'studentProfiles/student1': { name: 'سالم', halaqaId: 'h1' },
    'studentProfiles/student2': { name: 'سارة', halaqaId: 'h2' },
    'studentProfiles/student3': { name: 'عمر', halaqaId: 'h2' },
    'studentProfiles/student4': { name: 'ليلى', halaqaId: 'h1' },
    // CF-maintained roster scope (every halaqa of the student).
    'studentSearch/student3': { visibleTo: ['teacher2', 'supervisor2', 'teacher1', 'supervisor1'] },
    'parentProfiles/parent1': { childrenIds: ['student1'] },
    'parentProfiles/parent2': { childrenIds: ['student2', 'student3'] },
    'achievements/a1': { studentId: 'student1', halaqaId: 'h1', halaqaIds: ['h1'], recipientStudentIds: ['student1'], type: 'x' },
    'achievements/a2': { studentId: 'student2', halaqaId: 'h2', halaqaIds: ['h2', 'h1'], recipientStudentIds: ['student2'], type: 'x' },
  });
});

test('unrelated teacher or supervisor cannot read a student profile', async () => {
  for (const uid of ['teacher2', 'supervisor2']) {
    await assertFails(authed(uid).doc('studentProfiles/student1').get());
  }
  for (const uid of ['teacher1', 'supervisor1']) {
    await assertFails(authed(uid).doc('studentProfiles/student2').get());
  }
  await assertFails(authed('assistant1').doc('studentProfiles/student1').get());
});

test('related staff read the students they serve, including a second halaqa', async () => {
  for (const uid of ['teacher1', 'supervisor1']) {
    await assertSucceeds(authed(uid).doc('studentProfiles/student1').get());
    await assertSucceeds(authed(uid).doc('studentProfiles/student4').get());
    // student3's primary halaqa is h2; h1 staff reach it through roster scope.
    await assertSucceeds(authed(uid).doc('studentProfiles/student3').get());
  }
  for (const uid of ['teacher2', 'supervisor2']) {
    await assertSucceeds(authed(uid).doc('studentProfiles/student2').get());
    await assertSucceeds(authed(uid).doc('studentProfiles/student3').get());
  }
});

test('a stale primary pointer or an inactive teacher grants nothing', async () => {
  // Pointer says h1 but the roster no longer holds the student.
  await seedAll({
    'studentProfiles/student2': { name: 'سارة', halaqaId: 'h1' },
    'halaqat/h1': halaqa({ teacherId: 'teacher1', supervisorId: 'supervisor1', studentIds: ['student1'] }),
  });
  await assertFails(authed('teacher1').doc('studentProfiles/student2').get());
  // teacherOff is named on hOff, which rosters student1, but is deactivated.
  await seedAll({ 'studentProfiles/student1': { name: 'سالم', halaqaId: 'hOff' } });
  await assertFails(authed('teacherOff').doc('studentProfiles/student1').get());
});

test('staff cannot list student profiles, even with ids of their own students', async () => {
  for (const uid of ['teacher1', 'supervisor1', 'teacher2', 'supervisor2']) {
    await assertFails(authed(uid).collection('studentProfiles').get());
    await assertFails(authed(uid).collection('studentProfiles').where('halaqaId', '==', 'h1').get());
  }
  await assertFails(
    authed('teacher1').collection('studentProfiles').where('__name__', 'in', ['student1', 'student4']).get(),
  );
});

test('the active cover reads the covered halaqa students only while covering', async () => {
  await seedAll({ 'halaqat/h1': halaqa({ teacherId: 'teacher1', supervisorId: 'supervisor1', studentIds: ['student1', 'student3', 'student4'], coverTeacherId: 'teacher2', coverId: 'cv1' }) });
  await assertSucceeds(authed('teacher2').doc('studentProfiles/student1').get());
  await seedAll({ 'halaqat/h1': halaqa({ teacherId: 'teacher1', supervisorId: 'supervisor1', studentIds: ['student1', 'student3', 'student4'] }) });
  await assertFails(authed('teacher2').doc('studentProfiles/student1').get());
});

test('student, linked parent, classmates and Admin keep their access', async () => {
  await assertSucceeds(authed('student1').doc('studentProfiles/student1').get());
  // Classmate on student1's primary roster (group chat names).
  await assertSucceeds(authed('student4').doc('studentProfiles/student1').get());
  await assertFails(authed('student2').doc('studentProfiles/student1').get());
  await assertSucceeds(authed('parent1').doc('studentProfiles/student1').get());
  await assertFails(authed('parent1').doc('studentProfiles/student2').get());
  await assertSucceeds(authed('parent2').doc('studentProfiles/student3').get());
  await assertSucceeds(authed('admin1').doc('studentProfiles/student2').get());
  await assertSucceeds(authed('admin1').collection('studentProfiles').get());
});

test('parent profiles (the family graph) are read by the parent and Admin only', async () => {
  for (const uid of ['teacher1', 'supervisor1', 'teacher2', 'supervisor2', 'assistant1', 'student1', 'parent2']) {
    await assertFails(authed(uid).doc('parentProfiles/parent1').get());
    await assertFails(authed(uid).collection('parentProfiles').get());
    await assertFails(
      authed(uid).collection('parentProfiles').where('childrenIds', 'array-contains', 'student1').get(),
    );
  }
  await assertSucceeds(authed('parent1').doc('parentProfiles/parent1').get());
  await assertSucceeds(authed('admin1').doc('parentProfiles/parent1').get());
  await assertSucceeds(
    authed('admin1').collection('parentProfiles').where('childrenIds', 'array-contains', 'student1').get(),
  );
});

test('achievements: staff list their own halaqa only; unrelated staff denied', async () => {
  await assertSucceeds(authed('teacher1').collection('achievements').where('halaqaId', '==', 'h1').get());
  await assertSucceeds(authed('supervisor1').collection('achievements').where('halaqaId', '==', 'h1').get());
  await assertFails(authed('teacher1').collection('achievements').where('halaqaId', '==', 'h2').get());
  await assertFails(authed('teacher2').collection('achievements').where('halaqaId', '==', 'h1').get());
  for (const uid of ['teacher1', 'supervisor1', 'teacher2']) {
    await assertFails(authed(uid).collection('achievements').get());
    await assertFails(authed(uid).collection('achievements').where('halaqaIds', 'array-contains', 'h1').get());
  }
  await assertSucceeds(authed('teacher1').doc('achievements/a1').get());
  await assertFails(authed('teacher2').doc('achievements/a1').get());
  await assertFails(authed('supervisor1').doc('achievements/a2').get());
});

test('achievements: student, parent and Admin keep their access', async () => {
  await assertSucceeds(authed('student1').doc('achievements/a1').get());
  await assertSucceeds(authed('student1').collection('achievements').where('studentId', '==', 'student1').get());
  await assertSucceeds(
    authed('student1').collection('achievements').where('recipientStudentIds', 'array-contains', 'student1').get(),
  );
  await assertFails(authed('student1').doc('achievements/a2').get());
  await assertSucceeds(authed('parent1').doc('achievements/a1').get());
  await assertFails(authed('parent1').doc('achievements/a2').get());
  await assertSucceeds(authed('admin1').collection('achievements').get());
});

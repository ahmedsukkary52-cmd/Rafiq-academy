/**
 * P0 PRODUCTION COMPLETION — Firestore rule changes (ALLOW + DENY).
 *
 * Halaqa creation / schedule are callable-only (P0-04), homework reward
 * markers and `completedAt` are server-owned (P0-05), posts and the shared
 * content library are Halaqa-scoped (§7 / §8), and the Supervisor payment
 * review list query is roster-scoped (P0-03).
 *
 * Run from repo root:
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "npm --prefix rules_test run test:p0"
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

function post(authorId, halaqaId, audienceTarget = halaqaId) {
  return {
    authorId,
    halaqaId,
    audienceTarget,
    content: 'x',
    likedBy: [],
    commentsCount: 0,
    isPinned: false,
  };
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
    'users/parent3': user('parent'),
    'users/student1': user('student'),
    'users/student2': user('student'),
    'halaqat/h1': {
      name: 'H1',
      teacherId: 'teacher1',
      supervisorId: 'supervisor1',
      studentIds: ['student1'],
      schedule: [{ day: 'الاثنين', startTime: '16:00', endTime: '17:00', slotId: 'slot-1' }],
      status: 'active',
    },
    'halaqat/h2': {
      name: 'H2',
      teacherId: 'teacher2',
      supervisorId: 'supervisor2',
      studentIds: ['student2'],
      schedule: [{ day: 'الثلاثاء', startTime: '16:00', endTime: '17:00', slotId: 'slot-2' }],
      status: 'active',
    },
    'studentProfiles/student1': { uid: 'student1', halaqaId: 'h1' },
    'studentProfiles/student2': { uid: 'student2', halaqaId: 'h2' },
    'parentProfiles/parent1': { uid: 'parent1', childrenIds: ['student1'] },
    'parentProfiles/parent2': { uid: 'parent2', childrenIds: ['student2'] },
    'parentProfiles/parent3': { uid: 'parent3', childrenIds: [] },
    'homeworkRewards/hw1': {
      assignmentId: 'hw1',
      studentId: 'student1',
      coins: 35,
      requiredKinds: ['reading', 'listening'],
    },
    'halaqaScheduleLocks/teacher_teacher1': { teacherId: 'teacher1' },
    'assignments/hw1': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [{ id: 'reading', kind: 'reading', isCompleted: false }],
      isSubmitted: false,
      status: 'pending',
    },
    'assignments/legacy1': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      tasks: [],
      isSubmitted: false,
      status: 'pending',
    },
    'assignments/done1': {
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [],
      isSubmitted: true,
      status: 'completed',
      completedAt: new Date('2026-09-01T10:00:00Z'),
    },
    'posts/pH1': post('teacher1', 'h1'),
    'posts/pH2': post('teacher2', 'h2'),
    'posts/pAll': post('admin1', null, 'all'),
    'posts/pH1/comments/c1': { authorId: 'teacher1', text: 'x' },
    'contentLibrary/cH1': {
      title: 'H1 file',
      halaqaId: 'h1',
      uploadedBy: 'teacher1',
      storagePath: 'content_library/h1/teacher1/a.pdf',
    },
    'contentLibrary/cH2': {
      title: 'H2 file',
      halaqaId: 'h2',
      uploadedBy: 'teacher2',
      storagePath: 'content_library/h2/teacher2/a.pdf',
    },
    'contentLibrary/cLegacy': { title: 'legacy', uploadedBy: 'admin1' },
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
      amount: 100,
      status: 'due',
      reviewStatus: 'pending_review',
    },
  });
});

// ── P0-04 halaqa / schedule ────────────────────────────────────────────────

test('P0-04: no client role creates a Halaqa or edits its schedule/teacher', async () => {
  for (const uid of ALL_ROLES) {
    const db = authed(uid);
    await assertFails(
      db.doc('halaqat/new').set({
        name: 'x',
        teacherId: 'teacher1',
        studentIds: [],
        schedule: [{ day: 'السبت', startTime: '10:00', endTime: '11:00' }],
      }),
    );
    await assertFails(db.doc('halaqat/h1').update({ schedule: [] }));
    await assertFails(db.doc('halaqat/h1').update({ teacherId: 'teacher2' }));
    await assertFails(db.doc('halaqat/h1').update({ createdBy: uid }));
  }
});

test('P0-04: schedule locks are Admin-readable and server-written', async () => {
  await assertSucceeds(authed('admin1').doc('halaqaScheduleLocks/teacher_teacher1').get());
  for (const uid of ['supervisor1', 'teacher1', 'parent1', 'student1']) {
    await assertFails(authed(uid).doc('halaqaScheduleLocks/teacher_teacher1').get());
  }
  for (const uid of ALL_ROLES) {
    await assertFails(authed(uid).doc('halaqaScheduleLocks/teacher_teacher1').set({ x: 1 }));
    await assertFails(authed(uid).doc('halaqaScheduleLocks/teacher_teacher1').delete());
  }
});

// ── P0-05 homework reward ──────────────────────────────────────────────────

test('P0-05: reward markers are owner/Admin-readable and never client-written', async () => {
  await assertSucceeds(authed('student1').doc('homeworkRewards/hw1').get());
  await assertSucceeds(authed('admin1').doc('homeworkRewards/hw1').get());
  for (const uid of ['student2', 'teacher1', 'parent1', 'supervisor1']) {
    await assertFails(authed(uid).doc('homeworkRewards/hw1').get());
  }
  for (const uid of [...ALL_ROLES, 'student2']) {
    await assertFails(authed(uid).doc('homeworkRewards/hw1').delete());
    await assertFails(authed(uid).doc('homeworkRewards/hwX').set({ studentId: uid, coins: 100 }));
    await assertFails(authed(uid).doc('homeworkRewards/hw1').update({ coins: 0 }));
  }
});

test('P0-05: completedAt is server-owned (no set / move / clear)', async () => {
  await assertFails(
    authed('student1').doc('assignments/hw1').update({ completedAt: new Date() }),
  );
  await assertFails(
    authed('teacher1').doc('assignments/done1').update({ completedAt: null }),
  );
  await assertFails(
    authed('teacher1').doc('assignments/hw1').update({ completedAt: new Date() }),
  );
  await assertFails(
    authed('teacher1').collection('assignments').add({
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [],
      completedAt: new Date(),
    }),
  );
  // Teacher reopen without touching completedAt stays allowed.
  await assertSucceeds(
    authed('teacher1').doc('assignments/done1').update({ status: 'pending', isSubmitted: false }),
  );
  await assertSucceeds(
    authed('teacher1').collection('assignments').add({
      studentId: 'student1',
      halaqaId: 'h1',
      assignedBy: 'teacher1',
      kind: 'lessonHomework',
      tasks: [],
    }),
  );
});

test('P0-05: student ticks tasks but never rewrites kind or completion', async () => {
  const db = authed('student1');
  await assertSucceeds(
    db.doc('assignments/hw1').update({
      tasks: [{ id: 'reading', kind: 'reading', isCompleted: true }],
    }),
  );
  await assertFails(db.doc('assignments/hw1').update({ kind: 'quiz' }));
  await assertFails(db.doc('assignments/hw1').update({ kind: '' }));
  await assertFails(db.doc('assignments/hw1').update({ isSubmitted: true }));
  await assertFails(db.doc('assignments/hw1').update({ status: 'completed' }));
  // Legacy repair: kind may be set once, only to lessonHomework.
  await assertFails(db.doc('assignments/legacy1').update({ kind: 'quiz' }));
  await assertSucceeds(db.doc('assignments/legacy1').update({ kind: 'lessonHomework' }));
  await assertFails(
    authed('student2').doc('assignments/legacy1').update({ kind: 'lessonHomework' }),
  );
});

// ── §7 posts are Halaqa-scoped ─────────────────────────────────────────────

test('§7 posts: halaqa community reads its posts only; legacy "all" is Admin-only', async () => {
  for (const uid of ['student1', 'parent1', 'teacher1', 'supervisor1', 'admin1']) {
    await assertSucceeds(authed(uid).doc('posts/pH1').get());
  }
  for (const uid of ['student2', 'parent2', 'parent3', 'teacher2', 'supervisor2']) {
    await assertFails(authed(uid).doc('posts/pH1').get());
  }
  await assertSucceeds(authed('admin1').doc('posts/pAll').get());
  for (const uid of ['student1', 'parent1', 'teacher1', 'supervisor1']) {
    await assertFails(authed(uid).doc('posts/pAll').get());
  }
});

test('§7 posts: halaqa feed query is authorized per audience', async () => {
  const feed = (uid, h) =>
    authed(uid).collection('posts').where('audienceTarget', '==', h).get();
  await assertSucceeds(feed('student1', 'h1'));
  await assertSucceeds(feed('parent1', 'h1'));
  await assertSucceeds(feed('teacher1', 'h1'));
  await assertFails(feed('student1', 'h2'));
  await assertFails(feed('parent1', 'h2'));
  await assertFails(feed('student1', 'all'));
  await assertFails(authed('student1').collection('posts').get());
  await assertSucceeds(authed('admin1').collection('posts').get());
});

test('§7 posts: only halaqa staff/Admin author; no academy-wide target', async () => {
  await assertSucceeds(authed('teacher1').collection('posts').add(post('teacher1', 'h1')));
  await assertSucceeds(authed('supervisor1').collection('posts').add(post('supervisor1', 'h1')));
  await assertSucceeds(authed('admin1').collection('posts').add(post('admin1', 'h2')));
  await assertFails(authed('teacher1').collection('posts').add(post('teacher1', 'h2')));
  await assertFails(authed('teacher1').collection('posts').add(post('teacher1', 'h1', 'all')));
  await assertFails(authed('admin1').collection('posts').add(post('admin1', null, 'all')));
  await assertFails(authed('student1').collection('posts').add(post('student1', 'h1')));
  await assertFails(authed('parent1').collection('posts').add(post('parent1', 'h1')));
});

test('§7 posts: audience is frozen; likes/comments stay in the halaqa', async () => {
  await assertFails(authed('teacher1').doc('posts/pH1').update({ audienceTarget: 'all' }));
  await assertFails(authed('admin1').doc('posts/pH1').update({ halaqaId: 'h2', audienceTarget: 'h2' }));
  await assertSucceeds(authed('parent1').doc('posts/pH1').update({ likedBy: ['parent1'] }));
  await assertFails(authed('parent2').doc('posts/pH1').update({ likedBy: ['parent2'] }));
  await assertSucceeds(authed('student1').doc('posts/pH1/comments/c1').get());
  await assertFails(authed('student2').doc('posts/pH1/comments/c1').get());
  await assertSucceeds(
    authed('student1').collection('posts/pH1/comments').add({ authorId: 'student1', text: 'x' }),
  );
  await assertFails(
    authed('student2').collection('posts/pH1/comments').add({ authorId: 'student2', text: 'x' }),
  );
});

// ── §8 content library is Halaqa-scoped ────────────────────────────────────

test('§8 content: halaqa community reads; other halaqat and legacy denied', async () => {
  for (const uid of ['student1', 'parent1', 'teacher1', 'supervisor1', 'admin1']) {
    await assertSucceeds(authed(uid).doc('contentLibrary/cH1').get());
  }
  for (const uid of ['student2', 'parent2', 'parent3', 'teacher2', 'supervisor2']) {
    await assertFails(authed(uid).doc('contentLibrary/cH1').get());
  }
  await assertSucceeds(authed('admin1').doc('contentLibrary/cLegacy').get());
  await assertFails(authed('teacher1').doc('contentLibrary/cLegacy').get());
  await assertSucceeds(
    authed('parent1').collection('contentLibrary').where('halaqaId', '==', 'h1').get(),
  );
  await assertFails(
    authed('parent1').collection('contentLibrary').where('halaqaId', '==', 'h2').get(),
  );
});

test('§8 content: staff of the halaqa / Admin manage; shape enforced', async () => {
  const item = (uid, h, path = `content_library/${h}/${uid}/f.pdf`) => ({
    title: 'x',
    type: 'pdf',
    uploadedBy: uid,
    halaqaId: h,
    storagePath: path,
  });
  await assertSucceeds(authed('supervisor1').collection('contentLibrary').add(item('supervisor1', 'h1')));
  await assertSucceeds(authed('admin1').collection('contentLibrary').add(item('admin1', 'h2')));
  await assertFails(authed('teacher1').collection('contentLibrary').add(item('teacher1', 'h2')));
  await assertFails(
    authed('teacher1').collection('contentLibrary').add(item('teacher1', 'h1', 'content/teacher1/f.pdf')),
  );
  await assertFails(
    authed('teacher1').collection('contentLibrary').add(
      item('teacher1', 'h1', 'content_library/h2/teacher1/f.pdf'),
    ),
  );
  await assertFails(authed('student1').collection('contentLibrary').add(item('student1', 'h1')));
  await assertFails(authed('parent1').collection('contentLibrary').add(item('parent1', 'h1')));
  await assertFails(authed('teacher1').doc('contentLibrary/cH1').update({ title: 'y' }));
  await assertFails(authed('teacher2').doc('contentLibrary/cH1').delete());
  await assertSucceeds(authed('supervisor1').doc('contentLibrary/cH1').delete());
});

// ── P0-03 payment review list scope ────────────────────────────────────────

test('P0-03: Supervisor lists pending proofs per supervised student only', async () => {
  const pending = (uid, studentId) =>
    authed(uid)
      .collection('payments')
      .where('studentId', '==', studentId)
      .where('reviewStatus', '==', 'pending_review')
      .get();
  await assertSucceeds(pending('supervisor1', 'student1'));
  await assertFails(pending('supervisor1', 'student2'));
  await assertFails(pending('teacher1', 'student1'));
  await assertSucceeds(
    authed('admin1').collection('payments').where('reviewStatus', '==', 'pending_review').get(),
  );
  await assertFails(
    authed('supervisor1').collection('payments').where('reviewStatus', '==', 'pending_review').get(),
  );
});

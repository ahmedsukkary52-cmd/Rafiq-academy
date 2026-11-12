/**
 * B14 Phase 2 — `halaqaMeetingLinks/{halaqaId}` access matrix.
 *
 * Reads: active Admin (get + list); the active, assigned Supervisor (get);
 * an active, non-archived roster Student with a studentProfiles doc (get).
 * Everyone else is denied, and no client — not even Admin — writes directly.
 *
 * Run from repo root:
 *   npx firebase emulators:exec --project demo-rafiq-rules --only firestore \
 *     "node --test --test-concurrency=1 rules_test/b14_meeting_links.rules.test.mjs"
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

const LINK = 'https://meet.example.test/b14-room';
const COL = 'halaqaMeetingLinks';

// Values normalizeLifecycle treats as active that the rules also allow.
const ACTIVE_LIFECYCLES = {
  active: 'active',
  padded_active: '  active ',
  upper_archived: 'ARCHIVED',
  title_archived: 'Archived',
  unknown: 'paused',
  empty: '',
  number: 42,
  null_value: null,
  boolean: true,
  list: ['archived'],
  map: { value: 'archived' },
};
// Values normalizeLifecycle treats as archived (JS trim + exact match).
const ARCHIVED_LIFECYCLES = {
  exact: 'archived',
  padded: '  archived  ',
  tab_newline: '\tarchived\n',
  vertical_tab: '\varchived',
  crlf_line_separator: '\r\narchived\u2028',
  no_break_space: '\u00A0archived',
  ideographic_space: 'archived\u3000',
  bom: '\uFEFFarchived',
};
// Values normalizeLifecycle treats as ACTIVE that the rules intentionally
// deny: any string containing lowercase 'archived' fails closed.
const CONSERVATIVE_DENY_LIFECYCLES = {
  suffixed: 'archived-soon',
  prefixed: 'unarchived',
  phrase: 'not archived',
  zero_width_space_prefix: '\u200Barchived',
};
const lcId = (key) => `lc_${key}`;
const archId = (key) => `arch_${key}`;
const consId = (key) => `cons_${key}`;

let testEnv;

function authed(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function unauthed() {
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

async function allow(label, promise) {
  try {
    return await assertSucceeds(promise);
  } catch (e) {
    throw new Error(`expected ALLOW: ${label} (${e.code ?? e.message})`);
  }
}

async function deny(label, promise) {
  try {
    await assertFails(promise);
  } catch {
    throw new Error(`expected DENY: ${label}`);
  }
}

const linkDoc = () => ({
  meetingLink: LINK,
  updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
});

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
  const profile = (uid, extra = {}) => ({ uid, points: 0, ...extra });

  const lifecycleUsers = {};
  const lifecycleProfiles = {};
  for (const [key, value] of Object.entries(ACTIVE_LIFECYCLES)) {
    lifecycleUsers[`users/${lcId(key)}`] = user('student');
    lifecycleProfiles[`studentProfiles/${lcId(key)}`] = profile(lcId(key), { halaqaId: 'h1', lifecycle: value });
  }
  for (const [key, value] of Object.entries(ARCHIVED_LIFECYCLES)) {
    lifecycleUsers[`users/${archId(key)}`] = user('student');
    lifecycleProfiles[`studentProfiles/${archId(key)}`] = profile(archId(key), { halaqaId: 'h1', lifecycle: value });
  }
  for (const [key, value] of Object.entries(CONSERVATIVE_DENY_LIFECYCLES)) {
    lifecycleUsers[`users/${consId(key)}`] = user('student');
    lifecycleProfiles[`studentProfiles/${consId(key)}`] = profile(consId(key), { halaqaId: 'h1', lifecycle: value });
  }

  const h1Roster = [
    'student1',
    'studentOff',
    'studentNoProfile',
    'ghost',
    ...Object.keys(ACTIVE_LIFECYCLES).map(lcId),
    ...Object.keys(ARCHIVED_LIFECYCLES).map(archId),
    ...Object.keys(CONSERVATIVE_DENY_LIFECYCLES).map(consId),
  ];
  const halaqa = (supervisorId, studentIds, teacherId = 'teacher2') => ({
    name: 'H',
    teacherId,
    supervisorId,
    studentIds,
    schedule: [{ day: 0, startTime: '16:00', endTime: '17:00', slotId: 'slot-1' }],
    status: 'active',
  });

  await seedAll({
    'users/admin1': user('admin'),
    'users/adminOff': user('admin', { isActive: false }),
    'users/sup1': user('supervisor'),
    'users/sup2': user('supervisor'),
    'users/supOff': user('supervisor', { isActive: false }),
    'users/teacher1': user('teacher'),
    'users/teacher2': user('teacher'),
    'users/parent1': user('parent'),
    'users/student1': user('student'),
    'users/studentOff': user('student', { isActive: false }),
    'users/studentNoProfile': user('student'),
    'users/student3': user('student'),
    ...lifecycleUsers,

    'studentProfiles/student1': profile('student1', { halaqaId: 'h1' }),
    'studentProfiles/studentOff': profile('studentOff', { halaqaId: 'h1' }),
    'studentProfiles/student3': profile('student3', { halaqaId: 'h2' }),
    // Signed-in uid with roster entry and profile but no users doc.
    'studentProfiles/ghost': profile('ghost', { halaqaId: 'h1' }),
    ...lifecycleProfiles,
    'parentProfiles/parent1': { uid: 'parent1', childrenIds: ['student1'] },

    'halaqat/h1': halaqa('sup1', h1Roster, 'teacher1'),
    'halaqat/h2': halaqa('', ['student3']),
    'halaqat/h3': halaqa('sup1', ['student1']),
    'halaqat/hSupOff': halaqa('supOff', []),
    'halaqat/hTeacherSup': halaqa('teacher1', []),
    'halaqat/hParentSup': halaqa('parent1', []),

    [`${COL}/h1`]: { meetingLink: LINK, updatedAt: new Date(0) },
    [`${COL}/h2`]: { meetingLink: LINK, updatedAt: new Date(0) },
    [`${COL}/hSupOff`]: { meetingLink: LINK, updatedAt: new Date(0) },
    [`${COL}/hTeacherSup`]: { meetingLink: LINK, updatedAt: new Date(0) },
    [`${COL}/hParentSup`]: { meetingLink: LINK, updatedAt: new Date(0) },
    // Canonical doc whose halaqa does not exist.
    [`${COL}/orphan`]: { meetingLink: LINK, updatedAt: new Date(0) },
    // h3 exists but has no canonical doc.
  });
});

const getLink = (db, id) => db.doc(`${COL}/${id}`).get();
const listAll = (db) => db.collection(COL).get();
const listById = (db, id) =>
  db.collection(COL).where(firebase.firestore.FieldPath.documentId(), '==', id).get();
const listByValue = (db) => db.collection(COL).where('meetingLink', '==', LINK).get();

// ── Admin ──────────────────────────────────────────────────────────────────

test('B14 links: active Admin may get any link (including orphans and missing docs) and list', async () => {
  const db = authed('admin1');
  for (const id of ['h1', 'h2', 'hSupOff', 'orphan']) {
    const snap = await allow(`admin get ${id}`, getLink(db, id));
    if (!snap.exists) throw new Error(`admin get ${id}: expected an existing doc`);
  }
  const missing = await allow('admin get h3 (no doc)', getLink(db, 'h3'));
  if (missing.exists) throw new Error('h3 must have no canonical doc');
  const all = await allow('admin list', listAll(db));
  if (all.size !== 6) throw new Error(`admin list: expected 6 docs, got ${all.size}`);
  await allow('admin list by id', listById(db, 'h1'));
  await allow('admin list by value', listByValue(db));
});

test('B14 links: deactivated Admin is denied get and list', async () => {
  const db = authed('adminOff');
  await deny('inactive admin get h1', getLink(db, 'h1'));
  await deny('inactive admin get orphan', getLink(db, 'orphan'));
  await deny('inactive admin list', listAll(db));
});

// ── Supervisors ────────────────────────────────────────────────────────────

test('B14 links: assigned active Supervisor may get only assigned halaqat; list denied', async () => {
  const db = authed('sup1');
  await allow('sup1 get h1 (assigned)', getLink(db, 'h1'));
  const missing = await allow('sup1 get h3 (assigned, no doc)', getLink(db, 'h3'));
  if (missing.exists) throw new Error('h3 must have no canonical doc');
  for (const id of ['h2', 'hSupOff', 'hTeacherSup', 'hParentSup', 'orphan']) {
    await deny(`sup1 get ${id} (not assigned)`, getLink(db, id));
  }
  await deny('sup1 list', listAll(db));
  await deny('sup1 list by id h1', listById(db, 'h1'));
  await deny('sup1 list by value', listByValue(db));
});

test('B14 links: unassigned and deactivated Supervisors are denied', async () => {
  const sup2 = authed('sup2');
  for (const id of ['h1', 'h2', 'h3', 'orphan']) {
    await deny(`sup2 get ${id}`, getLink(sup2, id));
  }
  await deny('sup2 list', listAll(sup2));

  const supOff = authed('supOff');
  await deny('inactive supervisor get own hSupOff', getLink(supOff, 'hSupOff'));
  await deny('inactive supervisor list by id', listById(supOff, 'hSupOff'));
});

test('B14 links: non-supervisor roles named in supervisorId are denied', async () => {
  await deny('teacher named as supervisor', getLink(authed('teacher1'), 'hTeacherSup'));
  await deny('parent named as supervisor', getLink(authed('parent1'), 'hParentSup'));
  await deny('teacher named as supervisor, list by id', listById(authed('teacher1'), 'hTeacherSup'));
});

// ── Teachers, parents, profileless and signed-out ──────────────────────────

test('B14 links: teachers, parents, profileless users and signed-out callers are denied', async () => {
  const callers = {
    'teacher of h1': authed('teacher1'),
    'parent of a student on h1': authed('parent1'),
    'signed-in user without users doc (on roster, has profile)': authed('ghost'),
    'signed-out': unauthed(),
  };
  for (const [label, db] of Object.entries(callers)) {
    for (const id of ['h1', 'h2', 'h3', 'orphan']) {
      await deny(`${label} get ${id}`, getLink(db, id));
    }
    await deny(`${label} list`, listAll(db));
    await deny(`${label} list by id`, listById(db, 'h1'));
  }
});

// ── Students ───────────────────────────────────────────────────────────────

test('B14 links: active roster Student with a profile may get own halaqa link only', async () => {
  const db = authed('student1');
  const own = await allow('student1 get h1', getLink(db, 'h1'));
  if (own.data().meetingLink !== LINK) throw new Error('student1 read the wrong link');
  const missing = await allow('student1 get h3 (on roster, no doc)', getLink(db, 'h3'));
  if (missing.exists) throw new Error('h3 must have no canonical doc');
  await deny('student1 get h2 (not on roster)', getLink(db, 'h2'));
  await deny('student1 get orphan (no halaqa)', getLink(db, 'orphan'));
  await deny('student1 list', listAll(db));
  await deny('student1 list by id h1', listById(db, 'h1'));
  await deny('student1 list by value', listByValue(db));

  await allow('student3 get h2 (own roster)', getLink(authed('student3'), 'h2'));
  await deny('student3 get h1 (not on roster)', getLink(authed('student3'), 'h1'));
});

test('B14 links: missing, padded active, uppercase, unknown, empty and non-string lifecycle values count as active', async () => {
  for (const key of Object.keys(ACTIVE_LIFECYCLES)) {
    const db = authed(lcId(key));
    await allow(`lifecycle ${key}: get h1`, getLink(db, 'h1'));
    await deny(`lifecycle ${key}: get h2`, getLink(db, 'h2'));
    await deny(`lifecycle ${key}: list by id`, listById(db, 'h1'));
  }
});

test('B14 links: archived Students (ASCII- or Unicode-padded archived) are denied', async () => {
  for (const key of Object.keys(ARCHIVED_LIFECYCLES)) {
    const db = authed(archId(key));
    await deny(`archived ${key}: get h1`, getLink(db, 'h1'));
    await deny(`archived ${key}: get h3`, getLink(db, 'h3'));
    await deny(`archived ${key}: list`, listAll(db));
  }
});

test('B14 links: conservative fail-closed — strings containing lowercase archived are denied even when the backend treats them as active', async () => {
  for (const key of Object.keys(CONSERVATIVE_DENY_LIFECYCLES)) {
    const db = authed(consId(key));
    await deny(`conservative ${key}: get h1 (backend: active, rules: deny)`, getLink(db, 'h1'));
    await deny(`conservative ${key}: get h3 (backend: active, rules: deny)`, getLink(db, 'h3'));
    await deny(`conservative ${key}: list`, listAll(db));
    // The roster entry itself is unaffected: an active rostered student reads halaqat/h1.
    await allow(`conservative ${key}: still reads halaqat/h1`, db.doc('halaqat/h1').get());
  }
});

test('B14 links: deactivated and profileless roster Students are denied', async () => {
  await deny('inactive student get h1', getLink(authed('studentOff'), 'h1'));
  await deny('student without studentProfiles doc get h1', getLink(authed('studentNoProfile'), 'h1'));
  await deny('student without studentProfiles doc list by id', listById(authed('studentNoProfile'), 'h1'));
});

// ── Direct writes ──────────────────────────────────────────────────────────

test('B14 links: no client role can create, set, merge, update or delete', async () => {
  const callers = {
    admin1: authed('admin1'),
    adminOff: authed('adminOff'),
    sup1: authed('sup1'),
    sup2: authed('sup2'),
    teacher1: authed('teacher1'),
    parent1: authed('parent1'),
    student1: authed('student1'),
    archived: authed(archId('exact')),
    ghost: authed('ghost'),
    unauthed: unauthed(),
  };
  for (const [label, db] of Object.entries(callers)) {
    await deny(`${label} create h3 (no doc)`, db.doc(`${COL}/h3`).set(linkDoc()));
    await deny(`${label} create new id`, db.doc(`${COL}/brandNew`).set(linkDoc()));
    await deny(`${label} add() auto id`, db.collection(COL).add(linkDoc()));
    await deny(`${label} set h1`, db.doc(`${COL}/h1`).set(linkDoc()));
    await deny(`${label} set h1 merge`, db.doc(`${COL}/h1`).set({ meetingLink: LINK }, { merge: true }));
    await deny(`${label} set h3 merge`, db.doc(`${COL}/h3`).set({ meetingLink: LINK }, { merge: true }));
    await deny(`${label} update h1`, db.doc(`${COL}/h1`).update({ meetingLink: LINK }));
    await deny(`${label} update h1 updatedAt`, db.doc(`${COL}/h1`).update({
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    }));
    await deny(`${label} delete h1`, db.doc(`${COL}/h1`).delete());
    await deny(`${label} delete h3 (no doc)`, db.doc(`${COL}/h3`).delete());
    await deny(`${label} delete orphan`, db.doc(`${COL}/orphan`).delete());
  }

  let remaining;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    remaining = (await ctx.firestore().collection(COL).get()).size;
  });
  if (remaining !== 6) throw new Error(`a client write landed: ${remaining} docs`);
});

// ── Overlapping rules ──────────────────────────────────────────────────────

test('B14 links (J.9): halaqat read access never implies canonical link access', async () => {
  // Assigned teacher and an archived roster student read the halaqa document
  // (it carries no link), yet the canonical link stays closed.
  for (const [label, db] of Object.entries({
    'teacher1 (assigned)': authed('teacher1'),
    'archived roster student': authed(archId('exact')),
  })) {
    await allow(`${label} reads halaqat/h1`, db.doc('halaqat/h1').get());
    await deny(`${label} get ${COL}/h1`, getLink(db, 'h1'));
  }
  // J.10: a linked parent reads neither (getParentChildHalaqat projects it).
  await deny('parent1 (child on roster) reads halaqat/h1', authed('parent1').doc('halaqat/h1').get());
  await deny(`parent1 (child on roster) get ${COL}/h1`, getLink(authed('parent1'), 'h1'));
  // Unassigned, deactivated and profile-less callers read neither.
  for (const [label, db] of Object.entries({
    'sup2 (unassigned)': authed('sup2'),
    'teacher2 (unassigned)': authed('teacher2'),
    'supOff (deactivated)': authed('supOff'),
    'studentOff (deactivated, on roster)': authed('studentOff'),
    'adminOff (deactivated)': authed('adminOff'),
    'ghost (no users doc, on roster)': authed('ghost'),
    'signed-out': unauthed(),
  })) {
    await deny(`${label} reads halaqat/h1`, db.doc('halaqat/h1').get());
    await deny(`${label} get ${COL}/h1`, getLink(db, 'h1'));
  }
  await deny('student3 (not on roster) reads halaqat/h1', authed('student3').doc('halaqat/h1').get());
  await allow('sup1 (assigned) reads halaqat/h1', authed('sup1').doc('halaqat/h1').get());
  await allow('student1 (eligible) reads halaqat/h1', authed('student1').doc('halaqat/h1').get());
});

test('B14 links (J.9): a legacy halaqat.meetingLink is readable only by Admin; the canonical link is unaffected', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('halaqat/h1').update({ meetingLink: LINK });
  });
  for (const uid of ['teacher1', 'parent1', 'sup1', 'student1', archId('exact'), 'sup2', 'ghost']) {
    await deny(`${uid} gets halaqat/h1 carrying a legacy link`, authed(uid).doc('halaqat/h1').get());
  }
  const snap = await allow('admin gets halaqat/h1 carrying a legacy link', authed('admin1').doc('halaqat/h1').get());
  if (snap.data().meetingLink !== LINK) throw new Error('legacy seed missing');
  await allow('sup1 still gets the canonical link', getLink(authed('sup1'), 'h1'));
  await allow('student1 still gets the canonical link', getLink(authed('student1'), 'h1'));
});

test('B14 links (J.9): halaqat list and query attempts follow the role scope', async () => {
  await allow('admin lists halaqat', authed('admin1').collection('halaqat').get());
  for (const uid of ['teacher1', 'sup1', 'sup2', 'parent1', 'student1', 'ghost', 'adminOff']) {
    await deny(`${uid} lists all halaqat`, authed(uid).collection('halaqat').get());
  }
  await allow(
    'teacher1 queries own halaqat',
    authed('teacher1').collection('halaqat').where('teacherId', '==', 'teacher1').get(),
  );
  await deny(
    'teacher1 queries teacher2 halaqat',
    authed('teacher1').collection('halaqat').where('teacherId', '==', 'teacher2').get(),
  );
  await allow(
    'sup1 queries own halaqat',
    authed('sup1').collection('halaqat').where('supervisorId', '==', 'sup1').get(),
  );
  await deny(
    'sup2 queries sup1 halaqat',
    authed('sup2').collection('halaqat').where('supervisorId', '==', 'sup1').get(),
  );
  await allow(
    'student1 queries own roster',
    authed('student1').collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await deny(
    "parent1 queries child's roster (J.10: parents use getParentChildHalaqat)",
    authed('parent1').collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await deny(
    'parent1 queries another roster',
    authed('parent1').collection('halaqat').where('studentIds', 'array-contains', 'student3').get(),
  );
  await deny(
    'ghost queries its roster entry',
    authed('ghost').collection('halaqat').where('studentIds', 'array-contains', 'ghost').get(),
  );
});

test('B14 links: the legacy halaqat.meetingLink mirror is not exposed to unrelated or deactivated callers', async () => {
  await seedAll({
    'users/parent2': { name: 'parent2', role: 'parent', isActive: true },
    'parentProfiles/parent2': { uid: 'parent2', childrenIds: ['student3'] },
    'users/parentOff': { name: 'parentOff', role: 'parent', isActive: false },
    'parentProfiles/parentOff': { uid: 'parentOff', childrenIds: ['student1'] },
    'users/teacherOff': { name: 'teacherOff', role: 'teacher', isActive: false },
  });
  const callers = {
    // Roster entry and profile, but no users doc.
    ghost: authed('ghost'),
    studentOff: authed('studentOff'),
    student3: authed('student3'),
    parent2: authed('parent2'),
    parentOff: authed('parentOff'),
    teacherOff: authed('teacherOff'),
    supOff: authed('supOff'),
    adminOff: authed('adminOff'),
    unauthed: unauthed(),
  };
  for (const [label, db] of Object.entries(callers)) {
    await deny(`${label} reads halaqat/h1`, db.doc('halaqat/h1').get());
    await deny(`${label} lists halaqat`, db.collection('halaqat').get());
    await deny(
      `${label} queries halaqat by student1`,
      db.collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
    );
    await deny(`${label} get ${COL}/h1`, getLink(db, 'h1'));
  }
  await deny('supOff reads own hSupOff', authed('supOff').doc('halaqat/hSupOff').get());

  // Legitimate relationships keep reading the Halaqa document.
  await allow('student1 reads own halaqat/h1', authed('student1').doc('halaqat/h1').get());
  await allow('student3 reads own halaqat/h2', authed('student3').doc('halaqat/h2').get());
  // J.10: parents never read halaqat, even a linked child's; they use
  // getParentChildHalaqat.
  await deny('parent2 reads linked halaqat/h2', authed('parent2').doc('halaqat/h2').get());
  await deny(
    'parent1 queries halaqat by linked child',
    authed('parent1').collection('halaqat').where('studentIds', 'array-contains', 'student1').get(),
  );
  await allow('sup1 queries own halaqat', authed('sup1').collection('halaqat').where('supervisorId', '==', 'sup1').get());
  await allow('admin1 lists halaqat', authed('admin1').collection('halaqat').get());
});

test('B14 links: nested paths and collection-group queries are not opened', async () => {
  await seedAll({ [`${COL}/h1/history/v1`]: { meetingLink: LINK } });
  for (const [label, db] of Object.entries({
    admin1: authed('admin1'),
    sup1: authed('sup1'),
    student1: authed('student1'),
  })) {
    await deny(`${label} get nested doc`, db.doc(`${COL}/h1/history/v1`).get());
    await deny(`${label} write nested doc`, db.doc(`${COL}/h1/history/v2`).set({ meetingLink: LINK }));
    await deny(`${label} collection group`, db.collectionGroup(COL).get());
  }
});

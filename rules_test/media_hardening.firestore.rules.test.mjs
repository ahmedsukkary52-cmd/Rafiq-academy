/**
 * Media hardening — payment-proof metadata on payments/{paymentId}.
 *
 * The current proof pointer, its server-issued `proofCycleId`, the used-name
 * history and `pending_review` are written only by the submitPaymentProof
 * callable after it verified the uploaded object, and review only by
 * reviewPaymentProof. Every direct-submission shape below is denied.
 *
 *   npx firebase emulators:exec --project <demo-project> --only firestore \
 *     "npm --prefix rules_test run test:media"
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

const { FieldValue, Timestamp } = firebase.firestore;

let testEnv;

const authed = (uid) => testEnv.authenticatedContext(uid).firestore();

function submission(paymentId, overrides = {}, parentId = 'parent1') {
  const fileName = '1760000000000.jpg';
  return {
    proofStoragePath: `payment_proofs/${parentId}/${paymentId}/${fileName}`,
    proofDownloadUrl: FieldValue.delete(),
    proofFileName: fileName,
    proofSubmittedBy: parentId,
    proofSubmittedAt: FieldValue.serverTimestamp(),
    method: 'vodafone_cash',
    reviewStatus: 'pending_review',
    ...overrides,
  };
}

const PRIOR_REVIEWED_AT = Timestamp.fromDate(new Date(Date.UTC(2026, 0, 15)));

// Review outcome + confirmed amounts written by reviewPaymentProof.
const PROTECTED_REVIEW_FIELDS = {
  reviewedBy: 'admin1',
  reviewedAt: PRIOR_REVIEWED_AT,
  reviewNotes: 'part',
  amountPaidConfirmed: 60,
  remainingAmount: 40,
};

async function readPayment(id) {
  let d;
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    d = (await ctx.firestore().doc(`payments/${id}`).get()).data();
  });
  return d;
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
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (role) => ({ name: role, role, isActive: true });
    const docs = {
      'users/admin1': user('admin'),
      'users/parent1': user('parent'),
      'users/parent2': user('parent'),
      'users/teacher1': user('teacher'),
      'payments/pay1': {
        parentId: 'parent1',
        studentId: 'student1',
        status: 'unpaid',
        amount: 100,
      },
      'payments/pay2': {
        parentId: 'parent2',
        studentId: 'student2',
        status: 'unpaid',
        amount: 50,
      },
      // Previously rejected, with a legacy URL and old review fields.
      'payments/payRejected': {
        parentId: 'parent1',
        studentId: 'student1',
        status: 'unpaid',
        amount: 100,
        reviewStatus: 'rejected',
        reviewedBy: 'admin1',
        reviewNotes: 'blurry',
        proofStoragePath: 'payment_proofs/parent1/payRejected/old.jpg',
        proofDownloadUrl: 'https://example.test/old.jpg',
      },
      // Partial payment confirmed by the reviewer; still not paid.
      'payments/payPartial': {
        parentId: 'parent1',
        studentId: 'student1',
        status: 'due',
        amount: 100,
        reviewStatus: 'partial',
        proofStoragePath: 'payment_proofs/parent1/payPartial/old.jpg',
        proofFileName: 'old.jpg',
        ...PROTECTED_REVIEW_FIELDS,
      },
      'payments/payPaid': {
        parentId: 'parent1',
        studentId: 'student1',
        status: 'paid',
        amount: 100,
      },
    };
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
  });
});

test('Proof metadata: owner cannot write even a trusted path directly (callable-only)', async () => {
  await assertFails(authed('parent1').doc('payments/pay1').update(submission('pay1')));
  for (const name of ['1.jpeg', 'a_b-1.png', '17.webp']) {
    await assertFails(
      authed('parent1').doc('payments/pay1').update(
        submission('pay1', {
          proofStoragePath: `payment_proofs/parent1/pay1/${name}`,
          proofFileName: name,
        }),
      ),
    );
  }
});

test('Proof metadata: direct resubmission after rejection is denied; record unchanged', async () => {
  await assertFails(
    authed('parent1').doc('payments/payRejected').update(submission('payRejected')),
  );
  const d = await readPayment('payRejected');
  if (d.reviewStatus !== 'rejected' || d.proofStoragePath !== 'payment_proofs/parent1/payRejected/old.jpg') {
    throw new Error('denied resubmission changed the proof pointer / review status');
  }
  if (d.reviewedBy !== 'admin1' || d.reviewNotes !== 'blurry') {
    throw new Error('resubmission erased the previous review outcome');
  }
  if (d.status !== 'unpaid' || d.amount !== 100) {
    throw new Error('resubmission changed status / amount');
  }
});

test('Proof metadata: a legacy download URL must be cleared on resubmission', async () => {
  const { proofDownloadUrl: _omit, ...withoutUrlDelete } = submission('payRejected');
  await assertFails(
    authed('parent1').doc('payments/payRejected').update(withoutUrlDelete),
  );
});

test('Proof metadata: direct resubmission after a partial payment is denied; amounts kept', async () => {
  await assertFails(
    authed('parent1').doc('payments/payPartial').update(submission('payPartial')),
  );
  const d = await readPayment('payPartial');
  if (d.reviewStatus !== 'partial') {
    throw new Error(`expected partial, got ${d.reviewStatus}`);
  }
  if (d.proofStoragePath !== 'payment_proofs/parent1/payPartial/old.jpg') {
    throw new Error('denied resubmission changed the proof pointer');
  }
  for (const [key, value] of Object.entries(PROTECTED_REVIEW_FIELDS)) {
    const same = value instanceof Timestamp ? value.isEqual(d[key]) : d[key] === value;
    if (!same) throw new Error(`resubmission changed protected field ${key}`);
  }
  if (d.status !== 'due' || d.amount !== 100) {
    throw new Error('resubmission changed status / amount');
  }
});

test('Proof metadata: Parent can neither delete nor change review outcome / amounts', async () => {
  const forged = {
    reviewedBy: 'parent1',
    reviewedAt: Timestamp.fromDate(new Date(Date.UTC(2026, 1, 1))),
    reviewNotes: 'forged',
    amountPaidConfirmed: 100,
    remainingAmount: 0,
  };
  for (const key of Object.keys(PROTECTED_REVIEW_FIELDS)) {
    await assertFails(
      authed('parent1').doc('payments/payPartial').update(
        submission('payPartial', { [key]: FieldValue.delete() }),
      ),
    );
    await assertFails(
      authed('parent1').doc('payments/payPartial').update(
        submission('payPartial', { [key]: forged[key] }),
      ),
    );
  }
  for (const key of ['reviewedBy', 'reviewNotes']) {
    await assertFails(
      authed('parent1').doc('payments/payRejected').update(
        submission('payRejected', { [key]: FieldValue.delete() }),
      ),
    );
  }
  const d = await readPayment('payPartial');
  if (d.amountPaidConfirmed !== 60 || d.remainingAmount !== 40 || d.reviewStatus !== 'partial') {
    throw new Error('denied writes still changed the partial payment');
  }
});

test('Proof metadata: wrong parent or wrong payment in the path is denied', async () => {
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', {
        proofStoragePath: 'payment_proofs/parent2/pay1/1760000000000.jpg',
      }),
    ),
  );
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', {
        proofStoragePath: 'payment_proofs/parent1/pay2/1760000000000.jpg',
      }),
    ),
  );
  // Another parent's invoice, even with a path under their own uid.
  await assertFails(
    authed('parent1').doc('payments/pay2').update(submission('pay2')),
  );
  await assertFails(
    authed('parent2').doc('payments/pay1').update(submission('pay1', {}, 'parent2')),
  );
});

test('Proof metadata: arbitrary URLs and malformed paths are denied', async () => {
  const bad = [
    'https://evil.example/proof.jpg',
    'https://firebasestorage.googleapis.com/v0/b/x/o/payment_proofs%2Fparent1%2Fpay1%2F1.jpg?alt=media',
    'gs://bucket/payment_proofs/parent1/pay1/1760000000000.jpg',
    '/payment_proofs/parent1/pay1/1760000000000.jpg',
    'payment_proofs/parent1/pay1',
    'payment_proofs/parent1/pay1/sub/1760000000000.jpg',
    'payment_proofs/parent1/pay1/../pay2/1760000000000.jpg',
    'payment_proofs/parent1/pay1/1760000000000.gif',
    'payment_proofs/parent1/pay1/1760000000000',
    'payment_proofs/parent1/pay1/a b.jpg',
    'posts/parent1/pay1/1760000000000.jpg',
    '',
  ];
  for (const path of bad) {
    await assertFails(
      authed('parent1').doc('payments/pay1').update(
        submission('pay1', {
          proofStoragePath: path,
          proofFileName: path.split('/').pop(),
        }),
      ),
    );
  }
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { proofStoragePath: 42 }),
    ),
  );
});

test('Proof metadata: proofFileName must equal the path object name', async () => {
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { proofFileName: 'other.jpg' }),
    ),
  );
});

test('Proof metadata: download URL fields and unknown fields are rejected', async () => {
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { proofDownloadUrl: 'https://example.test/a.jpg' }),
    ),
  );
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { proofImageUrl: 'https://example.test/a.jpg' }),
    ),
  );
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { note: 'hi' }),
    ),
  );
});

test('Proof metadata: submitter, timestamp and method are pinned', async () => {
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { proofSubmittedBy: 'parent2' }),
    ),
  );
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { proofSubmittedAt: Timestamp.fromDate(new Date(2020, 0, 1)) }),
    ),
  );
  await assertFails(
    authed('parent1').doc('payments/pay1').update(
      submission('pay1', { method: 'cash' }),
    ),
  );
});

test('Proof metadata: uploading a proof never approves or pays', async () => {
  for (const overrides of [
    { reviewStatus: 'approved' },
    { reviewStatus: 'partial' },
    { reviewStatus: FieldValue.delete() },
    { status: 'paid' },
    { paidAt: FieldValue.serverTimestamp() },
    { amount: 1 },
    { reviewedBy: 'parent1' },
    { amountPaidConfirmed: 100 },
    { remainingAmount: 0 },
  ]) {
    await assertFails(
      authed('parent1').doc('payments/pay1').update(submission('pay1', overrides)),
    );
  }
  await assertFails(
    authed('parent1').doc('payments/payPaid').update(submission('payPaid')),
  );
});

test('Proof metadata: non-parent roles cannot write proof fields', async () => {
  for (const uid of ['admin1', 'teacher1']) {
    await assertFails(authed(uid).doc('payments/pay1').update(submission('pay1')));
  }
});

test('Proof cycle: no client sets the cycle, the name history or pending_review', async () => {
  const cycle = 'pc_AAAAAAAAAAAAAAAAAAAAAAAA';
  for (const uid of ['parent1', 'admin1', 'teacher1']) {
    for (const change of [
      { proofCycleId: cycle },
      { proofFileNameHistory: ['old.jpg'] },
      { proofFileNameHistory: FieldValue.delete() },
      { proofObjectGeneration: '1' },
      { reviewStatus: 'pending_review' },
      submission('payPartial', { proofCycleId: cycle }),
    ]) {
      await assertFails(authed(uid).doc('payments/payPartial').update(change));
    }
  }
});

test('Proof cycle: A → B → A and never-uploaded pointers are not client-writable', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('payments/payCycle').set({
      parentId: 'parent1',
      studentId: 'student1',
      status: 'due',
      amount: 100,
      reviewStatus: 'pending_review',
      proofStoragePath: 'payment_proofs/parent1/payCycle/B.jpg',
      proofFileName: 'B.jpg',
      proofCycleId: 'pc_BBBBBBBBBBBBBBBBBBBBBBBB',
      proofFileNameHistory: ['A.jpg', 'B.jpg'],
      amountPaidConfirmed: 60,
      remainingAmount: 40,
    });
  });
  for (const name of ['A.jpg', 'B.jpg', 'never-uploaded.jpg']) {
    await assertFails(
      authed('parent1').doc('payments/payCycle').update(
        submission('payCycle', {
          proofStoragePath: `payment_proofs/parent1/payCycle/${name}`,
          proofFileName: name,
        }),
      ),
    );
  }
  await assertFails(authed('parent1').doc('payments/payCycle').delete());
  const d = await readPayment('payCycle');
  if (d.proofCycleId !== 'pc_BBBBBBBBBBBBBBBBBBBBBBBB' || d.amountPaidConfirmed !== 60) {
    throw new Error('denied writes changed the current cycle / confirmed amount');
  }
});

test('Proof cycle: owner, Admin keep read access; other parents do not', async () => {
  await assertSucceeds(authed('parent1').doc('payments/payPartial').get());
  await assertSucceeds(authed('admin1').doc('payments/payPartial').get());
  await assertFails(authed('parent2').doc('payments/payPartial').get());
});

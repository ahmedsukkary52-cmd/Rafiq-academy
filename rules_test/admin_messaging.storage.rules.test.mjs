/**
 * Admin-managed groups — membership is the only access path.
 *
 * Conversation docs, messages, chat media and the group image all resolve
 * through conversations.participantIds, so removing a member (server-side,
 * adminSetChatGroupMembers) revokes history and files without touching any
 * object. The Storage emulator caches cross-service reads across
 * clearFirestore(), so "before" and "after removal" are two groups with
 * unique ids rather than one document toggled mid-test.
 *
 *   npx firebase emulators:exec --project demo-rafiq-rules \
 *     --only firestore,storage \
 *     "node --test --test-concurrency=1 rules_test/admin_messaging.storage.rules.test.mjs"
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
const read = (name) => readFileSync(join(__dirname, '..', name), 'utf8');

let testEnv;

const storageOf = (uid) => testEnv.authenticatedContext(uid).storage();
const firestoreOf = (uid) => testEnv.authenticatedContext(uid).firestore();

function image(ref, customMetadata) {
  return ref.put(new Uint8Array([0xff, 0xd8, 0xff, 0xd9]), {
    contentType: 'image/jpeg',
    ...(customMetadata ? { customMetadata } : {}),
  });
}

const MEMBER_GROUP = 'group_amMemberGroup0001';
const REMOVED_GROUP = 'group_amRemovedGroup001';
const MSG = 'AmMsgAaaaaaaaaaaa';

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: read('firestore.rules') },
    storage: { rules: read('storage.rules') },
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (role) => ({ name: role, role, isActive: true });
    const group = (participantIds) => ({
      kind: 'custom_group',
      title: 'مجموعة',
      participantIds,
      imagePath: null,
    });
    const docs = {
      'users/amAdmin': user('admin'),
      'users/amTeacher': user('teacher'),
      'users/amParent': user('parent'),
      'users/amOutsider': user('teacher'),
      [`conversations/${MEMBER_GROUP}`]: group(['amAdmin', 'amParent', 'amTeacher']),
      [`conversations/${REMOVED_GROUP}`]: group(['amAdmin', 'amTeacher']),
    };
    for (const id of [MEMBER_GROUP, REMOVED_GROUP]) {
      docs[`conversations/${id}/messages/${MSG}`] = {
        senderId: 'amTeacher',
        type: 'image',
        deleted: false,
        media: { storagePath: `chat_media/${id}/${MSG}/a.jpg` },
      };
    }
    for (const [path, data] of Object.entries(docs)) {
      await db.doc(path).set(data);
    }
    for (const id of [MEMBER_GROUP, REMOVED_GROUP]) {
      await image(ctx.storage().ref(`chat_media/${id}/${MSG}/a.jpg`));
      await image(ctx.storage().ref(`chat_group_images/${id}/cover.jpg`));
    }
  });
});

test('group member reads the group, its messages, media and image', async () => {
  const db = firestoreOf('amParent');
  await assertSucceeds(db.doc(`conversations/${MEMBER_GROUP}`).get());
  await assertSucceeds(db.doc(`conversations/${MEMBER_GROUP}/messages/${MSG}`).get());
  await assertSucceeds(
    storageOf('amParent').ref(`chat_media/${MEMBER_GROUP}/${MSG}/a.jpg`).getDownloadURL(),
  );
  await assertSucceeds(
    storageOf('amParent').ref(`chat_group_images/${MEMBER_GROUP}/cover.jpg`).getDownloadURL(),
  );
});

test('removed member loses the group, history, media and image', async () => {
  const db = firestoreOf('amParent');
  await assertFails(db.doc(`conversations/${REMOVED_GROUP}`).get());
  await assertFails(db.doc(`conversations/${REMOVED_GROUP}/messages/${MSG}`).get());
  await assertFails(
    storageOf('amParent').ref(`chat_media/${REMOVED_GROUP}/${MSG}/a.jpg`).getDownloadURL(),
  );
  await assertFails(
    storageOf('amParent').ref(`chat_group_images/${REMOVED_GROUP}/cover.jpg`).getDownloadURL(),
  );
  await assertFails(
    image(
      storageOf('amParent').ref(`chat_media/${REMOVED_GROUP}/AmMsgBbbbbbbbbbbb/n.jpg`),
      { uploaderId: 'amParent' },
    ),
  );
  // Remaining member is unaffected.
  await assertSucceeds(
    storageOf('amTeacher').ref(`chat_media/${REMOVED_GROUP}/${MSG}/a.jpg`).getDownloadURL(),
  );
});

test('outsiders never read group files; clients never write group docs', async () => {
  await assertFails(
    storageOf('amOutsider').ref(`chat_group_images/${MEMBER_GROUP}/cover.jpg`).getDownloadURL(),
  );
  await assertFails(firestoreOf('amOutsider').doc(`conversations/${MEMBER_GROUP}`).get());
  await assertFails(
    firestoreOf('amAdmin').doc(`conversations/${MEMBER_GROUP}`).update({
      participantIds: ['amAdmin', 'amOutsider'],
    }),
  );
});

test('only Admin uploads a group image, images only, onto an existing group', async () => {
  await assertSucceeds(
    image(storageOf('amAdmin').ref(`chat_group_images/${MEMBER_GROUP}/new.jpg`)),
  );
  await assertFails(
    image(storageOf('amTeacher').ref(`chat_group_images/${MEMBER_GROUP}/t.jpg`)),
  );
  await assertFails(
    storageOf('amAdmin')
      .ref(`chat_group_images/${MEMBER_GROUP}/x.pdf`)
      .put(new Uint8Array([0x25, 0x50, 0x44, 0x46]), { contentType: 'application/pdf' }),
  );
  await assertFails(
    image(storageOf('amAdmin').ref('chat_group_images/group_missing00000001/c.jpg')),
  );
});

test('a newly provisioned Admin cannot upload Admin files before the first-login change', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/amNewAdmin').set({
      name: 'new',
      role: 'admin',
      isActive: true,
      passwordChangeRequired: true,
    });
  });
  await assertFails(
    image(storageOf('amNewAdmin').ref(`chat_group_images/${MEMBER_GROUP}/p.jpg`)),
  );
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/amNewAdmin').update({ passwordChangeRequired: false });
  });
  await assertSucceeds(
    image(storageOf('amNewAdmin').ref(`chat_group_images/${MEMBER_GROUP}/p.jpg`)),
  );
});

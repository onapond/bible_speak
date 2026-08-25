import {readFile} from 'node:fs/promises';
import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = 'demo-bible-speak-rules';
const ownerId = 'review-owner';
const otherId = 'review-other';
let testEnv;

function reviewData(userId, overrides = {}) {
  return {
    userId,
    book: 'John',
    chapter: 3,
    verse: 16,
    stage: 1,
    ...overrides,
  };
}

function reviewRef(context, id) {
  return doc(context.firestore(), 'reviews', id);
}

async function seedReview(id, userId = ownerId) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(reviewRef(context, id), reviewData(userId));
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

test('owner can create, read, update, and delete a review', async () => {
  const owner = testEnv.authenticatedContext(ownerId);
  const ref = reviewRef(owner, 'owner-crud');

  await assertSucceeds(setDoc(ref, reviewData(ownerId)));
  const snapshot = await assertSucceeds(getDoc(ref));
  assert.equal(snapshot.data().userId, ownerId);
  await assertSucceeds(updateDoc(ref, {stage: 2}));
  await assertSucceeds(deleteDoc(ref));
});

test('a user can create only reviews owned by that user', async () => {
  const other = testEnv.authenticatedContext(otherId);

  await assertSucceeds(setDoc(reviewRef(other, 'other-owned'), reviewData(otherId)));
  await assertFails(setDoc(reviewRef(other, 'forged-owner'), reviewData(ownerId)));
});

test('non-owner cannot read, update, or delete an existing review', async () => {
  await seedReview('owner-private');
  const other = testEnv.authenticatedContext(otherId);
  const ref = reviewRef(other, 'owner-private');

  await assertFails(getDoc(ref));
  await assertFails(updateDoc(ref, {stage: 3}));
  await assertFails(deleteDoc(ref));
});

test('review list and count queries must be constrained to the signed-in owner', async () => {
  await seedReview('owner-query');
  await seedReview('other-query', otherId);
  const owner = testEnv.authenticatedContext(ownerId);
  const reviews = collection(owner.firestore(), 'reviews');
  const ownReviews = query(reviews, where('userId', '==', ownerId));
  const otherReviews = query(reviews, where('userId', '==', otherId));

  const snapshot = await assertSucceeds(getDocs(ownReviews));
  assert.equal(snapshot.size, 1);
  const count = await assertSucceeds(getCountFromServer(ownReviews));
  assert.equal(count.data().count, 1);
  await assertFails(getDocs(otherReviews));
  await assertFails(getDocs(reviews));
});

test('owner cannot transfer review ownership', async () => {
  await seedReview('no-transfer');
  const owner = testEnv.authenticatedContext(ownerId);

  await assertFails(updateDoc(reviewRef(owner, 'no-transfer'), {userId: otherId}));
});

test('signed-out clients cannot access reviews', async () => {
  await seedReview('signed-out');
  const guest = testEnv.unauthenticatedContext();

  await assertFails(getDoc(reviewRef(guest, 'signed-out')));
  await assertFails(setDoc(reviewRef(guest, 'guest-create'), reviewData(ownerId)));
});

test('fallback rule cannot bypass protected collection rules', async () => {
  const owner = testEnv.authenticatedContext(ownerId);
  const protectedPaths = [
    ['purchaseClaims', 'claim'],
    ['internalApiUsage', ownerId],
    ['bible', 'John'],
    ['global', 'config'],
  ];

  for (const path of protectedPaths) {
    await assertFails(setDoc(doc(owner.firestore(), ...path), {value: true}));
  }
  await assertFails(setDoc(doc(owner.firestore(), 'users', otherId), {name: 'forged'}));
  await assertSucceeds(setDoc(doc(owner.firestore(), 'progress', 'legacy'), {value: true}));
});

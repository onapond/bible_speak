import {randomBytes} from 'node:crypto';

import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';

const expectedProjectId = 'bible-speak-dev';
const projectId = process.env.FIREBASE_PROJECT_ID;
const apiKey = process.env.FIREBASE_WEB_API_KEY;

if (projectId !== expectedProjectId) {
  throw new Error(`Refusing Auth smoke for project ${projectId || '<unset>'}.`);
}
if (!apiKey) throw new Error('FIREBASE_WEB_API_KEY is required.');

const runId = (process.env.GITHUB_RUN_ID || Date.now().toString()).replace(/[^0-9]/g, '');
const adminApp = initializeApp({
  credential: applicationDefault(),
  projectId,
});
const adminAuth = getAuth(adminApp);
const adminFirestore = getFirestore(adminApp);

async function authRequest(body, operation) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({...body, returnSecureToken: true}),
    },
  );
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${operation} failed (${response.status}): ${data?.error?.message || 'unknown error'}`);
  }
  if (!data.localId || !data.idToken) throw new Error(`${operation} returned an incomplete response.`);
  return {uid: data.localId, idToken: data.idToken};
}

async function firestoreRequest(path, idToken, {method = 'GET', fields, expected = 200} = {}) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    {
      method,
      headers: {
        authorization: `Bearer ${idToken}`,
        ...(fields ? {'content-type': 'application/json'} : {}),
      },
      body: fields ? JSON.stringify({fields}) : undefined,
    },
  );
  if (response.status !== expected) {
    const data = await response.json().catch(() => ({}));
    throw new Error(
      `${method} ${path} expected ${expected}, got ${response.status}: ` +
      `${data?.error?.status || data?.error?.message || 'unknown error'}`,
    );
  }
}

function reviewFields(userId, stage = 1) {
  return {
    userId: {stringValue: userId},
    verseReference: {stringValue: 'John 3:16'},
    book: {stringValue: 'John'},
    chapter: {integerValue: '3'},
    verse: {integerValue: '16'},
    stage: {integerValue: String(stage)},
  };
}

async function runSmoke() {
  const users = [];
  const documentId = `rules_smoke_${runId}`;
  const forgedDocumentId = `${documentId}_forged`;
  const cleanupErrors = [];
  try {
    const password = `${randomBytes(24).toString('base64url')}aA1!`;
    const owner = await authRequest(
      {email: `bible-speak-rules-${runId}@example.invalid`, password},
      'Email/password sign-up',
    );
    users.push(owner.uid);
    const other = await authRequest({}, 'Anonymous sign-up');
    users.push(other.uid);

    await firestoreRequest(`reviews/${documentId}`, owner.idToken, {
      method: 'PATCH',
      fields: reviewFields(owner.uid),
    });
    await firestoreRequest(`reviews/${documentId}`, owner.idToken);
    await firestoreRequest(
      `reviews/${documentId}?updateMask.fieldPaths=stage`,
      owner.idToken,
      {method: 'PATCH', fields: {stage: {integerValue: '2'}}},
    );

    await firestoreRequest(`reviews/${documentId}`, other.idToken, {expected: 403});
    await firestoreRequest(`reviews/${forgedDocumentId}`, other.idToken, {
      method: 'PATCH',
      fields: reviewFields(owner.uid),
      expected: 403,
    });
    await firestoreRequest(
      `reviews/${documentId}?updateMask.fieldPaths=stage`,
      other.idToken,
      {method: 'PATCH', fields: {stage: {integerValue: '3'}}, expected: 403},
    );
    await firestoreRequest(`reviews/${documentId}`, other.idToken, {
      method: 'DELETE',
      expected: 403,
    });
    await firestoreRequest(`reviews/${documentId}`, owner.idToken, {method: 'DELETE'});
  } finally {
    for (const id of [documentId, forgedDocumentId]) {
      try {
        await adminFirestore.doc(`reviews/${id}`).delete();
      } catch (error) {
        cleanupErrors.push(`document ${id}: ${error?.message || 'unknown error'}`);
      }
    }
    for (const uid of users) {
      try {
        await adminAuth.deleteUser(uid);
      } catch (error) {
        cleanupErrors.push(`user ${uid}: ${error?.message || 'unknown error'}`);
      }
    }
    if (cleanupErrors.length) {
      throw new Error(`Development smoke cleanup failed: ${cleanupErrors.join('; ')}`);
    }
  }
}

try {
  await runSmoke();
  console.log(`Development Auth and Firestore rules smoke passed for ${projectId}.`);
} catch (error) {
  console.error(error?.message || 'Development Auth smoke failed.');
  process.exitCode = 1;
}

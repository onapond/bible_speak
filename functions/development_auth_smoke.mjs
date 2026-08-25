import {randomBytes} from 'node:crypto';

const expectedProjectId = 'bible-speak-dev';
const projectId = process.env.FIREBASE_PROJECT_ID;
const apiKey = process.env.FIREBASE_WEB_API_KEY;

if (projectId !== expectedProjectId) {
  throw new Error(`Refusing Auth smoke for project ${projectId || '<unset>'}.`);
}
if (!apiKey) throw new Error('FIREBASE_WEB_API_KEY is required.');

const runId = (process.env.GITHUB_RUN_ID || Date.now().toString()).replace(/[^0-9]/g, '');

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

async function deleteAuthUser(user) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({idToken: user.idToken}),
    },
  );
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(
      `account delete failed (${response.status}): ${data?.error?.message || 'unknown error'}`,
    );
  }
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
  const expectedStatuses = Array.isArray(expected) ? expected : [expected];
  if (!expectedStatuses.includes(response.status)) {
    const data = await response.json().catch(() => ({}));
    const error = new Error(
      `${method} ${path} expected ${expectedStatuses.join(' or ')}, got ${response.status}: ` +
      `${data?.error?.status || data?.error?.message || 'unknown error'}`,
    );
    error.status = response.status;
    throw error;
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
  let owner;
  let ownerDocumentState = 'absent';
  let forgedDocumentState = 'absent';
  let canDeleteOwner = true;
  let primaryError;
  try {
    const password = `${randomBytes(24).toString('base64url')}aA1!`;
    owner = await authRequest(
      {email: `bible-speak-rules-${runId}@example.invalid`, password},
      'Email/password sign-up',
    );
    users.push(owner);
    const other = await authRequest({}, 'Anonymous sign-up');
    users.push(other);

    try {
      await firestoreRequest(`reviews/${documentId}`, owner.idToken, {
        method: 'PATCH',
        fields: reviewFields(owner.uid),
      });
      ownerDocumentState = 'confirmed';
    } catch (error) {
      if (!error?.status || error.status >= 500) ownerDocumentState = 'ambiguous';
      throw error;
    }
    await firestoreRequest(`reviews/${documentId}`, owner.idToken);
    await firestoreRequest(
      `reviews/${documentId}?updateMask.fieldPaths=stage`,
      owner.idToken,
      {method: 'PATCH', fields: {stage: {integerValue: '2'}}},
    );

    await firestoreRequest(`reviews/${documentId}`, other.idToken, {expected: 403});
    try {
      await firestoreRequest(`reviews/${forgedDocumentId}`, other.idToken, {
        method: 'PATCH',
        fields: reviewFields(owner.uid),
        expected: 403,
      });
    } catch (error) {
      if (error?.status >= 200 && error?.status < 300) {
        forgedDocumentState = 'confirmed';
      } else if (!error?.status || error.status >= 500) {
        forgedDocumentState = 'ambiguous';
      }
      throw error;
    }
    await firestoreRequest(
      `reviews/${documentId}?updateMask.fieldPaths=stage`,
      other.idToken,
      {method: 'PATCH', fields: {stage: {integerValue: '3'}}, expected: 403},
    );
    try {
      await firestoreRequest(`reviews/${documentId}`, other.idToken, {
        method: 'DELETE',
        expected: 403,
      });
    } catch (error) {
      if (error?.status >= 200 && error?.status < 300) ownerDocumentState = 'absent';
      throw error;
    }
    await firestoreRequest(`reviews/${documentId}`, owner.idToken, {method: 'DELETE'});
    ownerDocumentState = 'absent';
  } catch (error) {
    primaryError = error;
  } finally {
    const documents = [
      [documentId, ownerDocumentState],
      [forgedDocumentId, forgedDocumentState],
    ];
    for (const [id, state] of documents) {
      if (state === 'absent' || !owner?.idToken) continue;
      try {
        await firestoreRequest(`reviews/${id}`, owner.idToken, {
          method: 'DELETE',
          expected: state === 'ambiguous' ? [200, 404] : 200,
        });
      } catch (error) {
        canDeleteOwner = false;
        cleanupErrors.push(`document ${id}: ${error?.message || 'unknown error'}`);
      }
    }
    for (const user of users) {
      if (user.uid === owner?.uid && !canDeleteOwner) {
        cleanupErrors.push(
          `user ${user.uid}: preserved because document cleanup did not complete`,
        );
        continue;
      }
      try {
        await deleteAuthUser(user);
      } catch (error) {
        cleanupErrors.push(`user ${user.uid}: ${error?.message || 'unknown error'}`);
      }
    }
  }
  if (primaryError && cleanupErrors.length) {
    throw new Error(
      `${primaryError.message}; cleanup also failed: ${cleanupErrors.join('; ')}`,
    );
  }
  if (primaryError) throw primaryError;
  if (cleanupErrors.length) {
    throw new Error(`Development smoke cleanup failed: ${cleanupErrors.join('; ')}`);
  }
}

try {
  await runSmoke();
  console.log(`Development Auth and Firestore rules smoke passed for ${projectId}.`);
} catch (error) {
  console.error(error?.message || 'Development Auth smoke failed.');
  process.exitCode = 1;
}

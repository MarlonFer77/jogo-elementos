import { test } from 'node:test';
import assert from 'node:assert/strict';
import { publicRevision, validateOperation } from '../src/operation.js';

test('production rejects ephemeral or unconfigured persistence', () => {
  assert.doesNotThrow(() => validateOperation({}));
  for (const runtime of [{ RENDER: 'true' }, { NODE_ENV: 'production' }]) {
    assert.throws(() => validateOperation(runtime));
    assert.throws(() => validateOperation({ ...runtime, MATCH_STORE: 'firestore' }));
    assert.doesNotThrow(() => validateOperation({
      ...runtime, MATCH_STORE: 'firestore', FIREBASE_PROJECT_ID: 'test',
    }));
  }
});

test('public revision exposes only a valid abbreviated commit', () => {
  assert.equal(publicRevision({}), 'local');
  assert.equal(publicRevision({ APP_COMMIT: 'invalid/private text' }), 'local');
  assert.equal(publicRevision({ RENDER_GIT_COMMIT: 'a'.repeat(40) }), 'a'.repeat(12));
  assert.equal(publicRevision({ APP_COMMIT: 'b'.repeat(40) }), 'b'.repeat(12));
});

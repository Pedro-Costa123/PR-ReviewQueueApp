const { test } = require('node:test');
const assert = require('node:assert/strict');
const { migrateLocalCallback } = require('../tool/local-callback.cjs');

test('existing P04 env migrates only the callback, preserving secret and line endings', () => {
  for (const eol of ['\n', '\r\n']) {
    const prefix = `SEND_EMAIL_HOOK_SECRET=fictional-test-value${eol}`;
    const suffix = `${eol}OTHER=unchanged${eol}`;
    const migrated = migrateLocalCallback(`${prefix}APP_CALLBACK_URL=http://127.0.0.1:4173/PR-Review-App-Queue/${suffix}`);
    assert.equal(migrated, `${prefix}APP_CALLBACK_URL=http://127.0.0.1:4173/${suffix}`);
    assert.equal(migrateLocalCallback(migrated), migrated);
  }
});
test('migration does not silently replace unrelated callback settings', () => {
  const content = 'APP_CALLBACK_URL=https://other.example.test/\n';
  assert.equal(migrateLocalCallback(content), content);
});

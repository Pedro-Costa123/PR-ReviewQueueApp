const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const script = fs.readFileSync('web/auth_callback.js', 'utf8');
function visit(suffix) {
  let cleaned = null;
  const context = { URL, URLSearchParams, location: { href: `http://127.0.0.1:4173/PR-Review-App-Queue/${suffix}` },
    history: { replaceState: (_a, _b, value) => { cleaned = value; } }, window: {} };
  vm.runInNewContext(script, context);
  return { take: context.window.takeAuthCallback, cleaned };
}
test('callback is removed immediately and read once without redeeming', () => {
  const token = 'a'.repeat(64);
  const page = visit(`#token_hash=${token}&type=email`);
  assert.equal(page.cleaned, '/PR-Review-App-Queue/');
  assert.equal(page.take(), token);
  assert.equal(page.take(), null);
});
test('query tokens and unexpected provider redirects are scrubbed and rejected', () => {
  for (const suffix of ['?token_hash=bad&type=email', '#access_token=bad&refresh_token=bad', '?code=bad', '#error_description=private']) {
    const page = visit(suffix);
    assert.equal(page.cleaned, '/PR-Review-App-Queue/');
    assert.equal(page.take(), 'invalid');
  }
});
test('ordinary hash routing remains intact', () => {
  const page = visit('#/teams/atlas');
  assert.equal(page.cleaned, null);
  assert.equal(page.take(), null);
});

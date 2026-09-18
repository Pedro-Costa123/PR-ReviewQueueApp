const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const script = fs.readFileSync('web/auth_callback.js', 'utf8');
function visit(suffix, base = 'http://127.0.0.1:4173/') {
  let cleaned = null;
  const listeners = {};
  const context = { URL, URLSearchParams, location: { href: `${base}${suffix}` },
    history: { replaceState: (_a, _b, value) => { cleaned = value; } },
    window: { addEventListener: (name, handler) => { listeners[name] = handler; } } };
  vm.runInNewContext(script, context);
  return { take: context.window.takeAuthCallback, get cleaned() { return cleaned; },
    navigate: suffix => {
      context.location.href = base + suffix;
      const results = [];
      for (const name of ['popstate', 'hashchange']) {
        let stopped = false;
        listeners[name]({ newURL: name === 'hashchange' ? base + suffix : undefined,
          stopImmediatePropagation: () => { stopped = true; } });
        if (stopped) context.location.href = base;
        results.push(stopped);
      }
      return results;
    } };
}
test('callback is removed immediately and read once without redeeming', () => {
  const token = 'a'.repeat(64);
  const page = visit(`#token_hash=${token}&type=email`);
  assert.equal(page.cleaned, '/');
  assert.equal(page.take(), token);
  assert.equal(page.take(), null);
});
test('obsolete paths and unexpected origins are scrubbed without accepting or forwarding tokens', () => {
  for (const base of ['http://127.0.0.1:4173/PR-Review-App-Queue/',
    'http://127.0.0.1:4173/index.html', 'http://127.0.0.1:4173/auth/callback',
    'http://localhost:4173/', 'http://127.0.0.1:4174/', 'https://127.0.0.1:4173/',
    'https://reviews.pedro-costa.dev/', 'https://other.example.test/',
    'http://user@127.0.0.1:4173/']) {
    const page = visit(`#token_hash=${'a'.repeat(64)}&type=email`, base);
    assert.equal(page.cleaned, '/'); // Same-origin cleanup, never a token redirect.
    assert.equal(page.take(), 'invalid');
    assert.equal(page.take(), null);
  }
});
test('mixed and duplicate callback parameters cannot be redeemed', () => {
  for (const extra of ['&access_token=bad', '&error=bad', '&type=email', '&token_hash=bad']) {
    const page = visit(`#token_hash=${'a'.repeat(64)}&type=email${extra}`);
    assert.equal(page.cleaned, '/');
    assert.equal(page.take(), 'invalid');
  }
});
test('query tokens and unexpected provider redirects are scrubbed and rejected', () => {
  for (const suffix of ['?token_hash=bad&type=email', '#access_token=bad&refresh_token=bad', '?code=bad', '#error_description=private']) {
    const page = visit(suffix);
    assert.equal(page.cleaned, '/');
    assert.equal(page.take(), 'invalid');
  }
});
test('ordinary hash routing remains intact', () => {
  const page = visit('#/teams/atlas');
  assert.equal(page.cleaned, null);
  assert.equal(page.take(), null);
  assert.deepEqual(page.navigate('#/teams/orbit'), [false, false]);
  assert.equal(page.cleaned, null);
});
test('in-page token navigation is cleaned and rejected before the router sees it', () => {
  const page = visit('');
  assert.deepEqual(page.navigate(`#token_hash=${'a'.repeat(64)}&type=email`), [true, true]);
  assert.equal(page.cleaned, '/');
  assert.equal(page.take(), 'invalid');
});

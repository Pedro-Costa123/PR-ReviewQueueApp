// Run after the root-base build, with node tool/serve.cjs running.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const origin = 'http://127.0.0.1:4173';

test('root entry, bundled resources and narrow frame are served at /', async () => {
  const root = await fetch(`${origin}/`);
  assert.equal(root.status, 200);
  const html = await root.text();
  assert.match(html, /<base href="\/">/);
  assert.ok(html.indexOf('auth_callback.js') >= 0);
  assert.ok(html.indexOf('auth_callback.js') < html.indexOf('flutter_bootstrap.js'));
  for (const file of ['auth_callback.js', 'main.dart.js', 'canvaskit/canvaskit.wasm']) {
    const response = await fetch(`${origin}/${file}`);
    assert.equal(response.status, 200, file);
    await response.body.cancel();
  }
  const narrow = await fetch(`${origin}/__preview/narrow`);
  assert.equal(narrow.status, 200);
  assert.match(await narrow.text(), /src="\/"/);
});

test('old prefix and missing routes return 404 without redirects or SPA rewrites', async () => {
  for (const path of ['/PR-Review-App-Queue', '/PR-Review-App-Queue/',
    '/PR-Review-App-Queue/?code=fictional', '/auth/callback', '/missing.js']) {
    const response = await fetch(origin + path, { redirect: 'manual' });
    assert.equal(response.status, 404, path);
    assert.equal(response.headers.get('location'), null);
  }
});

test('malformed paths and encoded directory traversal cannot escape build/web', async () => {
  assert.equal((await fetch(`${origin}/%ZZ`)).status, 400);
  assert.equal((await fetch(`${origin}/..%2f..%2f.env.local.json`)).status, 403);
});

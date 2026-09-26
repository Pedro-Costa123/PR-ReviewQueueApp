// Read-only Direct Upload preflight. Never creates a project or uploads files.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { inventory } = require('./release-policy.cjs');
const root = path.resolve(__dirname, '../build/web');
const files = [];
function visit(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    assert.ok(!entry.isSymbolicLink(), 'Upload must not contain symlinks');
    const file = path.join(directory, entry.name);
    const relative = path.relative(root, file).replaceAll('\\', '/');
    assert.ok(!/(^|\/)(?:functions|_worker\.js|\.env[^/]*|CNAME|node_modules|\.git|fixtures|tests|backups|exports)$/.test(relative),
      `Unexpected upload content: ${relative}`);
    assert.ok(!/\.(?:sql|dump|map|pem|key|pfx|log)$/i.test(relative), `Private/debug asset forbidden: ${relative}`);
    if (entry.isDirectory()) visit(file);
    else {
      const bytes = fs.statSync(file).size;
      assert.ok(bytes <= 25 * 1024 * 1024, `Asset exceeds 25 MiB: ${relative}`);
      files.push({ file: relative, bytes });
    }
  }
}
visit(root);
assert.ok(files.length > 0 && files.length <= 1000, 'Dashboard upload requires 1-1000 files');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
assert.ok(html.includes('<base href="/">'), 'Build with --base-href /');
assert.ok(html.indexOf('auth_callback.js') >= 0 &&
  html.indexOf('auth_callback.js') < html.indexOf('flutter_bootstrap.js'), 'Callback must run before Flutter');
for (const required of ['main.dart.js', 'auth_callback.js', 'turnstile.js', 'flutter_bootstrap.js', '_headers', '404.html']) {
  assert.ok(files.some(item => item.file === required), `Missing ${required}`);
}
assert.equal(fs.readFileSync(path.join(root, 'auth_callback.js'), 'utf8'),
  fs.readFileSync(path.resolve(__dirname, '../web/auth_callback.js'), 'utf8'), 'Rebuild stale callback asset');
const largest = files.reduce((a, b) => a.bytes >= b.bytes ? a : b);
assert.ok(!files.some(item => /service_worker/i.test(item.file)), 'No service worker asset permitted');
const bootstrap = fs.readFileSync(path.join(root, 'flutter_bootstrap.js'), 'utf8');
assert.ok(bootstrap.trimEnd().endsWith("_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});"), 'Use the reviewed bootstrap without service worker settings');
const headers = fs.readFileSync(path.join(root, '_headers'), 'utf8');
assert.match(headers, /frame-ancestors 'none'/);
assert.match(headers, /Cache-Control: no-store/);
assert.match(headers, /Referrer-Policy: no-referrer/);
assert.ok(!headers.includes('*.supabase.co') && !headers.includes("'unsafe-eval'"));
inventory(root); // Credential-pattern/JWT scan; no matching values are printed.
console.log(JSON.stringify({ method: 'manual dashboard Direct Upload', files: files.length,
  bytes: files.reduce((total, item) => total + item.bytes, 0), largest,
  limits: { files: 1000, perFileBytes: 25 * 1024 * 1024 },
  note: 'Local limits/security policy checks; heuristic secret scan, not hosted verification or approval.' }, null, 2));

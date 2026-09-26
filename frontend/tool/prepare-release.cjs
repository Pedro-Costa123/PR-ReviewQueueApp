// Offline post-build policy. No cloud calls, provider secrets or uploads.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { releaseConfig, headerFile } = require('./release-policy.cjs');
const mode = process.argv[2] || 'disconnected';
assert.ok(['local', 'production', 'production-check', 'disconnected'].includes(mode));
const root = path.resolve(__dirname, '../build/web');
const config = releaseConfig(mode);
fs.writeFileSync(path.join(root, '_headers'), headerFile(config));
// Flutter may emit a deprecated worker even when our bootstrap never registers it.
// Remove only this generated asset within the fixed build directory.
fs.rmSync(path.join(root, 'flutter_service_worker.js'), { force: true });
fs.writeFileSync(path.join(root, '404.html'), '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="referrer" content="no-referrer"><title>Not found</title><p>Page not found. Open the app from its root address.</p></html>\n');
console.log(`Prepared ${mode} artifact with CSP, no-store headers and no service worker.`);

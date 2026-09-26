const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sha256 = value => crypto.createHash('sha256').update(value).digest('hex');
const origin = 'https://pr-review-queue.pages.dev';
function releaseConfig(mode) {
  if (mode === 'production-check') return publicConfig('production', {
    AUTH_MODE: 'production', SUPABASE_URL: 'https://abcdefghijklmnopqrst.supabase.co',
    SUPABASE_PUBLISHABLE_KEY: 'sb_publishable_fictional', TURNSTILE_SITE_KEY: '0xFictionalProductionKey12345',
  });
  return publicConfig(mode, mode === 'disconnected' ? {} : JSON.parse(fs.readFileSync(path.resolve(__dirname, `../.env.${mode}.json`), 'utf8')));
}

function publicConfig(mode, config = {}) {
  assert.ok(['disconnected', 'local', 'production'].includes(mode), 'Unknown release mode');
  if (mode === 'disconnected') {
    assert.equal(Object.keys(config).length, 0);
    return config;
  }
  const allowed = mode === 'production' ? ['AUTH_MODE','SUPABASE_PUBLISHABLE_KEY','SUPABASE_URL','TURNSTILE_SITE_KEY'] : ['AUTH_MODE','SUPABASE_ANON_KEY','SUPABASE_PUBLISHABLE_KEY','SUPABASE_URL'];
  assert.ok(Object.keys(config).every(key => allowed.includes(key)), 'Only public config keys permitted');
  assert.equal(config.AUTH_MODE ?? 'local', mode);
  if (mode === 'production') {
    assert.match(config.SUPABASE_URL, /^https:\/\/[a-z0-9]{20}\.supabase\.co$/);
    assert.match(config.TURNSTILE_SITE_KEY, /^0x[A-Za-z0-9_-]{20,100}$/);
    assert.match(config.SUPABASE_PUBLISHABLE_KEY, /^sb_publishable_[A-Za-z0-9_-]+$/);
  } else assert.equal(config.SUPABASE_URL, 'http://127.0.0.1:54321');
  const key = config.SUPABASE_PUBLISHABLE_KEY || config.SUPABASE_ANON_KEY;
  assert.equal(typeof key, 'string');
  if (!/^sb_publishable_[A-Za-z0-9_-]+$/.test(key)) {
    const parts = key.split('.');
    assert.equal(parts.length, 3, 'Public anon JWT or publishable key required');
    assert.equal(JSON.parse(Buffer.from(parts[1], 'base64url')).role, 'anon', 'Privileged key forbidden');
  }
  return config;
}

function headers(config = {}) {
  const connect = config.SUPABASE_URL ? ` ${config.SUPABASE_URL}` : '';
  return {
    'Content-Security-Policy': `default-src 'none'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'none'; script-src 'self' 'wasm-unsafe-eval' https://challenges.cloudflare.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self'${connect} https://challenges.cloudflare.com; frame-src https://challenges.cloudflare.com; worker-src 'self' blob:; manifest-src 'self'`,
    'Referrer-Policy': 'no-referrer',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
    'Cache-Control': 'no-store',
  };
}
function headerFile(config) {
  return '/*\n' + Object.entries(headers(config)).map(([key, value]) => `  ${key}: ${value}`).join('\n') + '\n';
}

// Deliberately report paths/rule names only, never matching credential values.
function scan(bytes, file) {
  const text = bytes.toString('utf8');
  for (const [name, expression] of Object.entries({
    privateKey: /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
    providerSecret: /\b(?:sb_secret_[A-Za-z0-9_-]{12,}|re_[A-Za-z0-9]{20,}|whsec_[A-Za-z0-9+/=]{20,}|sbp_[a-f0-9]{30,})/,
    databaseCredential: /postgres(?:ql)?:\/\/[^\s:/]+:[^\s@]+@(?!127\.0\.0\.1|localhost)/,
  })) assert.ok(!expression.test(text), `Credential pattern ${name}: ${file}`);
  for (const jwt of text.matchAll(/eyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+/g)) {
    let payload;
    try { payload = JSON.parse(Buffer.from(jwt[1], 'base64url')); } catch { continue; }
    assert.ok(payload.role === 'anon' && !payload.sub, `Non-public JWT: ${file}`);
  }
}
function inventory(root) {
  const result = [];
  function visit(dir) {
    for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
      assert.ok(!item.isSymbolicLink(), 'Symlink forbidden');
      const file = path.join(dir, item.name);
      const relative = path.relative(root, file).replaceAll('\\', '/');
      if (item.isDirectory()) visit(file);
      else {
        const bytes = fs.readFileSync(file);
        scan(bytes, relative);
        result.push({ file: relative, bytes: bytes.length, sha256: sha256(bytes) });
      }
    }
  }
  visit(root);
  return result.sort((a, b) => a.file.localeCompare(b.file, 'en'));
}
module.exports = { origin, releaseConfig, publicConfig, headers, headerFile, scan, inventory, sha256 };

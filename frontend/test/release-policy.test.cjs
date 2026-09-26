const {test} = require('node:test');
const assert = require('node:assert/strict');
const {publicConfig, headers, scan} = require('../tool/release-policy.cjs');
const config = {AUTH_MODE:'production',SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',SUPABASE_PUBLISHABLE_KEY:'sb_publishable_fictional',TURNSTILE_SITE_KEY:'0xFictionalProductionKey12345'};
test('release configuration rejects secret fields, admin JWTs, preview APIs and dummy CAPTCHA', () => {
  assert.deepEqual(publicConfig('production',config),config);
  for (const bad of [{...config,SERVICE_ROLE_KEY:'forbidden'},{...config,SUPABASE_URL:'http://127.0.0.1:54321'},{...config,TURNSTILE_SITE_KEY:'1x00000000000000000000AA'},{...config,AUTH_MODE:'hosted-trial'}]) assert.throws(()=>publicConfig('production',bad));
  const jwt = 'eyJhbGciOiJIUzI1NiJ9.' + Buffer.from(JSON.stringify({role:'service_role'})).toString('base64url') + '.fictionalSignature';
  assert.throws(()=>publicConfig('local',{SUPABASE_URL:'http://127.0.0.1:54321',SUPABASE_ANON_KEY:jwt}));
  assert.throws(()=>scan(Buffer.from(jwt),'fixture'));
});
test('CSP permits only configured API and Turnstile, blocks framing and script eval', () => {
  const policy = headers(config)['Content-Security-Policy'];
  assert.ok(policy.includes(config.SUPABASE_URL));
  assert.ok(!policy.includes('*.supabase.co') && !policy.includes("'unsafe-eval'"));
  assert.ok(policy.includes("frame-ancestors 'none'") && policy.includes("script-src 'self' 'wasm-unsafe-eval' https://challenges.cloudflare.com"));
  assert.ok(!headers()['Content-Security-Policy'].includes('.supabase.co'));
  assert.equal(headers()['Cache-Control'],'no-store');
});

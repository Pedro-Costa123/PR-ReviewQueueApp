// Local operator convenience after npm test. Never imported by the application.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { localStack, scalar } = require('../tests/local.cjs');
(async () => {
  const stack = localStack();
  const email = 'p04-preview@example.test';
  const existing = scalar(`select id from auth.users where email='${email}'`);
  if (!existing) {
    const response = await fetch(`${stack.API_URL}/auth/v1/admin/users`, {
      method: 'POST', headers: { apikey: stack.SERVICE_ROLE_KEY, Authorization: `Bearer ${stack.SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, email_confirm: false }),
    });
    assert.equal(response.status, 200, 'Local provisioning must succeed');
  }
  scalar(`insert into public.team_invites(team_id,email,role,inviter_id,expires_at,provisioning_state)
    values ('20000000-0000-4000-8000-000000000001','${email}','member','10000000-0000-4000-8000-000000000001',now()+interval '7 days','provisioned')
    on conflict (team_id,email) where claimed_at is null and revoked_at is null do update set expires_at=excluded.expires_at, provisioning_state='provisioned'`);
  fs.writeFileSync(path.resolve(__dirname, '../../frontend/.env.local.json'), JSON.stringify({
    SUPABASE_URL: stack.API_URL, SUPABASE_ANON_KEY: stack.ANON_KEY,
  }, null, 2) + '\n');
  console.log('Local preview configured for p04-preview@example.test; keys omitted. Build frontend with --dart-define-from-file=.env.local.json');
})().catch(() => { console.error('Local preview setup failed. Start/reset the local stack and run the P03 tests first.'); process.exitCode = 1; });

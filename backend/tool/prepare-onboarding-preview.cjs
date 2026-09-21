// Fictional local QA only. No application imports and no hosted override.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { localStack, scalar } = require('../tests/local.cjs');
(async () => {
  const stack = localStack();
  const email = 'p06-preview@example.test';
  let id = scalar(`select id from auth.users where email='${email}'`);
  if (!id) {
    const response = await fetch(`${stack.API_URL}/auth/v1/admin/users`, {
      method: 'POST', headers: { apikey: stack.SERVICE_ROLE_KEY, Authorization: `Bearer ${stack.SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, email_confirm: false }),
    });
    assert.equal(response.status, 200); id = (await response.json()).id;
  }
  // Test fixture admins authorize two exact-email invites. The browser must
  // still verify its provider email and claim them through the real P06 RPC.
  for (const [team, admin, role] of [
    ['20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','admin'],
    ['20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003','member'],
  ]) {
    if (scalar(`select count(*) from public.team_memberships where team_id='${team}' and user_id='${id}'`) !== '0') continue;
    const invite = scalar(`begin; set local role authenticated;
      set local request.jwt.claims='{"sub":"${admin}","role":"authenticated"}';
      select public.prepare_invite('${team}','${email}','${role}'); commit;`);
    scalar(`select public.reconcile_invite('${invite}','${admin}',true,false)`);
  }
  fs.writeFileSync(path.resolve(__dirname, '../../frontend/.env.local.json'), JSON.stringify({
    SUPABASE_URL: stack.API_URL, SUPABASE_ANON_KEY: stack.ANON_KEY,
  }, null, 2) + '\n');
  console.log('Local onboarding preview: p06-preview@example.test, Atlas admin and Orbit member invitations. Request the captured sign-in link in the browser. No keys printed.');
})().catch(() => { console.error('Preview preparation failed. Run the clean local P03 tests first.'); process.exitCode = 1; });

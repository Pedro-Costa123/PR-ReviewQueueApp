// Operator-only P05 provisioning. No password, pre-confirmation, mail or team access.
// Uses the CLI's existing credential store; never prints or writes API keys.
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

async function main() {
  const project = process.env.TRIAL_PROJECT_REF ?? '';
  const email = (process.env.TRIAL_EMAIL ?? '').trim().toLowerCase();
  if (!/^[a-z0-9]{20}$/.test(project) || email.length > 254
      || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.endsWith('.test')) {
    throw new Error('Set TRIAL_PROJECT_REF and one controlled TRIAL_EMAIL through operator configuration');
  }
  const config = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../frontend/.env.hosted-trial.json'), 'utf8'));
  if (config.AUTH_MODE !== 'hosted-trial' || config.SUPABASE_URL !== `https://${project}.supabase.co`) {
    throw new Error('Project must match the local hosted-trial configuration');
  }
  let keys;
  try {
    const output = execFileSync(process.execPath, [path.resolve(__dirname, '../node_modules/supabase/dist/supabase.js'),
      'projects', 'api-keys', '--project-ref', project, '--output', 'json', '--agent', 'no', '--output-format', 'text'],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 15000 });
    keys = JSON.parse(output);
  } catch { throw new Error('CLI credentials unavailable; complete supabase login in your own terminal'); }
  const key = keys.find(item => item.name === 'service_role' && !item.disabled)?.api_key;
  if (!key) throw new Error('Project service credential unavailable');
  const response = await fetch(config.SUPABASE_URL + '/auth/v1/admin/users', {
    method: 'POST', headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, email_confirm: false }), signal: AbortSignal.timeout(10000), redirect: 'error',
  });
  if (!response.ok) throw new Error(`Provisioning not confirmed (HTTP ${response.status}); inspect Auth before retrying`);
  const user = await response.json();
  if (!/^[a-f0-9-]{36}$/.test(user.id) || user.email_confirmed_at || user.email?.toLowerCase() !== email) {
    throw new Error('Unexpected identity result; inspect Auth before continuing');
  }
  console.log(`Unconfirmed trial identity created: ${user.id}`);
}
main().catch(error => {
  // Known operator errors only; never dump child-process output or API payloads.
  console.error(error instanceof Error && /^(Set TRIAL_|Project |CLI credentials|Provisioning not|Unexpected identity)/.test(error.message)
    ? error.message : 'Provisioning outcome unknown; inspect Auth before retrying');
  process.exitCode = 1;
});

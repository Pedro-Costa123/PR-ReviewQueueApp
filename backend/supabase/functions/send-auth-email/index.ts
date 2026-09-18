import { createHandler } from './handler.ts';

const api = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const callback = Deno.env.get('APP_CALLBACK_URL')!;
const secret = Deno.env.get('SEND_EMAIL_HOOK_SECRET')!;
// P04 entrypoint is deliberately local-only. P05 adds the reviewed real sender.
// This cannot silently send login material to an arbitrary configured host.
if (api !== 'http://kong:8000' || callback !== 'http://127.0.0.1:4173/'
  || Deno.env.get('DENO_DEPLOYMENT_ID')) throw new Error('P04 requires local Supabase');

Deno.serve(createHandler({
  secret, callback,
  async rpc(name, args) {
    const response = await fetch(`${api}/rest/v1/rpc/${name}`, {
      method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args), signal: AbortSignal.timeout(2000), redirect: 'error',
    });
    if (!response.ok) { console.warn('Email database operation failed', response.status); throw new Error('reservation unavailable'); }
    return response.status === 204 ? null : response.json();
  },
  async send({ to, link, id }) {
    if (!to.endsWith('@example.test')) throw new Error('fictional recipients only');
    const response = await fetch('http://inbucket:8025/api/v1/send', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ From: { Email: 'signin@example.test', Name: 'PR Review Queue' },
        To: [{ Email: to }], Subject: 'Your local sign-in link',
        Text: `Open this link and choose Continue sign-in. It expires in 15 minutes and works once.\n\n${link}\n\nIf you did not request this, ignore it.`,
        Headers: { 'X-Auth-Event': id },
      }), signal: AbortSignal.timeout(2000), redirect: 'error',
    });
    if (!response.ok) { console.warn('Local inbox rejected message', response.status); throw new Error('local inbox unavailable'); }
  },
}));

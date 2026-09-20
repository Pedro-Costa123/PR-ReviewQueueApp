import { createHandler } from './handler.ts';
import { emailConfig } from './config.ts';
import { localSender, resendSender } from './senders.ts';

const config = emailConfig(name => Deno.env.get(name));
const { api, serviceKey, callback, secret } = config;

Deno.serve(createHandler({
  secret, callback,
  allowedRecipients: config.mode === 'hosted-trial' ? config.recipients : undefined,
  async rpc(name, args) {
    const response = await fetch(`${api}/rest/v1/rpc/${name}`, {
      method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(args), signal: AbortSignal.timeout(750), redirect: 'error',
    });
    if (!response.ok) { console.warn('Email database operation failed', response.status); throw new Error('reservation unavailable'); }
    return response.status === 204 ? null : response.json();
  },
  send: config.mode === 'local' ? localSender() : resendSender(config.resendKey, config.from),
}));

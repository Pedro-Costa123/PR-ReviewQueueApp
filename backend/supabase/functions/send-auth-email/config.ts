export const localCallback = 'http://127.0.0.1:4173/';
type Env = (name: string) => string | undefined;

// Hosted trial is deliberately distinct from the eventual production rollout.
// No local Mailpit adapter can run in a deployed function.
export function emailConfig(env: Env) {
  const mode = env('AUTH_EMAIL_MODE') ?? 'local';
  const api = env('SUPABASE_URL') ?? '';
  const callback = env('APP_CALLBACK_URL') ?? '';
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const secret = env('SEND_EMAIL_HOOK_SECRET') ?? '';
  if (!serviceKey || !secret || callback !== localCallback) throw new Error('Invalid email configuration');
  if (mode === 'local') {
    if (api !== 'http://kong:8000' || env('DENO_DEPLOYMENT_ID')) throw new Error('Local email requires local Supabase');
    return { mode, api, callback, serviceKey, secret, recipients: [] as string[], from: '', resendKey: '' };
  }
  if (mode !== 'hosted-trial' || !/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(api)
    || !env('DENO_DEPLOYMENT_ID')) throw new Error('Invalid hosted trial configuration');
  const recipients = (env('TRIAL_RECIPIENTS') ?? '').split(',').map(value => value.trim().toLowerCase());
  const from = env('AUTH_EMAIL_FROM') ?? '';
  const resendKey = env('RESEND_API_KEY') ?? '';
  const address = /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+$/i;
  if (recipients.length > 3 || new Set(recipients).size !== recipients.length
    || recipients.some(value => !address.test(value) || value.endsWith('.test'))
    || !address.test(from) || from.endsWith('.test') || !/^re_[A-Za-z0-9_-]+$/.test(resendKey)) {
    throw new Error('Hosted trial requires sender, key and one to three controlled recipients');
  }
  return { mode, api, callback, serviceKey, secret, recipients, from, resendKey };
}

export const localCallback = 'http://127.0.0.1:4173/';
export const productionCallback = 'https://pr-review-queue.pages.dev/';
type Env = (name: string) => string | undefined;

// Local preparation only. Hosted activation belongs to the reviewed P13 rollout.
// P12 must remove the temporary database trial-admission route before activation.
// No local Mailpit adapter can run in a deployed function.
export function emailConfig(env: Env) {
  const mode = env('AUTH_EMAIL_MODE') ?? 'local';
  const api = env('SUPABASE_URL') ?? '';
  const callback = env('APP_CALLBACK_URL') ?? '';
  const serviceKey = env('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const secret = env('SEND_EMAIL_HOOK_SECRET') ?? '';
  const expectedCallback = mode === 'production' ? productionCallback : localCallback;
  if (!serviceKey || !secret || callback !== expectedCallback) throw new Error('Invalid email configuration');
  if (mode === 'local') {
    if (api !== 'http://kong:8000' || env('DENO_DEPLOYMENT_ID')) throw new Error('Local email requires local Supabase');
    return { mode, api, callback, serviceKey, secret, recipients: [] as string[], from: '', resendKey: '' };
  }
  if (!['hosted-trial', 'production'].includes(mode) || !/^https:\/\/[a-z0-9]{20}\.supabase\.co$/.test(api)
    || !env('DENO_DEPLOYMENT_ID')) throw new Error('Invalid hosted configuration');
  const recipients = (env('TRIAL_RECIPIENTS') ?? '').split(',').map(value => value.trim().toLowerCase());
  const from = env('AUTH_EMAIL_FROM') ?? '';
  const resendKey = env('RESEND_API_KEY') ?? '';
  const address = /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+$/i;
  if (mode === 'production') {
    if (env('TRIAL_RECIPIENTS') || !address.test(from)
      || !from.endsWith('@auth.pedro-costa.dev') || !/^re_[A-Za-z0-9_-]+$/.test(resendKey)) {
      throw new Error('Production requires the existing verified sender and no trial configuration');
    }
    return { mode, api, callback, serviceKey, secret, recipients: [] as string[], from, resendKey };
  }
  if (recipients.length > 3 || new Set(recipients).size !== recipients.length
    || recipients.some(value => !address.test(value) || value.endsWith('.test'))
    || !address.test(from) || from.endsWith('.test') || !/^re_[A-Za-z0-9_-]+$/.test(resendKey)) {
    throw new Error('Hosted trial requires sender, key and one to three controlled recipients');
  }
  return { mode, api, callback, serviceKey, secret, recipients, from, resendKey };
}

import { inviteHandler } from './handler.ts';
import { emailConfig } from '../send-auth-email/config.ts';

// Reuse the existing fail-closed local/trial boundary. Production is still P12/13.
const config = emailConfig(name => Deno.env.get(name));
const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
if (!anonKey) throw new Error('Public API key required');
Deno.serve(inviteHandler({ api: config.api, anonKey, serviceKey: config.serviceKey,
  origin: new URL(config.callback).origin,
  recipients: config.mode === 'hosted-trial' ? config.recipients : undefined }));

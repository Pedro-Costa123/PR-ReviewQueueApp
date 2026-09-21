type Options = { api: string; anonKey: string; serviceKey: string; origin: string;
  recipients?: string[]; fetcher?: typeof fetch };

// Provisioning sends no email. The browser subsequently uses ordinary Auth
// OTP/confirmation resend, preserving CAPTCHA and the signed budget hook.
export function inviteHandler(options: Options) {
  const fetcher = options.fetcher ?? fetch;
  const headers = { 'Access-Control-Allow-Origin': options.origin,
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Vary': 'Origin',
    'Content-Type': 'application/json', 'Cache-Control': 'no-store' };
  const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers });
  async function call(path: string, key: string, bearer: string, body?: unknown) {
    const result = await fetcher(`${options.api}${path}`, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { apikey: key, Authorization: bearer, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
      redirect: 'error', signal: AbortSignal.timeout(5000),
    });
    if (!result.ok) throw new Error('operation unavailable');
    return result.status === 204 ? null : result.json();
  }
  return async (request: Request): Promise<Response> => {
    if (request.headers.has('origin') && request.headers.get('origin') !== options.origin) return reply(403, { error: 'Origin unavailable' });
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
    if (request.method !== 'POST') return reply(405, { error: 'POST required' });
    const bearer = request.headers.get('authorization') ?? '';
    if (!/^Bearer [^\s]+$/.test(bearer)) return reply(401, { error: 'Sign in required' });
    let actor: string;
    try {
      const user = await call('/auth/v1/user', options.anonKey, bearer);
      if (!user.id || !user.email_confirmed_at) return reply(401, { error: 'Verified sign-in required' });
      actor = user.id;
    } catch { return reply(401, { error: 'Sign in required' }); }
    let input;
    try {
      // Bound streaming input too; Content-Length is not trusted.
      const reader = request.body?.getReader();
      if (!reader) return reply(400, { error: 'Invalid invitation' });
      let text = ''; let size = 0; const decoder = new TextDecoder();
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.length;
        if (size > 2048) { await reader.cancel(); return reply(413, { error: 'Request too large' }); }
        text += decoder.decode(value, { stream: true });
      }
      input = JSON.parse(text + decoder.decode());
      if (!input || Object.keys(input).some(key => !['team_id','email','role'].includes(key))
        || typeof input.team_id !== 'string' || !/^[a-f0-9-]{36}$/i.test(input.team_id)
        || typeof input.email !== 'string' || input.email.length > 254
        || !['member','admin'].includes(input.role)) return reply(400, { error: 'Invalid invitation' });
      input.email = input.email.trim().toLowerCase();
      if (options.recipients && !options.recipients.includes(input.email)) return reply(403, { error: 'Recipient unavailable in this trial' });
    } catch { return reply(400, { error: 'Invalid invitation' }); }
    let invitation: string;
    const serviceBearer = `Bearer ${options.serviceKey}`;
    const reconcile = (finish: boolean, failed = false) => call('/rest/v1/rpc/reconcile_invite', options.serviceKey, serviceBearer,
      { p_invite_id: invitation, p_actor: actor, p_finish: finish, p_failed: failed });
    try {
      invitation = await call('/rest/v1/rpc/prepare_invite', options.anonKey, bearer,
        { p_team_id: input.team_id, p_email: input.email, p_role: input.role });
      const context = await reconcile(false);
      if (!context.exists) {
        try {
          await call('/auth/v1/admin/users', options.serviceKey, serviceBearer,
            { email: context.email, email_confirm: false });
        } catch {
          // A concurrent creator or lost response may already have succeeded.
          // Query the exact invitation-bound identity again, never list users.
          const recovered = await reconcile(true, true);
          if (!recovered.exists) return reply(503, { error: 'Invitation saved. Retry provisioning.' });
        }
      }
      const result = await reconcile(true);
      return reply(200, { id: invitation, email: result.email, state: 'provisioned' });
    } catch { return reply(409, { error: 'Invitation unavailable. Refresh the team and retry; ask an admin if access changed.' }); }
  };
}

type Payload = { user: { id: string; email: string }; email_data: {
  email_action_type: string; token_hash: string; redirect_to: string;
} };
export type Dependencies = {
  secret: string;
  callback: string;
  allowedRecipients?: string[];
  rpc: (name: string, args: Record<string, unknown>) => Promise<any>;
  send: (message: { to: string; link: string; id: string }) => Promise<void>;
};
const encoder = new TextEncoder();
const failure = (status: number) => Response.json(
  { error: { http_code: status, message: 'Email request unavailable' } }, { status });

// Standard Webhooks v1: verify the unmodified raw body, ID and timestamp.
export async function verifySignature(raw: string, headers: Headers, secret: string) {
  const id = headers.get('webhook-id') ?? '';
  const timestamp = headers.get('webhook-timestamp') ?? '';
  if (!/^[a-zA-Z0-9_-]{1,200}$/.test(id) || !/^\d{10}$/.test(timestamp)
    || Math.abs(Date.now() / 1000 - Number(timestamp)) > 300) throw new Error('signature');
  const bytes = Uint8Array.from(atob(secret.replace(/^v1,whsec_/, '').replace(/^whsec_/, '')), c => c.charCodeAt(0));
  if (bytes.length < 24) throw new Error('secret');
  const key = await crypto.subtle.importKey('raw', bytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
  for (const signature of (headers.get('webhook-signature') ?? '').split(' ')) {
    if (!signature.startsWith('v1,')) continue;
    try {
      const sig = Uint8Array.from(atob(signature.slice(3)), c => c.charCodeAt(0));
      if (await crypto.subtle.verify('HMAC', key, sig, encoder.encode(`${id}.${timestamp}.${raw}`))) return id;
    } catch { /* malformed signatures fail closed */ }
  }
  throw new Error('signature');
}

export function createHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') return failure(405);
    // Bound allocation, including requests without Content-Length.
    const reader = request.body?.getReader();
    if (!reader) return failure(400);
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 32768) { await reader.cancel(); return failure(413); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    let raw: string;
    try { raw = new TextDecoder('utf-8', { fatal: true }).decode(bytes); }
    catch { return failure(400); }
    let id: string;
    try { id = await verifySignature(raw, request.headers, deps.secret); }
    catch { return failure(401); }
    let payload: Payload;
    try {
      payload = JSON.parse(raw);
      const { user, email_data: data } = payload;
      if (!/^[0-9a-f-]{36}$/i.test(user.id) || typeof user.email !== 'string'
        || user.email.length > 254 || !/^[^\s@]+@[^\s@]+$/.test(user.email)
        || !['signup', 'magiclink'].includes(data.email_action_type)
        || !/^[a-zA-Z0-9_-]{32,256}$/.test(data.token_hash)
        || data.redirect_to !== deps.callback) return failure(400);
    } catch { return failure(400); }
    if (deps.allowedRecipients && !deps.allowedRecipients.includes(payload.user.email.trim().toLowerCase())) return failure(403);
    const digest = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)),
      b => b.toString(16).padStart(2, '0')).join('');
    let state: string;
    try {
      ({ state } = await deps.rpc('reserve_auth_email', {
        p_event_id: id, p_digest: digest, p_user_id: payload.user.id,
        p_email: payload.user.email, p_action: payload.email_data.email_action_type,
      }));
    } catch { return failure(403); }
    if (state === 'sent') return Response.json({});
    if (state !== 'new') return failure(503);
    // A fragment avoids sending the one-time secret to the static host. The
    // entry script removes it immediately; only a user action redeems it.
    const link = `${deps.callback}#token_hash=${encodeURIComponent(payload.email_data.token_hash)}&type=email`;
    let outcome = 'sent';
    try { await deps.send({ to: payload.user.email, link, id }); }
    catch { outcome = 'unknown'; }
    try { await deps.rpc('finish_auth_email', { p_event_id: id, p_digest: digest, p_outcome: outcome }); }
    catch { return failure(503); }
    return outcome === 'sent' ? Response.json({}) : failure(503);
  };
}

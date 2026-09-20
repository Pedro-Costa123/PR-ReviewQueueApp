type Message = { to: string; link: string; id: string };
type Fetch = typeof fetch;
const text = (link: string) => `Open this link and choose Continue sign-in. It expires in 15 minutes and works once.\n\n${link}\n\nIf you did not request this, ignore this email.`;

export function localSender(fetcher: Fetch = fetch) {
  return async ({ to, link, id }: Message) => {
    if (!to.endsWith('@example.test')) throw new Error('Fictional recipients only');
    const response = await fetcher('http://inbucket:8025/api/v1/send', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ From: { Email: 'signin@example.test', Name: 'PR Review Queue' },
        To: [{ Email: to }], Subject: 'Your local sign-in link', Text: text(link), Headers: { 'X-Auth-Event': id } }),
      signal: AbortSignal.timeout(2000), redirect: 'error',
    });
    if (!response.ok) throw new Error('Local inbox unavailable');
    await response.body?.cancel();
  };
}

export function resendSender(key: string, from: string, fetcher: Fetch = fetch) {
  return async ({ to, link, id }: Message) => {
    // Provider idempotency complements permanent database duplicate protection.
    // One bounded attempt: ambiguous outcomes stay counted and are not retried.
    const response = await fetcher('https://api.resend.com/emails', {
      method: 'POST', headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json', 'Idempotency-Key': id },
      body: JSON.stringify({ from: `PR Review Queue <${from}>`, to: [to],
        subject: 'Your PR Review Queue sign-in link', text: text(link) }),
      signal: AbortSignal.timeout(2500), redirect: 'error',
    });
    if (!response.ok) { await response.body?.cancel(); throw new Error('Email provider unavailable'); }
    const result = await response.json();
    if (typeof result?.id !== 'string' || !result.id) throw new Error('Email outcome unknown');
    // Never log recipient, link, key, or provider response body.
  };
}

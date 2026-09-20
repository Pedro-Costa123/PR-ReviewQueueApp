// Loaded after callback cleanup. No external request until the user asks for a
// link. Supabase Auth, not this browser bridge, validates the resulting token.
(() => {
  let loading = null;
  let active = null;
  function load() {
    if (window.turnstile) return Promise.resolve(window.turnstile);
    if (loading) return loading;
    loading = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      let settled = false;
      const finish = ok => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        if (ok && window.turnstile) resolve(window.turnstile);
        else { script.remove(); loading = null; reject(new Error('Verification unavailable')); }
      };
      const timer = setTimeout(() => finish(false), 15000);
      // ready() rejects async script loading. Use the provider's explicit load callback.
      window.prQueueTurnstileLoaded = () => finish(true);
      script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=prQueueTurnstileLoaded';
      script.async = true;
      script.onerror = () => finish(false);
      document.head.append(script);
    });
    return loading;
  }
  window.prQueueChallenge = {
    cancel() { active?.cancel(); },
    request(sitekey, theme) {
      if (active) return Promise.reject(new Error('Verification already running'));
      return new Promise((resolve, reject) => {
        const previousFocus = document.activeElement;
        const dialog = document.createElement('dialog');
        dialog.setAttribute('aria-labelledby', 'verification-title');
        dialog.style.cssText = `box-sizing:border-box;width:min(360px,calc(100vw - 24px));padding:20px;border:1px solid #61736c;border-radius:16px;font:16px/1.5 system-ui;color:${theme === 'dark' ? '#edf4f1' : '#172322'};background:${theme === 'dark' ? '#192123' : '#ffffff'}`;
        const title = document.createElement('h2');
        title.id = 'verification-title'; title.textContent = 'Verify your request';
        title.style.cssText = 'font-size:20px;margin:0 0 12px';
        const help = document.createElement('p');
        help.textContent = 'Complete this check to request your sign-in link.';
        const container = document.createElement('div');
        container.style.minHeight = '65px';
        const cancel = document.createElement('button');
        cancel.textContent = 'Cancel verification';
        cancel.style.cssText = 'font:inherit;color:inherit;background:transparent;border:1px solid #61736c;border-radius:8px;min-height:48px;width:100%;margin-top:16px;cursor:pointer';
        dialog.append(title, help, container, cancel);
        let widget, api, done = false;
        const finish = token => {
          if (done) return;
          done = true;
          clearTimeout(timer);
          if (widget !== undefined) { try { api.remove(widget); } catch { /* best effort */ } }
          dialog.close(); dialog.remove(); active = null;
          previousFocus?.focus();
          if (typeof token === 'string' && token.length > 0 && token.length <= 2048) resolve(token);
          else reject(new Error('Verification did not complete'));
        };
        const timer = setTimeout(() => finish(null), 120000);
        active = { cancel: () => finish(null) };
        cancel.onclick = () => finish(null);
        dialog.addEventListener('cancel', event => { event.preventDefault(); finish(null); });
        document.body.append(dialog);
        dialog.showModal(); cancel.focus();
        load().then(provider => {
          if (done) return;
          api = provider;
          widget = api.render(container, {
            sitekey, theme: theme === 'dark' ? 'dark' : 'light', size: 'flexible',
            execution: 'execute', appearance: 'always', retry: 'never',
            'refresh-expired': 'never', 'refresh-timeout': 'never', 'response-field': false,
            callback: token => finish(token),
            'error-callback': () => { finish(null); return true; },
            'expired-callback': () => finish(null), 'timeout-callback': () => finish(null),
            'unsupported-callback': () => finish(null),
          });
          api.execute(widget);
        }).catch(() => finish(null));
      });
    },
  };
  window.addEventListener('pagehide', () => window.prQueueChallenge.cancel());
})();

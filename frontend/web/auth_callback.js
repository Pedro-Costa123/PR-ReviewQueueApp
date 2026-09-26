// Runs before Flutter. Never leave login material in history, referrers or
// router state. GET/prefetch alone does not redeem a link.
(() => {
  let pending = null;
  // Handoff only; Dart independently checks the build's mode and exact origin.
  const origins = ['http://127.0.0.1:4173', 'https://pr-review-queue.pages.dev'];
  const keys = ['token_hash', 'type', 'access_token', 'refresh_token', 'code', 'error', 'error_description', 'error_code'];
  function scrub(allowHandoff, href = location.href) {
    const url = new URL(href);
    const fragment = new URLSearchParams(url.hash.slice(1));
    if (!keys.some(key => fragment.has(key) || url.searchParams.has(key))) return false;
    const hash = fragment.get('token_hash');
    if (allowHandoff && origins.includes(url.origin) && !url.username && !url.password
        && url.pathname === '/' && fragment.get('type') === 'email'
        && [...fragment.keys()].length === 2
        && /^[a-zA-Z0-9_-]{32,256}$/.test(hash ?? '') && !url.search) {
      pending = hash;
    } else {
      pending = 'invalid';
    }
    history.replaceState(null, '', '/');
    return true;
  }
  scrub(true);
  // A hash-only navigation does not reload this script or Flutter. Reject it
  // and prevent callback material from reaching the already-running router.
  // Reopen the email link in a new document for the confirmation handoff.
  for (const name of ['popstate', 'hashchange']) {
    window.addEventListener(name, event => {
      if (scrub(false, event.newURL ?? location.href)) event.stopImmediatePropagation();
    });
  }
  window.takeAuthCallback = () => { const result = pending; pending = null; return result; };
})();

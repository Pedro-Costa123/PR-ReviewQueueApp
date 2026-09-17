// Runs before Flutter. Never leave login material in history, referrers or
// router state. GET/prefetch alone does not redeem a link.
(() => {
  let pending = null;
  const url = new URL(location.href);
  const fragment = new URLSearchParams(url.hash.slice(1));
  const keys = ['token_hash', 'type', 'access_token', 'refresh_token', 'code', 'error', 'error_description', 'error_code'];
  if (keys.some(key => fragment.has(key) || url.searchParams.has(key))) {
    const hash = fragment.get('token_hash');
    if (url.pathname === '/PR-Review-App-Queue/' && fragment.get('type') === 'email'
        && /^[a-zA-Z0-9_-]{32,256}$/.test(hash ?? '') && !url.search) {
      pending = hash;
    } else {
      pending = 'invalid';
    }
    history.replaceState(null, '', '/PR-Review-App-Queue/');
  }
  window.takeAuthCallback = () => { const result = pending; pending = null; return result; };
})();

const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const script = fs.readFileSync('web/turnstile.js', 'utf8');

function page({ loaded = true } = {}) {
  const elements = [], timers = new Map(), renders = [], removed = [], events = {};
  let nextTimer = 0, focused = 0;
  const document = { activeElement: { focus() { focused++; } },
    createElement(tag) {
      const element = { tag, style: {}, events: {}, children: [],
        setAttribute() {}, append(...children) { this.children.push(...children); },
        remove() { this.removed = true; }, showModal() { this.open = true; }, close() { this.open = false; },
        focus() {}, addEventListener(name, handler) { this.events[name] = handler; } };
      elements.push(element); return element;
    }, head: { append() {} }, body: { append() {} } };
  const api = { ready() { throw new Error('ready is incompatible with async loading'); }, render(container, options) { renders.push(options); return renders.length; },
    execute() {}, remove(id) { removed.push(id); } };
  const window = { addEventListener(name, handler) { events[name] = handler; }, ...(loaded ? { turnstile: api } : {}) };
  vm.runInNewContext(script, { window, document, Promise,
    setTimeout(fn, ms) { const id = ++nextTimer; timers.set(id, { fn, ms }); return id; },
    clearTimeout(id) { timers.delete(id); } });
  return { bridge: window.prQueueChallenge, renders, removed, elements, timers, events, window, api,
    get focused() { return focused; }, tick: async () => { await Promise.resolve(); await Promise.resolve(); } };
}
test('script is lazy; every request creates a fresh widget and consumes exactly one token', async () => {
  const p = page();
  assert.equal(p.elements.length, 0);
  for (let n = 1; n <= 2; n++) {
    const pending = p.bridge.request('site-key', 'dark');
    await p.tick();
    const options = p.renders[n - 1];
    assert.equal(options.execution, 'execute');
    assert.equal(options.retry, 'never');
    assert.equal(options['response-field'], false);
    options.callback(`token-${n}`);
    assert.equal(await pending, `token-${n}`);
    options.callback('late-token');
  }
  assert.deepEqual(p.removed, [1, 2]);
  assert.equal(p.focused, 2);
  assert.equal(p.timers.size, 0);
});

test('first asynchronous load uses the provider callback before rendering', async () => {
  const p = page({ loaded: false });
  const pending = p.bridge.request('site-key', 'dark');
  const source = p.elements.find(e => e.tag === 'script');
  assert.equal(source.async, true);
  assert.equal(new URL(source.src).searchParams.get('onload'), 'prQueueTurnstileLoaded');
  assert.equal(p.renders.length, 0);
  p.window.turnstile = p.api;
  p.window.prQueueTurnstileLoaded();
  await p.tick();
  p.renders[0].callback('first-load-token');
  assert.equal(await pending, 'first-load-token');
  assert.equal(p.timers.size, 0);
});
test('expiry, error, timeout and unsupported callbacks reject and allow manual retry', async () => {
  for (const event of ['expired-callback', 'error-callback', 'timeout-callback', 'unsupported-callback']) {
    const p = page();
    const pending = p.bridge.request('site-key', 'light');
    const rejected = assert.rejects(pending, /Verification did not complete/);
    await p.tick();
    p.renders[0][event]();
    await rejected;
    assert.equal(p.removed.length, 1);
    const retry = p.bridge.request('site-key', 'light');
    await p.tick(); p.renders[1].callback('fresh');
    assert.equal(await retry, 'fresh');
  }
});
test('cancel, Escape and pagehide reject; a late script load cannot start a cancelled widget', async () => {
  for (const mode of ['button', 'escape', 'pagehide']) {
    const p = page({ loaded: false });
    const pending = p.bridge.request('site-key', 'dark');
    const rejected = assert.rejects(pending);
    if (mode === 'button') p.elements.find(e => e.tag === 'button').onclick();
    if (mode === 'escape') p.elements.find(e => e.tag === 'dialog').events.cancel({ preventDefault() {} });
    if (mode === 'pagehide') p.events.pagehide();
    await rejected;
    p.window.turnstile = p.api;
    p.window.prQueueTurnstileLoaded();
    await p.tick();
    assert.equal(p.renders.length, 0);
    assert.equal(p.timers.size, 0);
  }
});
test('script failures and bounded waits reject without background retries', async () => {
  for (const failure of ['network', 'script-timeout', 'challenge-timeout']) {
    const p = page({ loaded: failure === 'challenge-timeout' });
    const pending = p.bridge.request('site-key', 'dark');
    const rejected = assert.rejects(pending);
    await p.tick();
    if (failure === 'network') p.elements.find(e => e.tag === 'script').onerror();
    else [...p.timers.values()].find(t => t.ms === (failure === 'script-timeout' ? 15000 : 120000)).fn();
    await rejected;
    assert.equal(p.elements.filter(e => e.tag === 'script').length, failure === 'challenge-timeout' ? 0 : 1);
  }
});
test('overlapping requests and invalid tokens cannot reach Auth', async () => {
  const p = page();
  const first = p.bridge.request('site-key', 'dark');
  const rejected = assert.rejects(first);
  await assert.rejects(p.bridge.request('site-key', 'dark'), /already running/);
  await p.tick(); p.renders[0].callback('');
  await rejected;
});

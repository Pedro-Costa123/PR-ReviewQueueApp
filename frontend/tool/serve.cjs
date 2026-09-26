// Local release preview only. Serves the build at the required production path.
// No dependencies, backend, directory listings, or SPA rewrite fallback.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const base = '/';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf' };
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1:4173');
  const policy = fs.readFileSync(path.join(root, '_headers'), 'utf8');
  for (const line of policy.split(/\r?\n/).slice(1).filter(Boolean)) {
    const colon = line.indexOf(':');
    res.setHeader(line.slice(0, colon).trim(), line.slice(colon + 1).trim());
  }
  if (url.pathname === '/__preview/narrow') {
    // QA wrapper only. The application keeps the exact production anti-frame CSP.
    res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; frame-src 'self'");
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.end('<!doctype html><html lang="en"><title>Narrow preview · 390 × 844</title><body style="margin:24px;background:#dce5e1;font-family:system-ui"><p>Local QA viewport · 390 × 844</p><iframe title="Narrow app preview" width="390" height="844" style="border:1px solid #61736c" src="/"></iframe></body></html>');
  }
  let relative;
  if (url.pathname === '/_headers') { res.writeHead(404); return res.end('Not found'); }
  try { relative = decodeURIComponent(url.pathname.slice(base.length)) || 'index.html'; }
  catch { res.writeHead(400); return res.end('Bad path'); }
  const file = path.resolve(root, relative);
  if (!file.startsWith(root + path.sep)) { res.writeHead(403); return res.end('Forbidden'); }
  fs.readFile(file, (error, content) => {
    if (error) { res.writeHead(404); return res.end('Not found'); }
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    res.end(content);
  });
}).listen(4173, '127.0.0.1', () => console.log('Release preview: http://127.0.0.1:4173/'));

// Isolated browser QA. Public Cloudflare dummy keys never reach Supabase.
// This file and test/ are outside the Flutter web artifact.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const routes = {
  '/': ['../test/fixtures/turnstile.html', 'text/html; charset=utf-8'],
  '/turnstile.js': ['../web/turnstile.js', 'text/javascript'],
};
http.createServer((req, res) => {
  if (req.url === '/narrow') {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    return res.end('<!doctype html><title>Narrow widget QA</title><iframe title="390 by 844 widget preview" src="/" style="width:390px;height:844px;border:1px solid #777"></iframe>');
  }
  const route = routes[req.url];
  if (!route) { res.writeHead(404); return res.end(); }
  res.setHeader('Content-Type', route[1]); res.setHeader('Cache-Control', 'no-store');
  res.end(fs.readFileSync(path.resolve(__dirname, route[0])));
}).listen(4175, '127.0.0.1', () => console.log('Isolated widget QA: http://127.0.0.1:4175/'));

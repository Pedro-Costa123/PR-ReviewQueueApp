// Read-only repository/history credential-pattern and documentation audit.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {execFileSync} = require('node:child_process');
const {scan,sha256} = require('../../frontend/tool/release-policy.cjs');
const root = path.resolve(__dirname,'../..');
const git = args => execFileSync('git',args,{cwd:root,windowsHide:true,maxBuffer:64*1024*1024});
const files = [...new Set(git(['ls-files','--cached','--others','--exclude-standard','-z']).toString().split('\0').filter(Boolean))];
let markdown = 0, links = 0;
for (const file of files) {
  const absolute = path.join(root,file);
  if (!fs.existsSync(absolute)) continue;
  assert.ok(!/(^|\/)(?:backups|exports|releases|node_modules)\//.test(file), `Private/generated path tracked: ${file}`);
  assert.ok(!/(^|\/)\.env(?:\.|$)/.test(file) || file.endsWith('.example'), `Nonexample env tracked: ${file}`);
  const bytes = fs.readFileSync(absolute);
  scan(bytes,file);
  if (!file.endsWith('.md')) continue;
  markdown++;
  const text = bytes.toString('utf8');
  assert.equal((text.match(/^```/gm)||[]).length % 2,0,`Unbalanced fences: ${file}`);
  assert.ok(!/[ \t]+$/m.test(text),`Trailing whitespace: ${file}`);
  for (const match of text.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
    const target = match[1].replace(/^<|>$/g,'').split('#')[0];
    if (!target || /^[a-z]+:/i.test(target)) continue;
    links++;
    assert.ok(fs.existsSync(path.resolve(path.dirname(absolute),decodeURIComponent(target))),`Broken relative link: ${file} -> ${target}`);
  }
}
let blobs = 0;
if (process.argv.includes('--history')) {
  const objects = git(['rev-list','--objects','--all']).toString().split('\n').filter(Boolean);
  for (const line of objects) {
    const [id,...parts] = line.split(' ');
    const file = parts.join(' ');
    if (!file || git(['cat-file','-t',id]).toString().trim() !== 'blob') continue;
    scan(git(['cat-file','blob',id]), `history:${id.slice(0,12)}:${file}`);
    blobs++;
  }
}
// Detect exact local secret values in the current build without exposing them.
const env = path.join(root,'backend/.env');
let comparedSecrets = 0;
if (fs.existsSync(env) && fs.existsSync(path.join(root,'frontend/build/web'))) {
  const secrets = fs.readFileSync(env,'utf8').split(/\r?\n/).map(line => line.match(/^([A-Z_]*(?:SECRET|PASSWORD|TOKEN|RESEND_API_KEY)[A-Z_]*)=(.*)$/)).filter(Boolean)
    .map(match=>match[2].replace(/^['"]|['"]$/g,'')).filter(value=>value.length>=16);
  function visit(dir) {
    for (const item of fs.readdirSync(dir,{withFileTypes:true})) {
      const file = path.join(dir,item.name);
      if (item.isDirectory()) visit(file);
      else {
        const bytes = fs.readFileSync(file);
        assert.ok(!secrets.some(secret=>bytes.includes(Buffer.from(secret))),`Local secret found in asset: ${path.basename(file)}`);
      }
    }
  }
  visit(path.join(root,'frontend/build/web'));
  comparedSecrets = secrets.length;
}
console.log(JSON.stringify({files:files.length,markdown,relativeLinks:links,historyBlobs:blobs,exactLocalSecretsCompared:comparedSecrets,licenseSha256:sha256(fs.readFileSync(path.join(root,'LICENSE'))),note:'Heuristic credential scan plus exact local-secret comparison; not a guarantee of absence.'},null,2));

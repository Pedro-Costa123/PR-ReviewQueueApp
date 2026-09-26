const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const { releaseConfig, inventory, sha256, origin } = require('./release-policy.cjs');
const root = path.resolve(__dirname, '../..');
const frontend = path.join(root, 'frontend');
const [command, mode, pass] = process.argv.slice(2);
const config = releaseConfig(mode);
const folder = path.join(root, 'releases', mode);
const hashFile = file => sha256(fs.readFileSync(path.join(root, file)));
const git = (...args) => execFileSync('git', args, {cwd: root, encoding: 'utf8', windowsHide: true}).trim();
function sourceHash() {
  const files = git('ls-files','--cached','--others','--exclude-standard','-z').split('\0').filter(Boolean)
    .filter(file => /^(frontend\/(lib|web|tool)\/|frontend\/pubspec\.|backend\/(supabase\/(migrations|functions)\/|package))/u.test(file))
    .filter(file => fs.existsSync(path.join(root,file))).sort();
  return sha256(JSON.stringify(files.map(file => [file,hashFile(file)])));
}
if (command === 'validate') {
  assert.equal(process.version, 'v26.5.0', 'Use reviewed Node 26.5.0');
  console.log('Public-only configuration and Node version validated.');
} else if (command === 'record') {
  assert.ok(['1', '2'].includes(pass));
  fs.mkdirSync(folder, {recursive: true});
  const files = inventory(path.join(frontend, 'build/web'));
  const manifest = { format: 1, mode, destination: mode === 'production' ? origin + '/' : 'LOCAL REVIEW ONLY',
    revision: git('rev-parse','HEAD'), dirty: !!git('status','--porcelain'),
    sourceHash: sourceHash(),
    publicConfigHash: sha256(JSON.stringify(config)), node: process.version,
    flutter: '3.47.4 / 9584c6713b', dart: '3.13.3',
    lockfiles: Object.fromEntries(['frontend/pubspec.lock','backend/package-lock.json'].map(file => [file, hashFile(file)])),
    migrations: fs.readdirSync(path.join(root,'backend/supabase/migrations')).sort().map(file => ({file, sha256: hashFile('backend/supabase/migrations/' + file)})), files };
  fs.writeFileSync(path.join(folder, `pass-${pass}.json`), JSON.stringify(manifest,null,2) + '\n');
  console.log(`Recorded pass ${pass}: ${files.length} files.`);
} else if (command === 'compare') {
  const one = JSON.parse(fs.readFileSync(path.join(folder,'pass-1.json')));
  const two = JSON.parse(fs.readFileSync(path.join(folder,'pass-2.json')));
  assert.ok(JSON.stringify(two) === JSON.stringify(one), 'Clean builds or source inputs differ; compare private pass manifests before release');
  const artifact = path.join(folder, 'web');
  // Fixed generated output only; never follow an externally supplied deletion path.
  assert.ok(artifact.startsWith(path.join(root, 'releases') + path.sep));
  fs.rmSync(artifact, {recursive: true, force: true});
  fs.cpSync(path.join(frontend,'build/web'), artifact, {recursive: true});
  assert.deepEqual(inventory(artifact), two.files);
  fs.writeFileSync(path.join(folder,'manifest.json'), JSON.stringify({...two, reproducible: true},null,2) + '\n');
  console.log(`Two clean builds match byte-for-byte. Review package: releases/${mode}/`);
} else if (command === 'verify') {
  assert.ok(['production','disconnected'].includes(mode), 'Local/check packages must never be uploaded');
  const manifest = JSON.parse(fs.readFileSync(path.join(folder,'manifest.json')));
  assert.ok(manifest.reproducible && manifest.mode === mode);
  assert.equal(manifest.sourceHash,sourceHash(),'Rebuild changed release inputs');
  assert.equal(manifest.publicConfigHash,sha256(JSON.stringify(config)),'Rebuild changed public config');
  assert.ok(JSON.stringify(inventory(path.join(folder,'web'))) === JSON.stringify(manifest.files),'Packaged artifact changed');
  assert.ok(JSON.stringify(inventory(path.join(frontend,'build/web'))) === JSON.stringify(manifest.files),'build/web differs from reviewed package');
  console.log(`Verified ${mode} artifact integrity. This is not deployment authorization.`);
} else throw new Error('Expected validate, record, compare or verify');

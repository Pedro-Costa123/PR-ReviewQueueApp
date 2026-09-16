// Request loopback binding using Supabase's documented Docker network option.
// Verify/report actual bindings: some Docker/CLI versions ignore that default.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const network = 'pr-review-queue-local';
const binding = 'com.docker.network.bridge.host_binding_ipv4';
function run(command, args, timeout = 30000) {
  const result = spawnSync(command, args, {
    cwd: root, encoding: 'utf8', windowsHide: true, timeout, maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  return result;
}
assert.ok(!process.env.DOCKER_HOST, 'Use a local Docker context without a host override');
const context = run('docker', ['context', 'inspect']);
assert.equal(context.status, 0, 'Start Docker Desktop first');
assert.match(JSON.parse(context.stdout)[0].Endpoints.docker.Host, /^(npipe:\/\/|unix:\/\/)/);
let inspected = run('docker', ['network', 'inspect', network]);
if (inspected.status !== 0) {
  const created = run('docker', ['network', 'create', '--driver', 'bridge', '--opt', `${binding}=127.0.0.1`, network]);
  assert.equal(created.status, 0, created.stderr);
  inspected = run('docker', ['network', 'inspect', network]);
}
assert.equal(inspected.status, 0, inspected.stderr);
assert.equal(JSON.parse(inspected.stdout)[0].Options[binding], '127.0.0.1', 'Unexpected network binding; inspect it before starting');
console.log('Starting local Supabase with loopback binding requested; first start may download Docker images...');
const started = run(process.execPath, [path.join(root, 'node_modules/supabase/dist/supabase.js'),
  'start', '--network-id', network, '-x', 'studio,realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor'], 600000);
if (started.status !== 0) {
  console.error(started.stderr);
  process.exit(started.status || 1);
}
// Check actual bindings, including an already-running stack started elsewhere.
let nonLoopback = false;
for (const service of ['db', 'kong', 'inbucket']) {
  const ports = run('docker', ['inspect', `supabase_${service}_pr-review-queue`, '--format', '{{json .NetworkSettings.Ports}}']);
  assert.equal(ports.status, 0, ports.stderr);
  for (const mappings of Object.values(JSON.parse(ports.stdout))) {
    for (const mapping of mappings || []) {
      if (mapping.HostIp !== '127.0.0.1') nonLoopback = true;
    }
  }
}
if (nonLoopback) {
  console.warn('Docker reports ports published beyond loopback despite the requested network default.');
  console.warn('Use only on a trusted development machine/network and stop with npm run stop after use.');
}
// Supabase startup prints credentials; keep them out of routine test/build logs.
console.log('Local API: http://127.0.0.1:54321; local mail capture: http://127.0.0.1:54324');
console.log('Supabase is ready. Development credentials omitted; use the local CLI status command when needed.');

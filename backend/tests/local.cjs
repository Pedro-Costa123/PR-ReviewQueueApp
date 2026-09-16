// Test infrastructure only: no remote URL/key overrides and no app dependency.
const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const { existsSync, readFileSync } = require('node:fs');
const path = require('node:path');
const { createHmac } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const container = 'supabase_db_pr-review-queue';
const cli = path.join(root, 'node_modules/supabase/dist/supabase.js');

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', windowsHide: true, timeout: 30000, ...options });
  if (result.error) throw result.error;
  return result;
}

function localStack() {
  assert.equal(existsSync(path.join(root, 'supabase/.temp/project-ref')), false, 'Refuse linked projects');
  assert.match(readFileSync(path.join(root, 'supabase/config.toml'), 'utf8'), /project_id = "pr-review-queue"/);
  assert.ok(!process.env.DOCKER_HOST, 'Refuse a Docker host override');
  const context = run('docker', ['context', 'inspect']);
  assert.equal(context.status, 0, 'Docker context must be available');
  const endpoint = JSON.parse(context.stdout)[0].Endpoints.docker.Host;
  assert.match(endpoint, /^(npipe:\/\/|unix:\/\/)/, 'Tests require a local Docker engine');
  const inspected = run('docker', ['inspect', container, '--format', '{{json .Config.Labels}}']);
  assert.equal(inspected.status, 0, 'Start this project with npm start');
  const labels = JSON.parse(inspected.stdout);
  assert.equal(labels['com.supabase.cli.project'], 'pr-review-queue');
  assert.equal(path.resolve(labels['com.supabase.cli.workdir']), root, 'Container must belong to this checkout');
  const result = run(process.execPath, [cli, 'status', '-o', 'json']);
  assert.equal(result.status, 0, 'Local Supabase must be healthy');
  const status = JSON.parse(result.stdout);
  assert.equal(status.API_URL, 'http://127.0.0.1:54321');
  assert.equal(new URL(status.DB_URL).hostname, '127.0.0.1');
  assert.ok(status.JWT_SECRET && status.ANON_KEY, 'Local test signing material must be available');
  return status; // Kept in process memory; never logged or written to disk.
}

function sql(statement) {
  return run('docker', ['exec', '-i', container, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-U', 'postgres', '-d', 'postgres'], { input: statement });
}
function scalar(statement) {
  const result = sql(statement);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}
function roleSql(role, user, statement) {
  assert.ok(['anon', 'authenticated', 'service_role'].includes(role));
  return sql(`begin; set local role ${role}; select set_config('request.jwt.claims', '${JSON.stringify({ sub: user, role })}', true); ${statement}; rollback;`);
}
function token(status, user, metadata = {}) {
  // Short-lived synthetic JWTs ONLY for the local fixture database, never an
  // Auth implementation. Signature verification still runs in PostgREST.
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode({ sub: user, role: 'authenticated', aud: 'authenticated', iat: now, exp: now + 600, user_metadata: metadata })}`;
  return `${unsigned}.${createHmac('sha256', status.JWT_SECRET).update(unsigned).digest('base64url')}`;
}
async function request(status, jwt, route, { method = 'GET', body, headers = {} } = {}) {
  const response = await fetch(`${status.API_URL}/rest/v1/${route}`, {
    method,
    headers: { apikey: status.ANON_KEY, ...(jwt ? { Authorization: `Bearer ${jwt}` } : {}), 'Content-Type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'error', signal: AbortSignal.timeout(10000),
  });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
}
function connection(application) {
  assert.match(application, /^p03_[a-z_]+$/);
  const process = spawn('docker', ['exec', '-i', container, 'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-U', 'postgres', '-d', 'postgres'], { windowsHide: true, cwd: root });
  let stdout = '', stderr = '';
  process.stdout.on('data', data => { stdout += data; });
  process.stderr.on('data', data => { stderr += data; });
  const done = new Promise((resolve, reject) => {
    process.on('error', reject);
    process.on('close', code => resolve({ code, stdout, stderr }));
  });
  process.stdin.write(`set application_name = '${application}'; set statement_timeout = '10s';\n`);
  return { process, done, write: text => process.stdin.write(text + '\n'), end: () => process.stdin.end() };
}
async function until(check) {
  const deadline = Date.now() + 10000;
  while (!check()) {
    assert.ok(Date.now() < deadline, 'Timed out waiting for database lock');
    await new Promise(resolve => setTimeout(resolve, 50));
  }
}
module.exports = { root, localStack, sql, scalar, roleSql, token, request, connection, until };

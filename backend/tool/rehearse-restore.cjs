// Fictional local stack only. No hosted credentials, endpoints, mail or settings.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { randomBytes, createHash } = require('node:crypto');
const { localStack, scalar } = require('../tests/local.cjs');
localStack();
assert.equal(scalar("select count(*) from auth.users where email is not null and email !~ '@[^@]+\\.test$'"), '0', 'Rehearsal accepts fictional identities only');
const container = 'supabase_db_pr-review-queue';
const database = 'p12_restore_' + randomBytes(6).toString('hex');
const folder = path.resolve(__dirname, '../../backups', database);
fs.mkdirSync(folder, {recursive: true});
function run(command, args, input, encoding = 'utf8') {
  const result = spawnSync(command,args,{input,encoding,windowsHide:true,timeout:120000,maxBuffer:128*1024*1024});
  if (result.status !== 0 && args.includes('pg_restore')) {
    // Only the first server error line; never SQL statements or COPY row data.
    console.error(String(result.stderr).split(/\r?\n/).find(line => line.startsWith('pg_restore: error:'))?.replace(/DETAIL:.*/, '') || 'Restore failed');
  }
  // Child output can include data on failure. Do not echo it to logs.
  assert.equal(result.status,0, `${command} failed (${result.status}); inspect privately if needed`);
  return result.stdout;
}
function protect(operation, input) {
  return Buffer.from(run('powershell.exe',['-NoProfile','-File',path.join(__dirname,'restricted-backup.ps1'),'-Operation',operation],input.toString('base64')), 'base64');
}
function query(db, sql) {
  return run('docker',['exec','-i',container,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d',db],sql).trim();
}
const fingerprintSql = `select format('%I.%I',schemaname,tablename) from pg_tables where schemaname in ('public','private','auth','supabase_migrations') order by 1`;
function fingerprint(db) {
  const tables = query(db, fingerprintSql).split('\n').filter(Boolean);
  return tables.map(table => ({ table, count: Number(query(db,`select count(*) from ${table}`)),
    digest: query(db,`select md5(coalesce(string_agg(row_to_json(t)::text, E'\\n' order by row_to_json(t)::text),'')) from ${table} t`) }));
}
const securitySql = `select json_build_object('tables',(select json_agg(x order by x.name) from (select n.nspname||'.'||c.relname name,c.relrowsecurity,c.relforcerowsecurity,coalesce(c.relacl,acldefault('r',c.relowner))::text relacl from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r') x),'functions',(select json_agg(x order by x.name) from (select n.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')' name,p.prosecdef,p.proconfig,coalesce(p.proacl,acldefault('f',p.proowner))::text proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')) x),'policies',(select json_agg(x order by x.schemaname,x.tablename,x.policyname) from pg_policies x where schemaname in ('public','private')))`;
let created = false;
try {
  run('powershell.exe',['-NoProfile','-File',path.join(__dirname,'restricted-backup.ps1'),'-Operation','Restrict','-Directory',folder]);
  const before = fingerprint('postgres');
  assert.ok(before.some(t => t.table === 'public.queue_entries' && t.count > 0), 'Load fictional test records first');
  const security = query('postgres',securitySql);
  const dump = run('docker',['exec',container,'pg_dump','-U','postgres','-d','postgres','--format=custom','--schema=public','--schema=private','--schema=auth','--schema=extensions','--schema=supabase_migrations'],undefined,null);
  const sealed = protect('Protect',dump);
  const archive = path.join(folder,'database.dump.dpapi');
  fs.writeFileSync(archive,sealed,{flag:'wx'});
  const restoredBytes = protect('Unprotect',fs.readFileSync(archive));
  assert.deepEqual(restoredBytes,dump,'Encrypted backup round trip');
  query('postgres',`create database ${database} template template0`);
  created = true;
  query(database,'drop schema public'); // Empty template schema in our scratch DB only.
  // The isolated local cluster's internal superuser restores original owners and
  // managed Auth default ACLs. Never grant extra rights to hosted postgres.
  run('docker',['exec','-i',container,'pg_restore','-U','supabase_admin','-d',database,'--exit-on-error','--single-transaction'],restoredBytes);
  assert.deepEqual(fingerprint(database),before,'Every included table count/content must match');
  assert.ok(query(database,securitySql) === security,'Effective RLS, policies, function grants/search paths must match');
  assert.equal(query(database,"select count(*) from private.auth_trial_admissions where revoked_at is null"),'0');
  assert.equal(query(database,"select position('auth_trial_admissions' in pg_get_functiondef('public.reserve_auth_email(text,text,uuid,text,text)'::regprocedure))"),'0');
  // Authorization actually executes on the restored database, including valid JWT claims.
  assert.equal(query(database,`begin; set local role authenticated; select count(*) from public.teams; rollback;`),'0');
  const anonymous = spawnSync('docker',['exec','-i',container,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d',database],{input:'begin; set local role anon; select * from public.teams; rollback;',encoding:'utf8',windowsHide:true});
  assert.notEqual(anonymous.status,0);
  assert.match(anonymous.stderr,/permission denied/);
  const actors = query(database,`select json_build_object('team',a.team_id,'member',a.user_id,'foreign',b.user_id,'revoked',r.user_id) from public.team_memberships a cross join public.team_memberships b cross join public.team_memberships r where a.active and b.active and r.active=false and a.team_id<>b.team_id and a.team_id=r.team_id and not exists(select 1 from public.team_memberships m where m.team_id=a.team_id and m.user_id=b.user_id and m.active) limit 1`);
  assert.ok(actors,'Need active, foreign and revoked fixture members');
  const ids = JSON.parse(actors);
  for (const key of ['foreign','revoked']) {
    assert.equal(query(database,`begin; set local role authenticated; set local "request.jwt.claims" = '{"sub":"${ids[key]}","role":"authenticated"}'; select count(*) from public.teams where id='${ids.team}'; rollback;`),'0');
  }
  const denied = spawnSync('docker',['exec','-i',container,'psql','-X','-qAt','-v','ON_ERROR_STOP=1','-U','postgres','-d',database],{input:`begin; set local role authenticated; set local "request.jwt.claims" = '{"sub":"${ids.member}","role":"authenticated"}'; update public.queue_entries set submitter_id='${ids.foreign}' where team_id='${ids.team}'; rollback;`,encoding:'utf8',windowsHide:true});
  assert.notEqual(denied.status,0,'Restored forged/direct ownership must be denied');
  assert.match(denied.stderr,/permission denied/);
  const evidence = {version:1,scope:'fictional local database only',tables:before.length,rows:before.reduce((sum,t)=>sum+t.count,0),encryptedBytes:sealed.length,encryptedSha256:createHash('sha256').update(sealed).digest('hex'),encryption:'Windows DPAPI CurrentUser; restricted operator + SYSTEM ACL',checks:['all table counts and content hashes','RLS and policies','function grants and fixed search paths','retired admission','anonymous/foreign/revoked/forged ownership denials'],limitations:['No hosted export or restore','Same local Postgres cluster supplies roles/extensions','Auth/config/secrets and disaster recovery on another machine require RELEASE runbook']};
  fs.writeFileSync(path.join(folder,'evidence.json'),JSON.stringify(evidence,null,2)+'\n');
  console.log(JSON.stringify(evidence,null,2));
} finally {
  // Only the randomly named scratch database created by this run; never postgres.
  assert.match(database,/^p12_restore_[a-f0-9]{12}$/);
  if (created) query('postgres',`drop database ${database} with (force)`);
}

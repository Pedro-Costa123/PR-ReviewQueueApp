// Never targets a hosted project or resets the developer's existing database.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync, spawn } = require('node:child_process');
const { randomBytes } = require('node:crypto');
const { localStack, root } = require('./local.cjs');
const container = 'supabase_db_pr-review-queue';
const database = 'ops01_reset_' + randomBytes(6).toString('hex');
const script = fs.readFileSync(path.join(root, 'operator/reset-project.sql'), 'utf8');
const user = n => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
function docker(args, input, encoding = 'utf8') {
  return spawnSync('docker', args, { input, encoding, windowsHide: true, timeout: 90000, maxBuffer: 32 * 1024 * 1024 });
}
function psql(input, variables = {}, db = database) {
  return docker(['exec', '-i', container, 'psql', '-X', '-qAt', '-h', '/var/run/postgresql',
    '-U', 'postgres', '-d', db, '-v', 'ON_ERROR_STOP=1',
    ...Object.entries(variables).flatMap(([k,v]) => ['-v', `${k}=${v}`])], input);
}
function query(input, db) {
  const r = psql(input, {}, db);
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function reset(overrides = {}, prefix = '') {
  return psql(prefix + script, { admin_email: 'fixture1@example.test', team_name: "Fresh team's queue",
    apply: 'true', confirm: `RESET /var/run/postgresql / ${database} / postgres`, ...overrides });
}
function fingerprint() {
  const tables = query("select format('%I.%I',schemaname,tablename) from pg_tables where schemaname in ('public','private','auth','supabase_migrations') order by 1").split('\n');
  return tables.map(table => [table, query(`select md5(coalesce(string_agg(row_to_json(t)::text, E'\\n' order by row_to_json(t)::text),'')) from ${table} t`)]);
}
function denied(result, pattern) {
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, pattern);
}
const security = `select json_build_object(
  'tables',(select json_agg(t order by t.name) from (select n.nspname||'.'||c.relname name,c.relrowsecurity,c.relacl::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r') t),
  'policies',(select json_agg(t order by schemaname,tablename,policyname) from pg_policies t where schemaname in ('public','private')),
  'functions',(select json_agg(t order by t.oid) from (select p.oid,p.proacl::text,pg_get_functiondef(p.oid) definition from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')) t))`;

test('operator reset rehearsal in an isolated fictional database', async t => {
  localStack();
  let created = false;
  try {
    const dump = docker(['exec', container, 'pg_dump', '-U', 'postgres', '-d', 'postgres',
      '--schema-only', '--format=custom', '--schema=public', '--schema=private', '--schema=auth',
      '--schema=extensions', '--schema=storage', '--schema=supabase_migrations'], undefined, null);
    assert.equal(dump.status, 0, 'Local schema dump');
    query(`create database ${database} template template0`, 'postgres');
    created = true;
    query('drop schema public');
    const restore = docker(['exec', '-i', container, 'pg_restore', '-U', 'supabase_admin', '-d', database,
      '--exit-on-error', '--single-transaction'], dump.stdout);
    assert.equal(restore.status, 0, restore.stderr);
    const versions = fs.readdirSync(path.join(root, 'supabase/migrations')).map(f => f.split('_')[0]);
    query(`insert into supabase_migrations.schema_migrations(version) values ${versions.map(v => `('${v}')`).join(',')}`);
    query(fs.readFileSync(path.join(root, 'supabase/tests/fixtures.sql'), 'utf8'));
    query(`update public.team_memberships set active=false where user_id='${user(2)}';
      update public.queue_entries set state='archived',archived_at=now(),archived_by='${user(1)}',archive_reason='merged' where submitter_id='${user(2)}';
      update public.queue_entries set deleted_at=now(),deleted_by='${user(3)}' where submitter_id='${user(4)}';
      insert into private.enterprise_hosts select id,'pr','git.example.test' from public.teams;
      insert into private.enterprise_hosts select id,'jira','jira.example.test' from public.teams;
      insert into auth.sessions(id,user_id,created_at,updated_at) values (gen_random_uuid(),'${user(2)}',now(),now());
      insert into auth.refresh_tokens(session_id,user_id,token) select id,user_id::text,'fictional-reset-refresh' from auth.sessions;
      insert into auth.identities(provider_id,user_id,identity_data,provider) values ('${user(2)}','${user(2)}','{}','email');
      insert into private.auth_trial_admissions(slot,user_id,email,revoked_at) values (1,'${user(2)}','fixture2@example.test',now());`);
    const before = fingerprint();
    const permissions = query(security);
    await t.test('preview defaults to no persistent changes and shows exact target', () => {
      const r = psql(script, { admin_email: ' FIXTURE1@example.test ', team_name: 'Fresh team' });
      assert.equal(r.status, 0, r.stderr);
      assert.match(r.stdout, /PREVIEW ONLY/);
      assert.ok(r.stdout.includes(`RESET /var/run/postgresql / ${database} / postgres`));
      assert.deepEqual(fingerprint(), before);
    });
    await t.test('invalid input and confirmation leave all rows intact', () => {
      denied(reset({ confirm: 'RESET another-project' }), /exact confirmation/);
      denied(reset({ admin_email: 'missing@example.test' }), /existing, verified/);
      denied(reset({ team_name: ' ' }), /Supply admin_email/);
      denied(reset({ team_name: 'x'.repeat(101) }), /Supply admin_email/);
      denied(reset({ apply: 'typo' }), /invalid input syntax/);
      assert.deepEqual(fingerprint(), before);
      query(`update auth.users set email_confirmed_at=null where id='${user(7)}'`);
      denied(reset({ admin_email: 'fixture7@example.test' }), /existing, verified/);
      query(`update auth.users set email_confirmed_at=now(),banned_until=now()+interval '1 day' where id='${user(7)}'`);
      denied(reset({ admin_email: 'fixture7@example.test' }), /existing, verified/);
      query(`update auth.users set banned_until=null where id='${user(7)}'`);
    });
    await t.test('API roles cannot execute reset or bootstrap', () => {
      for (const role of ['anon','authenticated','service_role']) {
        denied(reset({}, `set role ${role};\n`), /permission denied|operator connection/);
        denied(psql(`set role ${role}; select private.bootstrap_team('Forged','${user(2)}');`), /permission denied/);
      }
    });
    await t.test('schema drift and nonuniform host configuration fail closed', () => {
      query('create table public.unreviewed_data(id int)');
      denied(reset(), /Unexpected application tables/);
      query('drop table public.unreviewed_data');
      query("insert into private.enterprise_hosts select id,'pr','different.example.test' from public.teams limit 1");
      denied(reset(), /different enterprise hosts/);
      query("delete from private.enterprise_hosts where hostname='different.example.test'");
    });
    await t.test('Storage object data blocks reset when Storage is present', () => {
      // Storage is disabled in the minimal local stack. Exercise the guard with
      // a sentinel relation; this does not claim a hosted Storage deletion test.
      assert.equal(query("select to_regclass('storage.objects') is null"), 't');
      const setup = docker(['exec','-i',container,'psql','-X','-qAt','-U','supabase_admin','-d',database,'-v','ON_ERROR_STOP=1'],
        'create table storage.objects(id int); grant select on storage.objects to postgres; insert into storage.objects values (1)');
      assert.equal(setup.status, 0, setup.stderr);
      try {
        denied(reset(), /Storage objects exist/);
      } finally {
        const cleanup = docker(['exec','-i',container,'psql','-X','-qAt','-U','supabase_admin','-d',database,'-v','ON_ERROR_STOP=1'], 'drop table storage.objects');
        assert.equal(cleanup.status, 0, cleanup.stderr);
      }
    });
    await t.test('failure after deletion rolls back Auth and application data', () => {
      query(`create function private.reset_test_fail() returns trigger language plpgsql as $$ begin raise exception 'injected reset failure'; end $$;
        create trigger reset_test_fail before insert on private.enterprise_hosts for each row execute function private.reset_test_fail()`);
      const rows = fingerprint();
      denied(reset(), /injected reset failure/);
      assert.deepEqual(fingerprint(), rows);
      query('drop trigger reset_test_fail on private.enterprise_hosts; drop function private.reset_test_fail()');
    });
    await t.test('busy database times out without deleting data', async () => {
      const holder = spawn('docker', ['exec','-i',container,'psql','-X','-qAt','-U','postgres','-d',database], { windowsHide:true });
      let output = '';
      holder.stdout.on('data', b => { output += b; });
      const done = new Promise(resolve => holder.on('close', resolve));
      holder.stdin.write("begin; lock public.teams in access exclusive mode; select 'LOCK_READY';\n");
      try {
        const deadline = Date.now() + 10000;
        while (!output.includes('LOCK_READY')) {
          assert.ok(Date.now() < deadline, 'Lock holder ready');
          await new Promise(r => setTimeout(r, 30));
        }
        denied(reset(), /lock timeout/);
      } finally {
        holder.stdin.end('rollback;\n');
        await done;
      }
    });
    await t.test('apply creates only the selected admin/team; old claims lose access', () => {
      const mail = query('select row_to_json(t) from private.email_quota_reservations t');
      const r = reset({ team_name: "Fresh team's queue; SELECT 'literal'" });
      assert.equal(r.status, 0, r.stderr);
      assert.match(r.stdout, /RESET COMMITTED/);
      assert.equal(query('select count(*) from auth.users'), '1');
      assert.equal(query('select id from auth.users'), user(1));
      assert.equal(query('select count(*) from auth.sessions'), '0');
      assert.equal(query('select count(*) from auth.refresh_tokens'), '0');
      assert.equal(query('select count(*) from auth.identities'), '0');
      assert.equal(query('select name from public.teams'), "Fresh team's queue; SELECT 'literal'");
      assert.equal(query('select count(*) from public.team_memberships where active and role=\'admin\''), '1');
      for (const table of ['public.profiles','public.queue_entries','public.entry_comments','public.entry_reviews',
        'public.team_invites','private.auth_trial_admissions','private.onboarding_limits','private.queue_limits']) {
        assert.equal(query(`select count(*) from ${table}`), '0', table);
      }
      assert.equal(query('select count(*) from private.enterprise_hosts'), '2');
      assert.equal(query('select action from private.audit_events'), 'operator_bootstrap');
      assert.equal(query('select row_to_json(t) from private.email_quota_reservations t'), mail);
      assert.equal(query('select count(*) from private.email_hook_events'), '1');
      assert.equal(query(security), permissions, 'RLS/grants/function definitions unchanged');
      denied(psql('set role anon; select * from public.teams'), /permission denied/);
      for (const n of [2,3,5]) { // Revoked member, foreign admin, multi-team member.
        assert.equal(query(`set role authenticated; set "request.jwt.claims"='{"sub":"${user(n)}","role":"authenticated"}'; select count(*) from public.teams`), '0');
      }
      denied(psql(`set role authenticated; set "request.jwt.claims"='{"sub":"${user(2)}","role":"authenticated"}'; insert into public.team_memberships select id,'${user(2)}','admin',true,now(),now() from public.teams`), /permission denied/);
      assert.equal(query(`set role authenticated; set "request.jwt.claims"='{"sub":"${user(1)}","role":"authenticated"}'; select count(*) from public.teams`), '1');
    });
  } finally {
    assert.match(database, /^ops01_reset_[a-f0-9]{12}$/);
    if (created) query(`drop database ${database} with (force)`, 'postgres');
  }
});

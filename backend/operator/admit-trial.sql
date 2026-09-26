-- Retained path so historical P05 commands fail closed.
\set ON_ERROR_STOP on
do $$ begin
  raise exception 'P05 trial admission is retired. Follow docs/RELEASE.md.';
end $$;

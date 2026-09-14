# Backend

Reserved for the API, database migrations, and backend tests. **Not scaffolded yet.**

The researched proposal is Supabase Postgres/Auth with row-level security, SQL functions, and TypeScript Edge Functions. Resend delivers magic links through a guarded Send Email Hook. GitHub Pages serves the public frontend; it does not replace database authorization.

Start with P03 (local database and permissions), then P04-P05 (magic-link and email-budget validation) in [NEXT](../docs/NEXT.md). Confirm the access boundary before building queue features. Docker Desktop supports the planned local Supabase stack.

See [ARCHITECTURE](../docs/ARCHITECTURE.md), [SECURITY](../docs/SECURITY.md), and [COSTS](../docs/COSTS.md). Add real setup, migration, test, and deployment commands here as each becomes available.

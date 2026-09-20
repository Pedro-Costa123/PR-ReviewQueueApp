-- Run only against the selected hosted trial, after provisioning an UNCONFIRMED
-- Auth identity. Supply slot (1-3), user_id and email through operator variables.
-- Never put real identities or substituted copies of this file in the repo.
\set ON_ERROR_STOP on
begin;
insert into private.auth_trial_admissions(slot, user_id, email)
values (:'slot'::smallint, :'user_id'::uuid, lower(btrim(:'email')));
commit;
-- Verify the identity/email pair in Auth before executing. A mismatch cannot
-- send because reserve_auth_email independently checks the live Auth record.

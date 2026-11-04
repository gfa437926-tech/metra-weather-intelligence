-- Correct the registration replay classification order. A pending request already
-- has profile/account-state rows, so pending must be checked before the generic
-- linked-account condition. This patch verifies the exact original block before
-- replacing it, and aborts if the expected definition is not present.
do $migration$
declare
  v_definition text;
  v_old text := $old$
  if exists (select 1 from public.metra_account_states s where s.user_id = p_auth_user_id)
     or exists (select 1 from public.metra_user_profiles p where p.user_id = p_auth_user_id) then
    return query select 'auth_user_already_linked'::text, null::uuid, null::uuid;
    return;
  end if;

  if exists (
    select 1 from public.registration_requests r
     where r.user_id = p_auth_user_id
       and r.status in ('pending_station_approval','pending_system_approval')
  ) then
    return query select 'existing_pending'::text, null::uuid, null::uuid;
    return;
  end if;
$old$;
  v_new text := $new$
  if exists (
    select 1 from public.registration_requests r
     where r.user_id = p_auth_user_id
       and r.status in ('pending_station_approval','pending_system_approval')
  ) then
    return query select 'existing_pending'::text, null::uuid, null::uuid;
    return;
  end if;

  if exists (select 1 from public.metra_account_states s where s.user_id = p_auth_user_id)
     or exists (select 1 from public.metra_user_profiles p where p.user_id = p_auth_user_id) then
    return query select 'auth_user_already_linked'::text, null::uuid, null::uuid;
    return;
  end if;
$new$;
begin
  select pg_get_functiondef(
    'private.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)'::regprocedure
  ) into v_definition;
  if position(v_old in v_definition)=0 then
    raise exception 'expected registration replay block not found; no function change applied';
  end if;
  v_definition := replace(v_definition,v_old,v_new);
  if position(v_new in v_definition)=0 then
    raise exception 'registration replay block replacement verification failed';
  end if;
  execute v_definition;
end
$migration$;

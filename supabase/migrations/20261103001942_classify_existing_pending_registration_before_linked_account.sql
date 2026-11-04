-- Return the correct replay outcome when an Auth user already has a pending
-- registration. Pending-request classification must precede generic linked-account
-- classification because the pending workflow intentionally creates a profile
-- and account-state row in the same transaction.
do $migration$
declare v_definition text;
begin
  select pg_get_functiondef(
    'private.submit_metra_registration(uuid,text,text,text,text,text,uuid,text,timestamptz,text)'::regprocedure
  ) into v_definition;

  v_definition := replace(
    v_definition,
    '  if exists (select 1 from public.metra_account_states s where s.user_id = p_auth_user_id)
     or exists (select 1 from public.metra_user_profiles p where p.user_id = p_auth_user_id) then
    return query select ''auth_user_already_linked''::text, null::uuid, null::uuid;
    return;
  end if;
  if exists (select 1 from public.registration_requests r where r.user_id = p_auth_user_id
      and r.status in (''pending_station_approval'',''pending_system_approval'')) then
    return query select ''existing_pending''::text, null::uuid, null::uuid;
    return;
  end if;',
    '  if exists (select 1 from public.registration_requests r where r.user_id = p_auth_user_id
      and r.status in (''pending_station_approval'',''pending_system_approval'')) then
    return query select ''existing_pending''::text, null::uuid, null::uuid;
    return;
  end if;
  if exists (select 1 from public.metra_account_states s where s.user_id = p_auth_user_id)
     or exists (select 1 from public.metra_user_profiles p where p.user_id = p_auth_user_id) then
    return query select ''auth_user_already_linked''::text, null::uuid, null::uuid;
    return;
  end if;'
  );

  if position('existing_pending' in v_definition)=0 then
    raise exception 'registration pending replay ordering hardening failed';
  end if;
  execute v_definition;
end
$migration$;

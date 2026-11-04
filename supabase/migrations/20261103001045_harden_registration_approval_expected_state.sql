-- Extend the decision RPC with an expected state so stale application-layer
-- reads can never be reinterpreted as a decision at a later approval stage.
-- Also revalidate the station and requestable role before station-stage approval.
do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'private.decide_metra_registration(uuid,uuid,text,text,timestamp with time zone)'::regprocedure
  ) into v_definition;

  v_definition := replace(
    v_definition,
    'CREATE OR REPLACE FUNCTION private.decide_metra_registration(p_request_id uuid, p_actor_user_id uuid, p_decision text, p_note text, p_occurred_at timestamp with time zone)',
    'CREATE OR REPLACE FUNCTION private.decide_metra_registration(p_request_id uuid, p_expected_status text, p_actor_user_id uuid, p_decision text, p_note text, p_occurred_at timestamp with time zone)'
  );
  v_definition := replace(
    v_definition,
    'if p_request_id is null or p_actor_user_id is null',
    'if p_request_id is null or p_expected_status not in (''pending_station_approval'',''pending_system_approval'') or p_actor_user_id is null'
  );
  v_definition := replace(
    v_definition,
    'if v_request.status not in (''pending_station_approval'',''pending_system_approval'') then',
    'if v_request.status <> p_expected_status or v_request.status not in (''pending_station_approval'',''pending_system_approval'') then'
  );
  v_definition := replace(
    v_definition,
    'if p_decision = ''approve'' then
      v_next_status := ''pending_system_approval'';',
    'if p_decision = ''approve'' then
      select s.owner_authority_id into v_authority_id
        from public.station_catalogue s
        join public.meteorological_authorities a on a.id=s.owner_authority_id
       where s.id=v_request.requested_station_id
         and s.owner_authority_id=v_request.requested_authority_id
         and s.approval_status=''approved'' and s.operational_status=''active''
         and s.is_demo=false and a.is_active=true
       for share of s,a;
      if v_authority_id is null then
        return query select ''conflict''::text,v_request.status; return;
      end if;
      perform 1 from public.metra_role_catalogue r
       where r.role_code=v_request.requested_role_code and r.is_active=true and r.is_requestable=true
       for share;
      if not found then
        return query select ''conflict''::text,v_request.status; return;
      end if;
      v_next_status := ''pending_system_approval'';'
  );

  if position('p_expected_status' in v_definition)=0
     or position('v_request.status <> p_expected_status' in v_definition)=0
     or position('select s.owner_authority_id into v_authority_id' in v_definition)=0 then
    raise exception 'approval RPC hardening transformation failed';
  end if;
  execute v_definition;
end
$migration$;

revoke all on function private.decide_metra_registration(uuid,uuid,text,text,timestamptz)
  from public,anon,authenticated,service_role,metra_api_runtime;
grant execute on function private.decide_metra_registration(uuid,text,uuid,text,text,timestamptz)
  to metra_api_runtime;

-- Atomic, server-authorized two-stage registration decisions.
alter table public.registration_audit_events
  add column decision_note text,
  add constraint registration_audit_decision_note_check
    check (decision_note is null or length(decision_note) <= 2000);

create unique index registration_audit_one_stage_decision_uq
  on public.registration_audit_events(request_id, event_type)
  where event_type in ('station_approved','station_rejected','system_approved','system_rejected');

create or replace function private.decide_metra_registration(
  p_request_id uuid,
  p_actor_user_id uuid,
  p_decision text,
  p_note text,
  p_occurred_at timestamptz
)
returns table(result_status text, resulting_status text)
language plpgsql security definer
set search_path = pg_catalog, public, private, extensions
as $$
declare
  v_request public.registration_requests%rowtype;
  v_actor_state text;
  v_station_approver uuid;
  v_authority_id uuid;
  v_permission_code text;
  v_event_type text;
  v_next_status text;
  v_account_state text;
  v_now timestamptz;
  v_locked_id uuid;
begin
  if p_request_id is null or p_actor_user_id is null
     or p_actor_user_id = '00000000-0000-0000-0000-000000000000'::uuid
     or p_decision not in ('approve','reject')
     or p_occurred_at is null
     or (p_note is not null and length(p_note) > 2000)
     or (p_note is not null and p_note ~ '[[:cntrl:]]')
     or (p_decision = 'reject' and nullif(trim(p_note), '') is null)
  then
    raise exception 'invalid registration decision' using errcode = '22023';
  end if;
  v_now := p_occurred_at;

  select r.* into v_request from public.registration_requests r
   where r.id = p_request_id for update;
  if not found then
    return query select 'not_found'::text, null::text; return;
  end if;
  if v_request.status not in ('pending_station_approval','pending_system_approval') then
    return query select 'conflict'::text, v_request.status; return;
  end if;
  if v_request.user_id = p_actor_user_id then
    return query select 'unauthorized'::text, v_request.status; return;
  end if;

  select s.account_state into v_actor_state
    from public.metra_account_states s where s.user_id = p_actor_user_id for share;
  if not found or v_actor_state <> 'active' then
    return query select 'unauthorized'::text, v_request.status; return;
  end if;
  select s.account_state into v_account_state
    from public.metra_account_states s where s.user_id = v_request.user_id for update;
  if not found or v_account_state not in ('pending_station_approval','pending_system_approval') then
    return query select 'conflict'::text, v_request.status; return;
  end if;

  if v_request.status = 'pending_station_approval' then
    v_permission_code := 'registrations.station.approve';
    v_event_type := case when p_decision = 'approve' then 'station_approved' else 'station_rejected' end;

    select g.id into v_locked_id from public.permission_grants g
     where g.user_id = p_actor_user_id and g.permission_code = v_permission_code
       and g.approval_status = 'approved' and g.revoked_at is null
       and g.valid_from <= v_now and (g.valid_to is null or g.valid_to > v_now)
     order by g.valid_from desc limit 1 for share;
    if v_locked_id is null then
      return query select 'unauthorized'::text, v_request.status; return;
    end if;

    select a.id into v_locked_id from public.station_assignments a
     where a.user_id = p_actor_user_id and a.station_id = v_request.requested_station_id
       and a.approval_status = 'approved' and a.valid_from <= v_now
       and (a.valid_to is null or a.valid_to > v_now)
     order by a.valid_from desc limit 1 for share;
    if v_locked_id is null then
      return query select 'unauthorized'::text, v_request.status; return;
    end if;

    if p_decision = 'approve' then
      v_next_status := 'pending_system_approval';
      update public.registration_requests set status=v_next_status, review_note=p_note where id=p_request_id;
      update public.metra_account_states set account_state=v_next_status, state_reason=null,
        reviewed_by=null, reviewed_at=null where user_id=v_request.user_id;
    else
      v_next_status := 'rejected';
      update public.registration_requests set status=v_next_status, reviewed_by=p_actor_user_id,
        reviewed_at=v_now, review_note=trim(p_note) where id=p_request_id;
      update public.metra_account_states set account_state='rejected', state_reason=trim(p_note),
        reviewed_by=p_actor_user_id, reviewed_at=v_now where user_id=v_request.user_id;
    end if;
  else
    v_permission_code := 'registrations.system.approve';
    v_event_type := case when p_decision = 'approve' then 'system_approved' else 'system_rejected' end;

    select g.id into v_locked_id from public.permission_grants g
     where g.user_id = p_actor_user_id and g.permission_code = v_permission_code
       and g.approval_status = 'approved' and g.revoked_at is null
       and g.valid_from <= v_now and (g.valid_to is null or g.valid_to > v_now)
     order by g.valid_from desc limit 1 for share;
    if v_locked_id is null then
      return query select 'unauthorized'::text, v_request.status; return;
    end if;

    select e.actor_user_id into v_station_approver from public.registration_audit_events e
     where e.request_id=p_request_id and e.event_type='station_approved'
     order by e.occurred_at,e.id limit 1;
    if v_station_approver is null or v_station_approver=p_actor_user_id then
      return query select 'unauthorized'::text, v_request.status; return;
    end if;

    select s.owner_authority_id into v_authority_id
      from public.station_catalogue s
      join public.meteorological_authorities a on a.id=s.owner_authority_id
     where s.id=v_request.requested_station_id
       and s.owner_authority_id=v_request.requested_authority_id
       and s.approval_status='approved' and s.operational_status='active'
       and s.is_demo=false and a.is_active=true
     for share of s,a;
    if v_authority_id is null then
      return query select 'conflict'::text,v_request.status; return;
    end if;

    perform 1 from public.metra_role_catalogue r
     where r.role_code=v_request.requested_role_code and r.is_active=true and r.is_requestable=true
     for share;
    if not found then
      return query select 'conflict'::text,v_request.status; return;
    end if;

    if p_decision='approve' then
      v_next_status := 'active';
      if exists (select 1 from public.station_assignments a
        where a.user_id=v_request.user_id and a.station_id=v_request.requested_station_id
          and a.approval_status in ('pending','approved')
          and (a.valid_to is null or a.valid_to>v_now)) then
        return query select 'conflict'::text,v_request.status; return;
      end if;
      insert into public.station_assignments(
        user_id,station_id,authority_id,assignment_role_code,approval_status,
        valid_from,requested_by,approved_by,reviewed_at,reason
      ) values (
        v_request.user_id,v_request.requested_station_id,v_authority_id,
        v_request.requested_role_code,'approved',v_now,v_request.user_id,
        p_actor_user_id,v_now,'اعتماد طلب التسجيل على مرحلتين: '||p_request_id::text
      );
      update public.registration_requests set status=v_next_status,reviewed_by=p_actor_user_id,
        reviewed_at=v_now,review_note=p_note where id=p_request_id;
      update public.metra_account_states set account_state='active',state_reason=null,
        reviewed_by=p_actor_user_id,reviewed_at=v_now where user_id=v_request.user_id;
    else
      v_next_status := 'rejected';
      update public.registration_requests set status=v_next_status,reviewed_by=p_actor_user_id,
        reviewed_at=v_now,review_note=trim(p_note) where id=p_request_id;
      update public.metra_account_states set account_state='rejected',state_reason=trim(p_note),
        reviewed_by=p_actor_user_id,reviewed_at=v_now where user_id=v_request.user_id;
    end if;
  end if;

  insert into public.registration_audit_events(
    request_id,user_id,actor_user_id,event_type,terms_version,decision_note,occurred_at
  ) values (
    p_request_id,v_request.user_id,p_actor_user_id,v_event_type,
    v_request.terms_version,nullif(trim(p_note),''),v_now
  );
  return query select 'committed'::text,v_next_status;
end;
$$;

revoke all on function private.decide_metra_registration(uuid,uuid,text,text,timestamptz)
  from public,anon,authenticated,service_role;
grant usage on schema private to metra_api_runtime;
grant execute on function private.decide_metra_registration(uuid,uuid,text,text,timestamptz)
  to metra_api_runtime;

comment on function private.decide_metra_registration(uuid,uuid,text,text,timestamptz)
  is 'Atomic two-stage registration decision. Validates active actor, explicit stage permission, station scope, distinct reviewers and current catalogue; updates account/request, creates station assignment on final approval and appends immutable audit in one transaction.';

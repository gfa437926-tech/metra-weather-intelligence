create or replace function public.metra_decide_observation(
  p_user_id uuid,
  p_station_id uuid,
  p_observation_id uuid,
  p_decision text,
  p_note text default null
) returns jsonb
language plpgsql security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.metra_observations%rowtype;
  v_permission text;
  v_status text;
begin
  if p_user_id is null or p_station_id is null or p_observation_id is null then
    raise exception 'user_station_observation_required' using errcode='22023';
  end if;
  if p_decision not in ('approve','return_for_correction') then
    raise exception 'invalid_observation_decision' using errcode='22023';
  end if;
  if p_note is not null and length(p_note)>2000 then
    raise exception 'decision_note_too_long' using errcode='22023';
  end if;
  v_permission := case when p_decision='approve' then 'observation.approve' else 'observation.return_for_correction' end;
  if not public.metra_user_has_station_permission(p_user_id,p_station_id,v_permission) then
    raise exception 'station_observation_decision_forbidden' using errcode='42501';
  end if;
  select * into v_row from public.metra_observations
   where id=p_observation_id and station_id=p_station_id for update;
  if not found then raise exception 'observation_not_found' using errcode='P0002'; end if;
  if v_row.status <> 'submitted' then
    raise exception 'observation_not_in_submitted_state' using errcode='22023';
  end if;
  v_status := case when p_decision='approve' then 'approved' else 'returned' end;
  update public.metra_observations
     set status=v_status, reviewed_by=p_user_id, reviewed_at=now(),
         review_note=nullif(btrim(p_note),''),
         updated_at=now()
   where id=p_observation_id and station_id=p_station_id;
  insert into public.metra_observation_audit_events
    (observation_id,station_id,actor_user_id,event_type,from_status,to_status,note)
  values (p_observation_id,p_station_id,p_user_id,p_decision,'submitted',v_status,nullif(btrim(p_note),''));
  return jsonb_build_object('id',p_observation_id,'status',v_status,'replayed',false);
end;
$$;
revoke all on function public.metra_decide_observation(uuid,uuid,uuid,text,text) from public, anon, authenticated, metra_api_runtime;
grant execute on function public.metra_decide_observation(uuid,uuid,uuid,text,text) to service_role;
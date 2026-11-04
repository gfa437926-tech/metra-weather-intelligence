-- Authenticated wrapper for the private two-stage approval transaction.
-- The actor is bound to auth.uid(); the database clock is authoritative.
create or replace function public.decide_metra_registration(
  p_request_id uuid,
  p_expected_status text,
  p_actor_user_id uuid,
  p_decision text,
  p_note text,
  p_occurred_at timestamptz
)
returns table(result_status text, resulting_status text)
language plpgsql
security definer
set search_path = pg_catalog, public, auth, private
as $function$
begin
  if auth.uid() is null or auth.uid() <> p_actor_user_id then
    raise exception 'registration_decision_user_mismatch' using errcode = '42501';
  end if;
  if p_expected_status not in ('pending_station_approval','pending_system_approval') then
    raise exception 'invalid_registration_stage' using errcode = '22023';
  end if;
  if p_decision not in ('approve','reject') then
    raise exception 'invalid_registration_decision' using errcode = '22023';
  end if;
  return query
    select d.result_status, d.resulting_status
      from private.decide_metra_registration(
        p_request_id, p_expected_status, p_actor_user_id,
        p_decision, p_note, clock_timestamp()
      ) d;
end;
$function$;
revoke all on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) from public;
revoke all on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) from anon;
grant execute on function public.decide_metra_registration(uuid,text,uuid,text,text,timestamptz) to authenticated;

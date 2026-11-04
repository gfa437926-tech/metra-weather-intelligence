-- Use the database clock for permission validity checks and audit timestamps.
-- The API-supplied timestamp is retained as an input contract but is not trusted
-- as the authority for grant/assignment validity.
do $migration$
declare v_definition text;
begin
  select pg_get_functiondef(
    'private.decide_metra_registration(uuid,text,uuid,text,text,timestamp with time zone)'::regprocedure
  ) into v_definition;
  v_definition := replace(v_definition,'v_now := p_occurred_at;','v_now := clock_timestamp();');
  if position('v_now := clock_timestamp();' in v_definition)=0 then
    raise exception 'database clock hardening transformation failed';
  end if;
  execute v_definition;
end
$migration$;

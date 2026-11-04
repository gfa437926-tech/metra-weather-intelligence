-- Keep permission revocation semantics consistent across API and database checks.
-- A future revocation timestamp is exclusive: the grant remains effective before it.
do $migration$
declare
  v_definition text;
  v_needle constant text := 'and g.revoked_at is null';
begin
  select pg_get_functiondef(
    'private.decide_metra_registration(uuid,text,uuid,text,text,timestamp with time zone)'::regprocedure
  ) into v_definition;

  if (length(v_definition) - length(replace(v_definition, v_needle, ''))) / length(v_needle) <> 2 then
    raise exception 'Expected exactly two permission revocation predicates in approval RPC';
  end if;

  v_definition := replace(
    v_definition,
    v_needle,
    'and (g.revoked_at is null or g.revoked_at > v_now)'
  );

  if position('g.revoked_at > v_now' in v_definition) = 0 then
    raise exception 'Scheduled permission revocation hardening failed';
  end if;

  execute v_definition;
end
$migration$;

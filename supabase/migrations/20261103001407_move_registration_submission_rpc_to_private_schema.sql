-- Move the security-definer submission function out of the exposed public schema.
revoke all on function public.submit_metra_registration(
  uuid,text,text,text,text,text,uuid,text,timestamptz,text
) from public,anon,authenticated,service_role,metra_api_runtime;

alter function public.submit_metra_registration(
  uuid,text,text,text,text,text,uuid,text,timestamptz,text
) set schema private;

grant usage on schema private to metra_api_runtime;
grant execute on function private.submit_metra_registration(
  uuid,text,text,text,text,text,uuid,text,timestamptz,text
) to metra_api_runtime;

comment on function private.submit_metra_registration(
  uuid,text,text,text,text,text,uuid,text,timestamptz,text
) is 'Atomic initial METRA registration. Callable only by the private least-privilege API runtime role; Auth subject must originate from a validated JWT.';

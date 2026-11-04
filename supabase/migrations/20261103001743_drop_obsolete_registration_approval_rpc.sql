-- Remove the superseded five-argument approval function. The only active
-- decision entry point is the six-argument expected-state RPC.
drop function private.decide_metra_registration(uuid,uuid,text,text,timestamptz);

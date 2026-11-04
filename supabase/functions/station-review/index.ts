import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { isValidStationReviewDecision } from "./validation.ts";
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,"Content-Type":"application/json; charset=utf-8"}});
const isObject=(v:unknown):v is Record<string,unknown>=>v!==null&&typeof v==="object"&&!Array.isArray(v);
Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 if(req.method!=="POST")return json({error:"method_not_allowed"},405);
 const token=(req.headers.get("Authorization")??"").replace(/^Bearer\s+/i,"");
 if(!token)return json({error:"unauthorized"},401);
 const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
 if(!url||!anon||!service)return json({error:"server_configuration_error"},500);
 const auth=createClient(url,anon,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:userData,error:userError}=await auth.auth.getUser(token);
 if(userError||!userData.user)return json({error:"unauthorized"},401);
 const actorId=userData.user.id;
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:account,error:accountError}=await admin.from("metra_account_states").select("account_state").eq("user_id",actorId).maybeSingle();
 if(accountError)return json({error:"account_check_failed"},500);
 if(account?.account_state!=="active")return json({error:"account_not_active"},403);
 const now=new Date().toISOString();
 const {data:grants,error:grantError}=await admin.from("permission_grants").select("id")
  .eq("user_id",actorId).eq("permission_code","stations.catalogue.review").eq("approval_status","approved")
  .is("revoked_at",null).lte("valid_from",now).or("valid_to.is.null,valid_to.gt."+now).limit(1);
 if(grantError)return json({error:"permission_check_failed"},500);
 if(!grants?.length)return json({error:"permission_denied",required_permission:"stations.catalogue.review"},403);
 const payload=await req.json().catch(()=>({}));
 if(!isObject(payload)||typeof payload.action!=="string")return json({error:"invalid_payload"},400);
 if(payload.action==="list"){
  // Read the entire pending queue in bounded pages; never silently cap it.
  const stations: Record<string,unknown>[]=[];
  const stationPageSize=500;
  for(let offset=0;;offset+=stationPageSize){
   const {data:page,error}=await admin.from("station_catalogue")
    .select("id,local_station_code,name_ar,name_en,station_type,approval_status,operational_status,owner_authority_id,elevation_m,timezone_name,description,submitted_at,source_system,source_table,source_record_id")
    .eq("is_demo",false).eq("approval_status","pending").order("name_ar").order("id")
    .range(offset,offset+stationPageSize-1);
   if(error)return json({error:"station_review_queue_failed"},500);
   stations.push(...(page??[]));
   if(!page||page.length<stationPageSize)break;
  }
  const ids=stations.map(s=>String(s.id));
  const coords=new Map<string,Record<string,unknown>>();
  const coordinatePageSize=1000;
  for(let offset=0;offset<ids.length;offset+=200){
   const batch=ids.slice(offset,offset+200);
   for(let pageOffset=0;;pageOffset+=coordinatePageSize){
    const {data:page,error:coordError}=await admin.from("station_coordinates")
     .select("station_id,latitude,longitude,coordinate_source,source_reference,valid_from")
     .in("station_id",batch).lte("valid_from",now).or("valid_to.is.null,valid_to.gt."+now)
     .order("valid_from",{ascending:false}).order("id",{ascending:false})
     .range(pageOffset,pageOffset+coordinatePageSize-1);
    if(coordError)return json({error:"station_coordinate_lookup_failed"},500);
    for(const c of page??[]){const id=String(c.station_id);if(coords.has(id))continue;
     const lat=Number(c.latitude),lon=Number(c.longitude);
     if(Number.isFinite(lat)&&Number.isFinite(lon)&&lat>=-90&&lat<=90&&lon>=-180&&lon<=180)coords.set(id,c);
    }
    if(!page||page.length<coordinatePageSize||batch.every(id=>coords.has(id)))break;
   }
  }
  return json({stations:stations.map(s=>({...s,current_coordinate:coords.get(String(s.id))??null})),total:stations.length});
 }
 if(payload.action==="decide"){
  if(!isValidStationReviewDecision(payload))
   return json({error:"invalid_station_review_decision"},400);
  const stationId=payload.station_id;
  const decision=payload.decision;
  const reason=payload.reason.trim();
  const {data,error}=await admin.rpc("decide_station_catalogue_review",{
   p_station_id:stationId,p_expected_status:"pending",p_actor_user_id:actorId,
   p_decision:decision,p_reason:reason,p_occurred_at:now
  });
  if(error){if(error.code==="42501")return json({error:"permission_denied"},403);
   if(error.code==="P0002")return json({error:"station_not_found"},404);
   return json({error:"station_review_decision_failed"},400);}
  const result=Array.isArray(data)?data[0]:data;
  return json({result:result??null});
 }
 return json({error:"unsupported_action"},400);
});
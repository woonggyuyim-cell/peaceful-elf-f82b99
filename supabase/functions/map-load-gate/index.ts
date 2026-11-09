const PUBLIC_KEY="sb_publishable_vsPDFkgGdUkNyHddcGCa5g_nznI41sC";
const origins=new Set(["https://woonggyuyim-cell.github.io","https://monterrey-living-map.netlify.app"]);
export async function handler(req:Request) {
  const origin=req.headers.get("Origin")||"";
  const headers={"Content-Type":"application/json","Cache-Control":"no-store","Vary":"Origin","Access-Control-Allow-Origin":origins.has(origin)?origin:"https://woonggyuyim-cell.github.io","Access-Control-Allow-Headers":"apikey,content-type,authorization,x-client-info","Access-Control-Allow-Methods":"POST,OPTIONS"};
  const reply=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers});
  if(origin&&!origins.has(origin))return reply({code:"FORBIDDEN"},403);
  if(req.method==="OPTIONS")return new Response(null,{status:204,headers});
  // Public website: validate its publishable key rather than requiring a user login.
  if(req.headers.get("apikey")!==PUBLIC_KEY)return reply({code:"UNAUTHORIZED"},401);
  if(req.method!=="POST")return reply({code:"METHOD_NOT_ALLOWED"},405);
  try {
    const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const res=await fetch(Deno.env.get("SUPABASE_URL")+"/rest/v1/rpc/reserve_map_load",{
      method:"POST",headers:{apikey:key,Authorization:"Bearer "+key,"Content-Type":"application/json"},
      body:"{}",signal:AbortSignal.timeout(10000)});
    if(!res.ok)throw new Error("database_unavailable");
    const quota=await res.json();
    if(!quota.allowed)return reply({...quota,code:"MONTHLY_LIMIT",message:"월 지도 사용량을 초과하여 지도를 표시할 수 없습니다. 다음 달에 다시 이용해 주세요."},429);
    return reply(quota);
  }catch{return reply({allowed:false,code:"UNAVAILABLE",message:"지도 사용량을 확인할 수 없어 지도를 불러오지 않았습니다. 잠시 후 새로고침해 주세요."},503);}
}
if(import.meta.main)Deno.serve(handler);

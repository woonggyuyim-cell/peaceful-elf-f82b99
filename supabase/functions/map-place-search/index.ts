const PUBLIC_KEY = "sb_publishable_vsPDFkgGdUkNyHddcGCa5g_nznI41sC";
const LIMIT = 4999;
const EXCEEDED = "월 검색 한도를 초과했습니다.";
const origins = new Set(["https://woonggyuyim-cell.github.io","https://monterrey-living-map.netlify.app"]);
const dbUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
function monthBucket() {
  const parts = new Intl.DateTimeFormat("en-US",{timeZone:"America/Los_Angeles",year:"numeric",month:"2-digit"}).formatToParts(new Date());
  return parts.find(p=>p.type==="year")!.value+"-"+parts.find(p=>p.type==="month")!.value+"-01";
}
async function db(path:string,method="GET",body?:unknown) {
  const res=await fetch(dbUrl+"/rest/v1/"+path,{method,headers:{apikey:serviceKey,Authorization:"Bearer "+serviceKey,"Content-Type":"application/json"},body:body===undefined?undefined:JSON.stringify(body)});
  if(!res.ok) throw new Error("database_unavailable");
  return res.json();
}
export async function handler(req:Request) {
  const origin=req.headers.get("Origin")||"";
  const headers={"Content-Type":"application/json","Cache-Control":"no-store","Access-Control-Allow-Origin":origins.has(origin)?origin:"https://woonggyuyim-cell.github.io","Access-Control-Allow-Headers":"apikey, authorization, content-type, x-client-info","Access-Control-Allow-Methods":"GET, POST, OPTIONS","Vary":"Origin"};
  const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
  if(origin && !origins.has(origin)) return reply({code:"FORBIDDEN"},403);
  if(req.method==="OPTIONS") return new Response(null,{status:204,headers});
  // Public website endpoint: verify the project's publishable key ourselves.
  if(req.headers.get("apikey")!==PUBLIC_KEY) return reply({code:"UNAUTHORIZED"},401);
  if(!["GET","POST"].includes(req.method)) return reply({code:"METHOD_NOT_ALLOWED"},405);
  try {
    const rows=await db("map_search_usage?month_start=eq."+monthBucket()+"&select=requests");
    const used=rows[0]?.requests||0;
    if(used>=LIMIT) return reply({code:"MONTHLY_LIMIT",message:EXCEEDED,used,limit:LIMIT},429);
    const googleKey=Deno.env.get("GOOGLE_PLACES_API_KEY");
    if(req.method==="GET") return reply({used,limit:LIMIT,configured:Boolean(googleKey)});
    const input=await req.json().catch(()=>null);
    const query=typeof input?.query==="string"?input.query.trim():"";
    if(query.length<2 || query.length>200) return reply({code:"INVALID_QUERY",message:"검색어를 2~200자로 입력하세요."},400);
    if(!googleKey) return reply({code:"NOT_CONFIGURED",message:"지도 검색을 준비 중입니다. 관리자 설정 후 이용할 수 있습니다."},503);
    const quota=await db("rpc/reserve_map_search","POST",{});
    if(!quota.allowed) return reply({code:"MONTHLY_LIMIT",message:EXCEEDED,...quota},429);
    // Reserve before the one Google call. Never retry or refund uncertain failures.
    let google;
    try {
      google=await fetch("https://places.googleapis.com/v1/places:searchText",{
        method:"POST",headers:{"Content-Type":"application/json","X-Goog-Api-Key":googleKey,
        "X-Goog-FieldMask":"places.id,places.displayName,places.formattedAddress,places.location"},
        body:JSON.stringify({textQuery:query,pageSize:5,languageCode:"es",regionCode:"MX",
          locationBias:{circle:{center:{latitude:25.65,longitude:-100.345},radius:50000}}}),
        signal:AbortSignal.timeout(15000)});
    } catch { return reply({code:"SEARCH_FAILED",message:"검색에 실패했으니 잠시 후 다시 시도해 주세요.",used:quota.used,limit:LIMIT},502); }
    if(!google.ok) return reply({code:"SEARCH_FAILED",message:"검색을 사용할 수 없으니 관리자에게 문의해 주세요.",used:quota.used,limit:LIMIT},502);
    const data=await google.json();
    const places=(data.places||[]).filter((p:any)=>Number.isFinite(p.location?.latitude)&&Number.isFinite(p.location?.longitude)).map((p:any)=>({id:p.id,name:p.displayName?.text||query,address:p.formattedAddress||"",lat:p.location.latitude,lng:p.location.longitude}));
    return reply({places,used:quota.used,limit:LIMIT});
  } catch {return reply({code:"UNAVAILABLE",message:"검색을 할 수 없으니 잠시 후 다시 시도해 주세요."},503);}
}
if(import.meta.main) Deno.serve(handler);

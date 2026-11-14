// =====================================================================
//  CAPA DE DATOS DE URANO
//  Toda la app lee de aquí. Para conectar una base de datos real cambia
//  DB_CONFIG.mode a 'rest' o 'supabase' y llena la URL. Si la conexión
//  falla, la app usa los datos de demostración y lo avisa.
// =====================================================================
const DB_CONFIG = Object.assign({
  mode: 'mock',                                   // 'mock' | 'rest' | 'supabase'
  restUrl: 'http://localhost:8000/api',           // tu API (ver DATA.md)
  supabaseUrl: 'https://TU-PROYECTO.supabase.co',
  supabaseKey: 'TU_ANON_KEY',
}, window.URANO_DB || {});

// ---------- Catálogo de biomarcadores (rango por defecto = línea base) ----------
const BM = {
  vol:  {n:'Volumen 24 h',u:'L',d:2,min:0,max:3.5,lo:1.6,hi:2.5},
  dens: {n:'Densidad específica',u:'',d:3,min:1,max:1.035,lo:1.005,hi:1.025},
  osm:  {n:'Osmolalidad',u:'mOsm/kg',d:0,min:50,max:1200,lo:300,hi:800},
  color:{n:'Color (escala 1–8)',u:'tono',d:0,min:1,max:8,lo:1,hi:4},
  ca:   {n:'Calcio urinario',u:'mg/día',d:0,min:0,max:400,lo:100,hi:250},
  ox:   {n:'Oxalato',u:'mg/día',d:0,min:0,max:60,lo:10,hi:40},
  cit:  {n:'Citrato',u:'mg/día',d:0,min:0,max:1200,lo:450,hi:1000},
  ua:   {n:'Ácido úrico',u:'mg/día',d:0,min:0,max:1000,lo:250,hi:750},
  ph:   {n:'pH',u:'',d:1,min:4.5,max:8,lo:5.8,hi:6.8},
  ntx:  {n:'NTx',u:'nmol BCE/mmol',d:0,min:0,max:100,lo:20,hi:60},
  ctx:  {n:'CTx',u:'µg/g',d:0,min:0,max:800,lo:150,hi:500},
  ohdg: {n:'8-OHdG',u:'ng/mg creat.',d:1,min:0,max:14,lo:2,hi:8},
  iso:  {n:'Isoprostanos',u:'ng/mg creat.',d:2,min:0,max:2.2,lo:.3,hi:1.2},
  leu:  {n:'Leucocitos',u:'/campo',d:0,min:0,max:15,lo:0,hi:5},
  nit:  {n:'Nitritos',bool:true},
  bld:  {n:'Sangre',bool:true},
  cort: {n:'Cortisol libre',u:'µg/día',d:0,min:0,max:120,lo:20,hi:70},
  mel:  {n:'6-sulfatoximelatonina',u:'µg/día',d:0,min:0,max:50,lo:10,hi:35},
  na:   {n:'Sodio',u:'mmol/día',d:0,min:0,max:300,lo:100,hi:200},
  k:    {n:'Potasio',u:'mmol/día',d:0,min:0,max:140,lo:50,hi:100},
  nak:  {n:'Relación Na/K',u:'',d:1,min:0,max:5,lo:1,hi:3,derived:true},
  acr:  {n:'Albúmina/creatinina',u:'mg/g',d:0,min:0,max:60,lo:0,hi:30},
  glu:  {n:'Glucosa',bool:true},
  ket:  {n:'Cetonas',bool:true},
  prot: {n:'Proteína',u:'mg/día',d:0,min:0,max:250,lo:0,hi:150},
  urea: {n:'Urea',u:'g/día',d:0,min:0,max:40,lo:12,hi:30},
  crea: {n:'Creatinina',u:'g/día',d:1,min:0,max:3,lo:1,hi:2},
};

// ---------- Contexto del usuario activo ----------
let CREW = [];          // lista de tripulantes
let MISSION = {};       // datos de la misión
let U = null;           // usuario activo: {crew, samples, recs, alerts, ranges, ...}

// ---------- Datos de demostración ----------
const MOCK = (()=>{
  const crew=[
    {id:'ana',  name:'Ana Torres', role:'Comandante',            initials:'AT',color:'#B3E9C7',age:41,weight:64,height:1.68,dose:142,hr:72,bp:'118/76',water:1700,waterGoal:2500,sleep:7.3,sessions:3,energy:58,protein:64,mood:3,
      target:{vol:1.4,dens:1.028,osm:890,color:5,ca:290,ox:42,cit:380,ph:5.9}},
    {id:'leo',  name:'Leo Park',   role:'Ingeniero de vuelo',    initials:'LP',color:'#A994E0',age:38,weight:78,height:1.80,dose:139,hr:68,bp:'122/80',water:2300,waterGoal:2700,sleep:7.0,sessions:1,energy:71,protein:55,mood:2,
      target:{ntx:64,ctx:530}},
    {id:'sami', name:'Sami Okoye', role:'Oficial médica',        initials:'SO',color:'#FFD23F',age:44,weight:70,height:1.74,dose:140,hr:81,bp:'126/82',water:2200,waterGoal:2500,sleep:5.1,sessions:4,energy:62,protein:70,mood:1,
      target:{cort:92,mel:7}},
    {id:'mateo',name:'Mateo Rojas',role:'Especialista de misión',initials:'MR',color:'#8367C7',age:35,weight:75,height:1.77,dose:188,hr:74,bp:'120/78',water:2400,waterGoal:2600,sleep:6.8,sessions:4,energy:66,protein:72,mood:2,
      target:{ohdg:11.2,iso:1.6}},
    {id:'yuki', name:'Yuki Tanaka',role:'Piloto',                initials:'YT',color:'#C2F8CB',age:36,weight:58,height:1.62,dose:141,hr:76,bp:'112/72',water:1900,waterGoal:2400,sleep:6.9,sessions:3,energy:60,protein:61,mood:2,
      target:{leu:6,nit:1}},
  ];
  const mission={name:'Artemis Gateway',day:142,total:180,doseLimit:600,start:'2026-06-26',sampleTimes:['07:30','15:30'],
    events:[{day:23,cls:'Clase C'},{day:61,cls:'Clase M'},{day:98,cls:'Clase C'},{day:131,cls:'Clase M'}]};
  const seed=s=>{let h=1779033703^s.length;for(const c of s)h=Math.imul(h^c.charCodeAt(0),3432918353),h=h<<13|h>>>19;return()=>{h=Math.imul(h^h>>>16,2246822507);h=Math.imul(h^h>>>13,3266489909);return((h^=h>>>16)>>>0)/4294967296}};
  const dateOf=day=>{const d=new Date(mission.start+'T07:30:00Z');d.setUTCDate(d.getUTCDate()+day-1);return d.toISOString()};
  function samples(c){const r=seed(c.id),N=40,base={},out=[];
    for(const [k,b] of Object.entries(BM)) if(!b.bool&&!b.derived) base[k]=b.lo+(b.hi-b.lo)*(.35+.3*r());
    for(let i=0;i<N;i++){const day=mission.day-(N-1-i),t=Math.max(0,(i-(N-6))/5),e=t*t*t,v={};
      for(const [k,b] of Object.entries(BM)){ if(b.derived) continue;
        if(b.bool){v[k]=(c.target[k]&&i===N-1)?1:0;continue}
        let x=base[k]+(r()-.5)*(b.hi-b.lo)*.06; if(c.target[k]!==undefined) x=x+(c.target[k]-x)*e;
        v[k]=+x.toFixed(b.d)}
      out.push({id:`${c.id}-${day}`,crewId:c.id,day,takenAt:dateOf(day),method:['sensor','sensor','tira','sensor','manual'][i%5],values:v})}
    return out}
  // Tripulantes agregados desde la app (se guardan en este navegador en modo demo)
  let custom=[];try{custom=JSON.parse(localStorage.getItem('urano-custom')||'[]')}catch(e){}
  const save=()=>{try{localStorage.setItem('urano-custom',JSON.stringify(custom))}catch(e){}};
  function makeSample(c,day,d={}){const r=seed(c.id+Date.now()),v={};
    for(const [k,b] of Object.entries(BM)){if(b.derived)continue;if(b.bool){v[k]=0;continue}v[k]=+(b.lo+(b.hi-b.lo)*(.35+.3*r())).toFixed(b.d)}
    if(d.volume_ml&&d.fluids_ml!==undefined) v.vol=+Math.max(1,Math.min(3,1.2+d.fluids_ml/1000)).toFixed(2);
    return {id:`${c.id}-${Date.now()}`,crewId:c.id,day,takenAt:new Date().toISOString(),method:d.method||'sensor',values:v}}
  const R=(id,m,p,t,w,done=false)=>({id,module:m,priority:p,text:t,why:w,done});
  const recs={
    ana:[R('ana1','hidratacion','Alta','Toma 500 ml de agua en las próximas 2 horas','Tu densidad urinaria es 1.028, por encima de tu rango personal (1.005–1.025).'),
         R('ana2','renal','Alta','Sube tu meta de líquidos a 2.5 L hoy','El calcio urinario alto con poco volumen eleva la saturación de oxalato de calcio.'),
         R('ana3','osea','Media','Haz tu sesión de resistencia pendiente','Llevas 3 de 4 sesiones esta semana. El ejercicio con carga frena la resorción ósea.'),
         R('ana4','radiacion','Baja','Incluye frutos rojos o tomate en la cena','Los antioxidantes ayudan a mantener estable tu marcador de daño oxidativo.'),
         R('ana5','cardio','Baja','Elige raciones bajas en sodio hoy','Mantener el sodio en rango protege tu balance de líquidos.',true)],
    leo:[R('leo1','osea','Alta','Completa 2 sesiones de resistencia antes del domingo','Tu NTx subió a 64, por encima de tu rango (20–60): tus huesos pierden mineral más rápido.'),
         R('leo2','osea','Media','Toma tu suplemento de vitamina D con el almuerzo','La vitamina D ayuda a fijar el calcio en el hueso.'),
         R('leo3','metabolismo','Media','Añade una ración de proteína en la cena','Tu consumo de proteína quedó 45 % bajo la meta y el músculo protege el hueso.'),
         R('leo4','hidratacion','Baja','Mantén tus 2.7 L de agua al día','El calcio que pierde el hueso sale por la orina; el agua lo diluye.')],
    sami:[R('sami1','estres','Alta','Apaga las pantallas una hora antes de dormir','Tu melatonina bajó a 7 µg/día y dormiste 5 h 6 min anoche.'),
          R('sami2','estres','Alta','Haz 5 minutos de respiración guiada ahora','Tu cortisol libre está en 92 µg/día, por encima de tu rango (20–70).'),
          R('sami3','estres','Media','Programa una llamada con tu familia','El contacto con personas cercanas reduce el estrés del aislamiento.'),
          R('sami4','inmunidad','Baja','Pide al comandante ajustar tu turno de mañana','El estrés sostenido debilita las defensas; descansar ayuda a prevenirlo.')],
    mateo:[R('mateo1','radiacion','Alta','Quédate en la zona blindada las próximas 12 horas','Tu 8-OHdG subió a 11.2, el valor más alto de la tripulación, tras tu última caminata espacial.'),
           R('mateo2','radiacion','Alta','Pospón tu próxima caminata espacial (EVA)','Tu dosis acumulada es 188 mSv; tu cuerpo necesita tiempo para reparar el daño.'),
           R('mateo3','radiacion','Media','Aumenta los antioxidantes: frutos rojos y tomate','Tus isoprostanos (1.6) muestran estrés oxidativo alto.')],
    yuki:[R('yuki1','inmunidad','Alta','Toma una muestra de control mañana a las 07:00','Nitritos positivos y 6 leucocitos por campo pueden indicar una infección urinaria.'),
          R('yuki2','inmunidad','Alta','Avisa a Sami Okoye, oficial médica','Una infección se trata mejor si se detecta temprano.'),
          R('yuki3','hidratacion','Media','Bebe 500 ml extra hoy','Más volumen de orina ayuda a eliminar bacterias.')],
  };
  const A=(id,s,m,t,c,a,h,st)=>({id,severity:s,module:m,title:t,cause:c,action:a,time:h,status:st});
  const alerts={
    ana:[A('ana-a1','warn','renal','Riesgo renal moderado','Calcio urinario alto y volumen bajo en tu última muestra.','Sube tu meta de líquidos a 2.5 L y revisa la próxima muestra.','Hoy 07:32','active'),
         A('ana-a2','warn','hidratacion','Hidratación baja','Densidad urinaria de 1.028, sobre tu rango personal.','Toma 500 ml en las próximas 2 horas.','Hoy 07:32','active'),
         A('ana-a3','crit','radiacion','Evento solar de clase M','Aumento de partículas solares durante 3 horas.','Refugio completado. Dosis extra: 1.2 mSv.','Día 131','resolved')],
    leo:[A('leo-a1','warn','osea','Resorción ósea alta','NTx y CTx por encima de tu rango en la última muestra.','Completa tus sesiones de resistencia esta semana.','Hoy 07:35','active')],
    sami:[A('sami-a1','warn','estres','Estrés y sueño fuera de rango','Cortisol alto y melatonina baja; dormiste 5 h anoche.','Prioriza el descanso esta noche y haz respiración guiada.','Hoy 07:28','active')],
    mateo:[A('mateo-a1','crit','radiacion','Daño oxidativo alto','8-OHdG de 11.2 tras tu caminata espacial del día 141.','Quédate en la zona blindada y pospón tu próxima EVA.','Hoy 07:40','active'),
           A('mateo-a2','crit','radiacion','Evento solar de clase M','Aumento de partículas solares durante 3 horas.','Refugio completado. Dosis extra: 1.4 mSv.','Día 131','resolved')],
    yuki:[A('yuki-a1','warn','inmunidad','Posible infección urinaria','Nitritos positivos y leucocitos sobre tu rango.','Muestra de control mañana y aviso a la oficial médica.','Hoy 07:31','active')],
  };
  const clone=o=>JSON.parse(JSON.stringify(o));
  return {
    async crew(){return clone(crew.map(({target,...c})=>c).concat(custom.map(x=>x.crew)))},
    async mission(){return clone(mission)},
    async user(id){const cu=custom.find(x=>x.crew.id===id);if(cu)return clone({crew:cu.crew,samples:cu.samples,recs:[],alerts:[],ranges:{}});
      const c=crew.find(x=>x.id===id)||crew[0];const {target,...info}=c;
      return {crew:clone(info),samples:samples(c),recs:clone(recs[c.id]||[]),alerts:clone(alerts[c.id]||[]),ranges:{}}},
    async setRec(){},async addWater(){},async resolveAlert(){},
    async addCrew(c){custom.push({crew:c,samples:[]});save()},
    // En modo demo solo los tripulantes nuevos reciben muestras simuladas (los 5 del equipo ya traen su historial).
    async saveSample(crewId,d){const cu=custom.find(x=>x.crew.id===crewId);if(!cu)return;const sm=makeSample(cu.crew,mission.day,d);cu.samples.push(sm);save();return sm},
    isCustom:id=>custom.some(x=>x.crew.id===id),
    _raw:{crew,recs,alerts,samples,mission},
  };
})();

// ---------- Adaptador REST (tu propia API) ----------
const REST = (()=>{
  const j=async(path,opt={})=>{const r=await fetch(DB_CONFIG.restUrl+path,{headers:{'Content-Type':'application/json'},...opt});if(!r.ok)throw new Error(`${r.status} en ${path}`);return r.status===204?null:r.json()};
  const send=(m,path,body)=>j(path,{method:m,body:JSON.stringify(body)});
  return {
    crew:()=>j('/crew'), mission:()=>j('/mission'),
    async user(id){const [crew,samples,recs,alerts,ranges]=await Promise.all([j(`/crew/${id}`),j(`/crew/${id}/samples`),j(`/crew/${id}/recommendations`),j(`/crew/${id}/alerts`),j(`/crew/${id}/ranges`).catch(()=>({}))]);return {crew,samples,recs,alerts,ranges}},
    setRec:(id,done)=>send('PATCH',`/recommendations/${id}`,{done}),
    addWater:(crewId,ml)=>send('POST',`/crew/${crewId}/water`,{ml}),
    resolveAlert:id=>send('PATCH',`/alerts/${id}`,{status:'resolved'}),
    saveSample:(crewId,data)=>send('POST',`/crew/${crewId}/samples`,data),
    addCrew:c=>send('POST','/crew',c),
  };
})();

// ---------- Adaptador Supabase (PostgREST, sin librerías) ----------
const SUPA = (()=>{
  const h=()=>({apikey:DB_CONFIG.supabaseKey,Authorization:'Bearer '+DB_CONFIG.supabaseKey,'Content-Type':'application/json'});
  const q=async path=>{const r=await fetch(`${DB_CONFIG.supabaseUrl}/rest/v1/${path}`,{headers:h()});if(!r.ok)throw new Error(`${r.status} en ${path}`);return r.json()};
  const send=(m,path,body)=>fetch(`${DB_CONFIG.supabaseUrl}/rest/v1/${path}`,{method:m,headers:{...h(),Prefer:'return=minimal'},body:JSON.stringify(body)});
  const crewRow=c=>({id:c.id,name:c.name,role:c.role,initials:c.initials,color:c.color,age:c.age,weight:c.weight_kg,height:c.height_m,dose:c.dose_msv,hr:c.heart_rate,bp:c.blood_pressure,
    water:c.water_ml_today,waterGoal:c.water_goal_ml,sleep:c.sleep_hours,sessions:c.resistance_sessions_week,energy:c.energy_pct,protein:c.protein_pct,mood:c.mood});
  return {
    async crew(){return (await q('crew?select=*&order=sort_order')).map(crewRow)},
    async mission(){const m=(await q('mission?select=*,solar_events(day,class)&limit=1'))[0];return {name:m.name,day:m.current_day,total:m.total_days,doseLimit:m.dose_limit_msv,start:m.start_date,sampleTimes:m.sample_times,events:(m.solar_events||[]).map(e=>({day:e.day,cls:e.class}))}},
    async user(id){
      const [c,s,r,a,g]=await Promise.all([q(`crew?id=eq.${id}`),q(`samples?crew_id=eq.${id}&select=id,mission_day,taken_at,method,sample_values(biomarker_id,value)&order=taken_at`),
        q(`recommendations?crew_id=eq.${id}&order=created_at`),q(`alerts?crew_id=eq.${id}&order=created_at.desc`),q(`personal_ranges?crew_id=eq.${id}`)]);
      return {crew:crewRow(c[0]),
        samples:s.map(x=>({id:x.id,crewId:id,day:x.mission_day,takenAt:x.taken_at,method:x.method,values:Object.fromEntries(x.sample_values.map(v=>[v.biomarker_id,+v.value]))})),
        recs:r.map(x=>({id:x.id,module:x.module,priority:x.priority,text:x.text,why:x.why,done:x.done})),
        alerts:a.map(x=>({id:x.id,severity:x.severity,module:x.module,title:x.title,cause:x.cause,action:x.action,time:x.time_label,status:x.status})),
        ranges:Object.fromEntries(g.map(x=>[x.biomarker_id,{lo:+x.lo,hi:+x.hi}]))}},
    setRec:(id,done)=>send('PATCH',`recommendations?id=eq.${id}`,{done}),
    addWater:(crewId,ml)=>send('POST','water_log',{crew_id:crewId,ml}),
    resolveAlert:id=>send('PATCH',`alerts?id=eq.${id}`,{status:'resolved'}),
    saveSample:(crewId,d)=>send('POST','sample_requests',{crew_id:crewId,payload:d}),
    addCrew:async c=>{const r=await send('POST','crew',{id:c.id,sort_order:99,name:c.name,role:c.role,initials:c.initials,color:c.color,age:c.age,weight_kg:c.weight,height_m:c.height,dose_msv:c.dose,heart_rate:c.hr,blood_pressure:c.bp,
      water_ml_today:c.water,water_goal_ml:c.waterGoal,sleep_hours:c.sleep,resistance_sessions_week:c.sessions,energy_pct:c.energy,protein_pct:c.protein,mood:c.mood});if(!r.ok)throw new Error('No se pudo crear el tripulante')},
  };
})();

// ---------- Fachada ----------
const DB = {
  source:'demo', error:null, api:MOCK,
  async init(){
    const pick={rest:REST,supabase:SUPA}[DB_CONFIG.mode];
    if(pick){ try{ CREW=await pick.crew(); MISSION=await pick.mission(); DB.api=pick; DB.source='db'; return; }
      catch(e){ DB.error=e.message; console.warn('URANO: no se pudo conectar, uso datos demo.',e); } }
    DB.api=MOCK; DB.source='demo'; CREW=await MOCK.crew(); MISSION=await MOCK.mission();
  },
  // (MISSION.sampleTimes = horas programadas de muestra; por defecto 07:30 y 15:30)
  cache:{},
  async loadUser(id){ const d=await DB.api.user(id);
    d.samples.sort((a,b)=>a.takenAt<b.takenAt?-1:1);
    DB.cache[id]={...d.crew, samples:d.samples, recs:d.recs, alerts:d.alerts, ranges:d.ranges||{}}; return DB.cache[id]; },
  async loadAll(){ await Promise.all(CREW.map(c=>DB.loadUser(c.id))); },
  use(id){ U=DB.cache[id]||DB.cache[CREW[0].id]; try{localStorage.setItem('urano-user',U.id)}catch(e){} return U; },
  async addCrew(c){ await DB.api.addCrew(c); CREW.push(c); await DB.loadUser(c.id); return c; },
  async saveSample(d){ U.lastSubmit=Date.now(); const out=await DB.api.saveSample(U.id,d);
    if(DB.source==='db'||MOCK.isCustom(U.id)){ const old=U,id=U.id; await DB.loadUser(id); DB.use(id);
      for(const k of ['water','waterGoal','sleep','sessions','energy','protein','mood','lastSubmit']) U[k]=old[k]; }
    return out; },
  run(fn,...a){ Promise.resolve(DB.api[fn](...a)).catch(e=>{console.warn(e);toast('No se pudo guardar en la base de datos','alc')}); },
};

// ---------- Lecturas derivadas ----------
const S_LAST=()=>U.samples.length-1;
function val(k,i=S_LAST()){const s=U.samples[i];if(!s)return null;if(k==='nak')return s.values.k?+(s.values.na/s.values.k).toFixed(1):null;return s.values[k]}
function rangeOf(k){return U.ranges[k]||{lo:BM[k].lo,hi:BM[k].hi}}
function sevOf(k,i=S_LAST()){const b=BM[k],v=val(k,i);if(v==null)return 'ok';if(b.bool)return v?'warn':'ok';const {lo,hi}=rangeOf(k);
  if(v>hi*1.35||(lo>0&&v<lo*.65))return 'crit';return (v<lo||v>hi)?'warn':'ok'}
function bmObj(k,i=S_LAST()){const b=BM[k],v=val(k,i);if(b.bool)return {n:b.n,t:v?'Positivo':'Negativo',bad:!!v};
  const {lo,hi}=rangeOf(k);return {n:b.n,v,u:b.u,d:b.d,lo,hi,min:b.min,max:b.max,p:val(k,i-1)??v}}
function series(k,n){return U.samples.slice(-n).map((_,j,a)=>val(k,U.samples.length-a.length+j))}
const fx=(k,v=val(k))=>v==null?'—':(+v).toFixed(BM[k].d??0);
const SEV=['ok','warn','crit'];
const worst=list=>list.reduce((a,b)=>SEV.indexOf(b)>SEV.indexOf(a)?b:a,'ok');

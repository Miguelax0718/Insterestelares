// ---------- Icons ----------
const ICONS={
  drop:'<path d="M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"/>',
  kidney:'<path d="M9 3C5.5 3 4 6.5 4 10s1.5 11 7 11c2.5 0 3.5-2 3-4-.4-1.6-2-2.2-2-4s1.6-2.4 2-4c.5-2.4-1.4-6-5-6z"/><path d="M17 8c1.7 1 3 2.5 3 5"/>',
  bone:'<path d="M17 10c.7-.7 1.69 0 2.5 0a2.5 2.5 0 1 0 0-5 .5.5 0 0 1-.5-.5 2.5 2.5 0 1 0-5 0c0 .81.7 1.8 0 2.5l-7 7c-.7.7-1.69 0-2.5 0a2.5 2.5 0 0 0 0 5c.28 0 .5.22.5.5a2.5 2.5 0 1 0 5 0c0-.81-.7-1.8 0-2.5Z"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>',
  shield:'<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>',
  heart:'<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
  moon:'<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
  food:'<path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2M7 2v20M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"/>',
  grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  flask:'<path d="M10 2v7.31M14 9.3V2M8.5 2h7M14 9.3a6.5 6.5 0 1 1-4 0M5.52 16h12.96"/>',
  orbit:'<circle cx="12" cy="12" r="3"/><path d="M20.2 20.2c2-2 .1-7.1-4.2-11.4S6.8 1.8 4.8 3.8 4.7 10.9 9 15.2s9.2 7 11.2 5z"/>',
  spark:'<path d="M9.94 15.5A2 2 0 0 0 8.5 14.06l-6.14-1.58a.5.5 0 0 1 0-.96L8.5 9.94A2 2 0 0 0 9.94 8.5l1.58-6.14a.5.5 0 0 1 .96 0L14.06 8.5a2 2 0 0 0 1.44 1.44l6.14 1.58a.5.5 0 0 1 0 .96l-6.14 1.58a2 2 0 0 0-1.44 1.44l-1.58 6.14a.5.5 0 0 1-.96 0z"/>',
  history:'<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5M12 7v5l4 2"/>',
  bell:'<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  user:'<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  check:'<path d="M20 6 9 17l-5-5"/>',
  down:'<path d="m6 9 6 6 6-6"/>',
  left:'<path d="m15 18-6-6 6-6"/>',
  right:'<path d="m9 18 6-6-6-6"/>',
  tri:'<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3M12 9v4M12 17h.01"/>',
  okc:'<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
  alc:'<circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>',
  sat:'<path d="M13 7 9 3 5 7l4 4M17 11l4 4-4 4-4-4M8 12l4 4 6-6-4-4Z"/><path d="m16 8 3-3M9 21a6 6 0 0 0-6-6"/>',
  menu:'<path d="M3 12h18M3 6h18M3 18h18"/>',
  up:'<path d="M12 19V5M5 12l7-7 7 7"/>',
  dn:'<path d="M12 5v14M19 12l-7 7-7-7"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  minus:'<path d="M5 12h14"/>',
  cam:'<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"/><circle cx="12" cy="13" r="3"/>',
  cpu:'<rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M15 2v2M15 20v2M2 15h2M2 9h2M20 15h2M20 9h2M9 2v2M9 20v2"/>',
  pencil:'<path d="M21.17 6.81a1 1 0 0 0-3.99-3.99L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z"/>',
  dl:'<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>',
  x:'<path d="M18 6 6 18M6 6l12 12"/>',
  wind:'<path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2M9.6 4.6A2 2 0 1 1 11 8H2M12.6 19.4A2 2 0 1 0 14 16H2"/>',
  run:'<circle cx="13" cy="4" r="2"/><path d="m4 17 4-1 2-4 4 3v5M8 9l3-2 4 2 2 3h3"/>',
  bike:'<circle cx="5.5" cy="17.5" r="3.5"/><circle cx="18.5" cy="17.5" r="3.5"/><path d="M15 6a1 1 0 1 0 0-2 1 1 0 0 0 0 2zm-3 11.5V14l-3-3 4-3 2 3h2"/>',
  dumb:'<path d="M6.5 6.5v11M17.5 6.5v11M3 9.5v5M21 9.5v5M6.5 12h11"/>',
  phone:'<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.79 19.79 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/>',
  clock:'<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
  filter:'<path d="M22 3H2l8 9.46V19l4 2v-8.54L22 3z"/>',
  play:'<path d="M7 4v16l13-8z" fill="currentColor"/>',
  pause:'<rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor"/><rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor"/>',
  grip:'<circle cx="9" cy="6" r="1.4" fill="currentColor"/><circle cx="15" cy="6" r="1.4" fill="currentColor"/><circle cx="9" cy="12" r="1.4" fill="currentColor"/><circle cx="15" cy="12" r="1.4" fill="currentColor"/><circle cx="9" cy="18" r="1.4" fill="currentColor"/><circle cx="15" cy="18" r="1.4" fill="currentColor"/>',
  eye:'<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  eyeoff:'<path d="M9.9 4.24A9.1 9.1 0 0 1 12 4c6.5 0 10 8 10 8a18.5 18.5 0 0 1-2.16 3.19M6.6 6.6A18.4 18.4 0 0 0 2 12s3.5 7 10 7a9.7 9.7 0 0 0 5.4-1.6M2 2l20 20"/>',
  sliders:'<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
  i_water:'<path d="M5 3h14l-1.6 16.2A2 2 0 0 1 15.4 21H8.6a2 2 0 0 1-2-1.8z"/><path d="M5.6 9h12.8"/><path d="M12 12.2c-1.2 1.5-1.8 2.5-1.8 3.3a1.8 1.8 0 0 0 3.6 0c0-.8-.6-1.8-1.8-3.3z"/>',
  i_kidney:'<path d="M15 3c-3.5 0-6 3-6 6.5 0 1.6 1.4 2.2 1.4 3.5S8 14.5 8 16.8C8 19.6 10.2 21 12.6 21 17.3 21 20 16.5 20 11.3 20 6.5 18.2 3 15 3z"/><path d="M10.2 13H6.5A2.5 2.5 0 0 0 4 15.5V21"/>',
  i_rad:'<path d="M7.20 3.69A9.6 9.6 0 0 1 16.80 3.69L13.70 9.06A3.4 3.4 0 0 0 10.30 9.06ZM21.60 12.00A9.6 9.6 0 0 1 16.80 20.31L13.70 14.94A3.4 3.4 0 0 0 15.40 12.00ZM7.20 20.31A9.6 9.6 0 0 1 2.40 12.00L8.60 12.00A3.4 3.4 0 0 0 10.30 14.94Z" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.9" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="10.6"/>',
  i_virus:'<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="M12 8.5v7M8.5 12h7"/>',
  i_heart:'<path d="M19.5 13.5C21 12 22 10.4 22 8.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 1.9 1 3.5 2.5 5L12 21z"/><path d="M3.5 12h4l1.5-3 3 6 1.8-3.5H20.5"/>',
  i_sleep:'<path d="M12.5 4a7.5 7.5 0 1 0 7.5 9.5A6 6 0 0 1 12.5 4z"/><path d="M15 3h4l-4 4h4M19.5 9h2.5l-2.5 2.5H22"/>',
  i_bolt:'<path d="M13 2 4.5 13.5H11L10 22l8.5-11.5H12z"/>',
  i_bone:'<path d="M7.5 9.5 14.5 16.5"/><path d="M8.6 10.6a2.6 2.6 0 1 1-3.4-3.4 2.6 2.6 0 1 1 3.4-3.4 2.6 2.6 0 0 1 2.4 2.9l3 3a2.6 2.6 0 0 1 2.9 2.4 2.6 2.6 0 1 1 3.4 3.4 2.6 2.6 0 1 1-3.4 3.4 2.6 2.6 0 0 1-2.4-2.9l-3-3a2.6 2.6 0 0 1-2.9-2.4z"/>',
  paw:'<circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="4" cy="8" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.05Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z"/>',
  mic:'<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M19 10v1a7 7 0 0 1-14 0v-1M12 18v4M8 22h8"/>',
  send:'<path d="M14.54 21.69a.5.5 0 0 0 .94-.03l6.5-19a.5.5 0 0 0-.64-.64l-19 6.5a.5.5 0 0 0-.03.94l7.93 3.18a2 2 0 0 1 1.11 1.11zM21.85 2.15 10.91 13.09"/>',
  vol:'<path d="M11 4.7a.7.7 0 0 0-1.2-.5L6.4 7.6A1.4 1.4 0 0 1 5.4 8H3a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2.4a1.4 1.4 0 0 1 1 .4l3.4 3.4a.7.7 0 0 0 1.2-.5zM16 9a5 5 0 0 1 0 6M19.4 18.4a9 9 0 0 0 0-12.8"/>',
  contrast:'<circle cx="12" cy="12" r="10"/><path d="M12 18a6 6 0 0 0 0-12v12z" fill="currentColor"/>',
};
const ic=(n,s=20,st='')=>`<svg class="i" viewBox="0 0 24 24" style="width:${s}px;height:${s}px;${st}">${ICONS[n]||''}</svg>`;
const $=(s,r=document)=>r.querySelector(s), $$=(s,r=document)=>[...r.querySelectorAll(s)];

// ---------- Estado de la interfaz ----------
const S={storm:false};
// ---------- Modules (todo se calcula desde las muestras) ----------
const hm=h=>`${Math.floor(h)} h ${String(Math.round(h%1*60)).padStart(2,'0')} min`;
function renalRisk(){const ks=['ca','ox','cit','ph','vol'];const sv=ks.map(k=>sevOf(k));const n=sv.filter(x=>x!=='ok').length;const crit=sv.includes('crit');
  return {n,label:crit||n>=5?'Alto':n>=2?'Moderado':'Bajo',score:Math.min(1,n/5*.8+(crit?.2:0)),out:ks.filter((k,i)=>sv[i]!=='ok'),inr:ks.filter((k,i)=>sv[i]==='ok').concat(['ua'].filter(k=>sevOf(k)==='ok'))}}
function resorp(){const f=series('ntx',U.samples.length).slice(0,10).map(Number);const b=f.reduce((a,x)=>a+x,0)/(f.length||1),c=val('ntx');return b?Math.round((c/b-1)*100):0}
function infection(){return !!(val('nit')||val('bld')||sevOf('leu')!=='ok')}
function sleepQ(){const s=U.sleep,m=sevOf('mel');return s>=7&&m==='ok'?{w:'bueno',ph:1}:s>=6?{w:'regular',ph:.62}:{w:'malo',ph:.3}}
const stressQ=()=>sevOf('cort')==='ok'?'bajo':'alto';
const MODS=[
 {id:'hidratacion',name:'Hidratación',icon:'i_water',measures:'Cuánta agua tiene tu cuerpo según la concentración de la orina',bms:['vol','dens','osm','color'],primary:'vol',
  key:()=>`${(U.water/1000).toFixed(1)} L`,sub:()=>`de ${(U.waterGoal/1000).toFixed(1)} L hoy`,
  why:'En microgravedad la sensación de sed disminuye y el agua del sistema de reciclaje es limitada. Beber poco concentra la orina y aumenta el riesgo de cálculos renales.',rel:['renal','cardio']},
 {id:'renal',name:'Riesgo renal',icon:'i_kidney',measures:'Probabilidad de formar cálculos según los minerales de la orina',bms:['ca','ox','cit','ua','ph','vol'],primary:'ca',
  key:()=>renalRisk().label,sub:()=>{const n=renalRisk().n;return n?`${n} factor${n>1?'es':''} fuera de rango`:'todo en rango'},
  why:'La pérdida ósea en microgravedad libera calcio que sale por la orina. Si además hay poco líquido, el calcio se concentra y forma cristales. Un cálculo en plena misión es una emergencia difícil de tratar.',rel:['hidratacion','osea']},
 {id:'osea',name:'Salud ósea',icon:'i_bone',measures:'Ritmo al que tus huesos pierden mineral',bms:['ntx','ctx'],primary:'ntx',
  key:()=>`${resorp()>=0?'+':''}${resorp()} %`,sub:()=>'resorción vs. línea base',
  why:'Sin la carga de la gravedad, los huesos pierden entre 1 y 1,5 % de su masa por mes. El ejercicio de resistencia diario es la principal defensa.',rel:['renal','metabolismo']},
 {id:'radiacion',name:'Radiación',icon:'i_rad',measures:'Dosis acumulada y respuesta de tu cuerpo al daño oxidativo',bms:['ohdg','iso'],primary:'ohdg',
  key:()=>`${U.dose} mSv`,sub:()=>`de ${MISSION.doseLimit} mSv de límite`,
  why:'Fuera de la protección de la Tierra, los rayos cósmicos y las tormentas solares dañan el ADN. La orina muestra cuánto daño oxidativo está reparando tu cuerpo.',rel:['inmunidad']},
 {id:'inmunidad',name:'Inmunidad',icon:'i_virus',measures:'Señales de infección y estado de tus defensas',bms:['leu','nit','bld'],primary:'leu',
  key:()=>infection()?'En vigilancia':'Estable',sub:()=>infection()?'posible infección urinaria':'sin signos de infección',
  why:'El aislamiento, el estrés y la radiación debilitan el sistema inmune, y algunos virus latentes pueden reactivarse. Detectar una infección temprano evita complicaciones.',rel:['estres','radiacion']},
 {id:'cardio',name:'Cardiovascular',icon:'i_heart',measures:'Balance de sales y líquidos que afectan tu corazón',bms:['na','k','nak','acr'],primary:'na',
  key:()=>`Na/K ${fx('nak')}`,sub:()=>'balance de sales',
  why:'En microgravedad los líquidos suben hacia la cabeza y el corazón trabaja distinto. El exceso de sodio retiene líquido y sobrecarga el sistema.',rel:['hidratacion']},
 {id:'estres',name:'Estrés y sueño',icon:'i_sleep',measures:'Hormonas de estrés y de sueño, más tu propio registro',bms:['cort','mel'],primary:'cort',
  key:()=>hm(U.sleep).replace(' min',' m'),sub:()=>`sueño ${sleepQ().w} · estrés ${stressQ()}`,
  why:'Meses de aislamiento, ciclos de luz alterados y una carga de trabajo alta afectan el sueño y el ánimo. Cuidarlos protege tu rendimiento y tu salud.',rel:['inmunidad']},
 {id:'metabolismo',name:'Metabolismo',icon:'i_bolt',measures:'Energía y nutrientes que tu cuerpo está usando',bms:['glu','ket','prot','urea','crea'],primary:'prot',
  key:()=>val('ket')?'Cetonas':'Sin cetonas',sub:()=>val('ket')?'energía insuficiente':'energía suficiente',
  why:'Comer menos de lo necesario es común en misiones largas. Si falta energía, el cuerpo usa músculo y grasa, y aparecen cetonas en la orina.',rel:['osea','cardio']},
];
const MOD=Object.fromEntries(MODS.map(m=>[m.id,m]));
function status(id,i=S_LAST()){const m=MOD[id];let s=worst(m.bms.map(k=>sevOf(k,i)));
  if(i===S_LAST()){ if(id==='hidratacion'&&U.water>=U.waterGoal) s='ok'; if(id==='radiacion'&&S.storm) s='crit'; } return s}
const crewStatus=()=>worst(MODS.map(m=>status(m.id)));
const SC={ok:'#5BE38C',warn:'#FFD23F',crit:'#FF5A5F'}; // código de emergencia: verde, amarillo, rojo
const ST={ok:['ok','okc','Estable'],warn:['warn','tri','Atención'],crit:['crit','alc','Crítico']};
const chip=(s,extra='',label)=>{const [c,i,w]=ST[s];return `<span class="chip ${c} ${extra}">${ic(i,15)}${label||w}</span>`};
const sevOrder={crit:0,warn:1,ok:2};
const PRIO={Alta:0,Media:1,Baja:2};
const activeAlerts=()=>U.alerts.filter(a=>a.status==='active');

// ---------- Helpers ----------
function spark(vals,w=120,h=36,col='var(--lav2)'){
  if(vals.length<2) vals=[vals[0]??0,vals[0]??0];
  const mn=Math.min(...vals),mx=Math.max(...vals),sp=mx-mn||1;
  const pts=vals.map((v,i)=>[i*(w/(vals.length-1)),h-4-(v-mn)/sp*(h-8)]);
  return `<svg width="100%" height="${h}" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" class="chart"><path class="line" d="M${pts.map(p=>p.join(' ')).join('L')}" fill="none" stroke="${col}" stroke-width="2" stroke-linecap="round"/><circle cx="${pts.at(-1)[0]}" cy="${pts.at(-1)[1]}" r="3" fill="${col}"/></svg>`;
}
function fmt(b){return b.d!==undefined?(+b.v).toFixed(b.d):b.v}
// ---------- Horario de muestras y cuenta regresiva ----------
function sampleSlots(now=new Date()){
  const t=(MISSION.sampleTimes&&MISSION.sampleTimes.length?MISSION.sampleTimes:['07:30','15:30']).map(s=>s.split(':').map(Number)).sort((a,b)=>a[0]*60+a[1]-(b[0]*60+b[1]));
  const at=(off,[h,m])=>{const x=new Date(now);x.setDate(x.getDate()+off);x.setHours(h,m,0,0);return x};
  const all=[-1,0,1].flatMap(o=>t.map(hm=>at(o,hm)));
  return {prev:[...all].reverse().find(d=>d<=now),next:all.find(d=>d>now)};
}
const hhmm=d=>d.toLocaleTimeString('es-CO',{hour:'2-digit',minute:'2-digit',hour12:false});
function fmtDur(ms){const m=Math.max(0,Math.round(ms/60000));if(m<1)return 'menos de 1 min';const h=Math.floor(m/60),r=m%60;return h?`${h} h${r?` ${r} min`:''}`:`${r} min`}
function sampleState(){const now=new Date(),{prev,next}=sampleSlots(now);
  const last=U.lastSubmit||(U.samples.length?Date.parse(U.samples.at(-1).takenAt):0);
  const due=!U.samples.length||last<prev.getTime();
  const dayWord=d=>d.toDateString()===now.toDateString()?'hoy':'mañana';
  const span=next-prev, pct=due?1:Math.min(1,Math.max(0,(now-prev)/span));
  return {due,first:!U.samples.length,prev,next,pct,
    short:due?'Ahora':(()=>{const m=Math.max(1,Math.round((next-now)/60000)),h=Math.floor(m/60);return h?`${h}h ${m%60}m`:`${m}m`})(),
    title:due?(U.samples.length?'Es hora de tu muestra':'Registra tu primera muestra'):`Próxima muestra en ${fmtDur(next-now)}`,
    sub:due?(U.samples.length?`Pendiente desde las ${hhmm(prev)} · hace ${fmtDur(now-prev)}`:'Con ella se crea tu línea base personal'):`Programada ${dayWord(next)} a las ${hhmm(next)}`}}

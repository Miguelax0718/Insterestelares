// ---------- Sky ----------
function sky(){
  const c=$('#sky'),x=c.getContext('2d');let stars=[];
  const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const size=()=>{c.width=innerWidth*devicePixelRatio;c.height=innerHeight*devicePixelRatio;c.style.width=innerWidth+'px';c.style.height=innerHeight+'px';
    stars=Array.from({length:Math.round(innerWidth*innerHeight/7000)},()=>({x:Math.random()*c.width,y:Math.random()*c.height,r:(Math.random()*1.1+.3)*devicePixelRatio,a:.05+Math.random()*.2,tw:Math.random()<.15,ph:Math.random()*6.28}))};
  size();addEventListener('resize',size);
  const draw=t=>{x.clearRect(0,0,c.width,c.height);for(const s of stars){const a=s.tw&&!reduce?s.a+Math.sin(t/900+s.ph)*.12+.06:s.a;x.globalAlpha=Math.max(0,a);x.fillStyle='#F0FFF1';x.beginPath();x.arc(s.x,s.y,s.r,0,6.28);x.fill()}
    if(!reduce) requestAnimationFrame(draw)};requestAnimationFrame(draw);
  const cm=$('.comet');const fire=()=>{if(reduce)return;cm.style.top=(20+Math.random()*120)+'px';cm.classList.remove('go');void cm.offsetWidth;cm.classList.add('go')};
  setTimeout(fire,3500);setInterval(fire,24000);
}

// ---------- Shell (barra lateral en computador/tablet, pestañas en celular) ----------
const NAV=[['panel','Panel','grid'],['nueva-muestra','Nueva muestra','flask'],['recomendaciones','Recomendaciones','spark'],['historial','Historial','history'],['alertas','Alertas','bell'],['perfil','Perfil','user']];
const TABS=[['panel','Panel','grid'],['nueva-muestra','Muestra','flask'],['recomendaciones','Consejos','spark'],['historial','Historial','history'],['perfil','Perfil','user']];
const LOGO=`<svg class="mark" viewBox="0 0 32 32"><defs><clipPath id="lgt"><rect x="0" y="0" width="32" height="16"/></clipPath><radialGradient id="lgp" cx=".35" cy=".3"><stop offset="0" stop-color="#C2F8CB"/><stop offset="1" stop-color="#8367C7"/></radialGradient></defs>
 <ellipse cx="16" cy="16" rx="5" ry="15" fill="none" stroke="#F0FFF1" stroke-width="1.6" transform="rotate(-18 16 16)" opacity=".55"/>
 <circle cx="16" cy="16" r="9.5" fill="url(#lgp)"/><path d="M8 13.5q8 2.5 16 0M7.2 18q8.8 2.6 17.6 0" stroke="#F0FFF1" stroke-opacity=".3" stroke-width="1.2" fill="none"/>
 <ellipse cx="16" cy="16" rx="5" ry="15" fill="none" stroke="#F0FFF1" stroke-width="1.6" transform="rotate(-18 16 16)" clip-path="url(#lgt)"/>
 <path d="M27 3l.9 2.1 2.1.9-2.1.9L27 9l-.9-2.1-2.1-.9 2.1-.9z" fill="#B3E9C7"/></svg>`;
const avatar=(c,size=40,fs=15)=>`<div class="avatar" style="background:${c.color};width:${size}px;height:${size}px;font-size:${fs}px">${c.initials}</div>`;
const firstName=()=>U.name.split(' ')[0];
const dotCol={ok:'var(--ok)',warn:'var(--warn)',crit:'var(--crit)'};
function moonPhase(day=MISSION.day,total=MISSION.total,size=36){
  const f=day/total; const off=f*2*size*.42;
  return `<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><defs><clipPath id="mp"><circle cx="${size/2}" cy="${size/2}" r="${size/2-2}"/></clipPath></defs>
  <circle cx="${size/2}" cy="${size/2}" r="${size/2-2}" fill="#F0FFF1"/><circle clip-path="url(#mp)" cx="${size/2-off-4}" cy="${size/2}" r="${size/2-1}" fill="#2F3061"/>
  <circle cx="${size/2+5}" cy="${size/2-4}" r="2" fill="#B4B2D1" opacity=".35"/><circle cx="${size/2+2}" cy="${size/2+6}" r="1.4" fill="#B4B2D1" opacity=".35"/></svg>`;
}
// estado de cualquier tripulante (usa su caché de datos)
function crewSummary(id){const keep=U;U=DB.cache[id];if(!U||!U.samples.length){U=keep;return {st:'ok',issues:[],empty:true}}const st=crewStatus();const issues=MODS.filter(m=>status(m.id)!=='ok').sort((a,b)=>sevOrder[status(a.id)]-sevOrder[status(b.id)]).map(m=>m.name);U=keep;return {st,issues}}
function crewList(){
  return `<div class="cap muted" style="padding:6px 10px 8px;letter-spacing:.06em">CAMBIAR DE TRIPULANTE</div>
   ${CREW.map(c=>{const sm=crewSummary(c.id);return `<button class="whoitem ${c.id===U.id?'on':''}" data-id="${c.id}">${avatar(c,36,13)}<span style="text-align:left;flex:1;min-width:0"><span style="display:block;font-weight:600;font-size:14px">${c.name}</span><span class="cap muted" style="display:block;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${sm.empty?'Sin muestras aún':sm.issues[0]||'Todo en rango'}</span></span>${sm.empty?'':`<span style="color:${dotCol[sm.st]}" aria-label="${ST[sm.st][2]}">${ic(ST[sm.st][1],18)}</span>`}</button>`}).join('')}
   <div class="hr" style="margin:6px 0"></div><button class="whoitem addcrew">${ic('plus',18)}<span style="font-size:14px">Agregar tripulante</span></button>
   ${window.URANO_BACK?`<a class="whoitem" href="${window.URANO_BACK}" style="text-decoration:none">${ic('left',18)}<span style="font-size:14px">Volver a AstraMed</span></a>`:''}`;
}
function bindCrewList(root,close){
  $$('.whoitem[data-id]',root).forEach(b=>b.onclick=()=>{const id=b.dataset.id;close();if(id===U.id)return;
    DB.use(id);S.storm=false;S.edit=false;S.wizard=0;rerender();toast(`Ahora ves los datos de ${U.name}`,'user')});
  $$('.addcrew',root).forEach(b=>b.onclick=()=>{close();crewModal()});
}
const whoBtn=id=>`<button class="whobtn" id="${id}" aria-label="Tripulante activo: ${U.name}. Cambiar de tripulante" aria-haspopup="true" aria-expanded="false">${avatar(U)}
  <span class="who-t" style="text-align:left;min-width:0"><span style="display:block;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${U.name}</span><span class="cap muted" style="display:block">${U.role}</span></span>
  <span class="chev" style="margin-left:auto">${ic('down',18)}</span></button>`;
function shell(){
  const r=route(); const cur=r.startsWith('m-')?'panel':r; const na=activeAlerts().length;
  return `<div class="shell">
   <header class="mhead">${whoBtn('mwho')}<button class="iconbtn ${na?'wig':''}" onclick="go('alertas')" aria-label="Alertas" style="width:48px;height:48px;border:0">${ic('bell',22)}${na?`<span class="badge">${na}</span>`:''}</button></header>
   <aside class="side ${S.side?'':'col'}" id="side">
   <div style="position:relative">${whoBtn('whobtn')}<div class="whomenu" id="whomenu" hidden>${crewList()}</div></div>
   <nav class="nav">${NAV.map(([k,l,i])=>`<a href="#${k}" class="${cur===k?'on':''}" ${cur===k?'aria-current="page"':''}>${ic(i)}<span class="lbl">${l}</span>${k==='alertas'&&na?`<span class="lbl" style="margin-left:auto;margin-right:18px"><span class="chip warn" style="height:22px;padding:0 8px">${na}</span></span>`:''}${k==='nueva-muestra'?`<span class="lbl navcd" data-cdclass style="margin-left:auto;margin-right:18px"><span class="cdpill" data-cd="short">${sampleState().short}</span></span>`:''}</a>`).join('')}</nav>
   <div class="side-foot">
     <div class="moonph">${moonPhase()}<div class="moon-t"><div class="small" style="font-weight:600">Día ${MISSION.day} de ${MISSION.total}</div><div class="cap muted">Misión ${MISSION.name}</div></div></div>
     <div class="conn"><span class="pulse" style="${DB.source==='db'?'':'background:var(--lav2)'}"></span>${ic('sat',16)}<span class="lbl">${DB.source==='db'?'Conectado a la base de datos':'Datos de demostración'}</span></div>
     <div class="between" style="padding:0 4px 0 8px"><div class="row lbl" style="gap:8px">${LOGO.replace('class="mark"','class="mark" style="width:22px;height:22px"')}<span style="font:700 14px var(--ff-h);letter-spacing:.06em" title="Unidad de Rastreo y Análisis Nefrológico Orbital">URANO</span></div>
       <button class="colbtn" id="colbtn" aria-label="Contraer menú">${ic('menu')}</button></div>
   </div></aside><main id="main"></main>
   <nav class="tabbar" aria-label="Secciones">${TABS.map(([k,l,i])=>`<a href="#${k}" class="tab ${cur===k?'on':''} ${k==='nueva-muestra'&&sampleState().due?'due':''}" ${k==='nueva-muestra'?'data-cdclass':''} ${cur===k?'aria-current="page"':''}><span style="position:relative">${ic(i,22)}${k==='nueva-muestra'?'<span class="tbadge" aria-label="Muestra pendiente"></span>':''}</span><span>${l}</span><span class="tdot"></span></a>`).join('')}</nav></div>`;
}
function bindShell(){
  $('#colbtn').onclick=()=>{S.side=!S.side;$('#side').classList.toggle('col',!S.side)};
  const menu=$('#whomenu'),btn=$('#whobtn');
  const closeMenu=()=>{menu.hidden=true;btn.setAttribute('aria-expanded','false');$('.chev',btn).classList.remove('open')};
  btn.onclick=e=>{e.stopPropagation();if(!S.side&&innerWidth>1100){S.side=true;$('#side').classList.remove('col')}menu.hidden=!menu.hidden;btn.setAttribute('aria-expanded',!menu.hidden);$('.chev',btn).classList.toggle('open',!menu.hidden)};
  document.onclick=e=>{if(!menu.hidden&&!menu.contains(e.target))closeMenu()};
  bindCrewList(menu,closeMenu);
  // Celular: la lista de tripulantes sale como hoja inferior
  $('#mwho').onclick=()=>{const sc=document.createElement('div');sc.className='scrim';sc.style.placeItems='end stretch';
    sc.innerHTML=`<div class="sheet" role="dialog" aria-label="Cambiar de tripulante"><div class="knob"></div>${crewList()}</div>`;document.body.appendChild(sc);
    const close=()=>{const s=$('.sheet',sc);s.animate([{transform:'none'},{transform:'translateY(100%)'}],{duration:200,easing:'ease-in'}).onfinish=()=>sc.remove()};
    sc.onclick=e=>{if(e.target===sc)close()};bindCrewList(sc,close)};
}

// ---------- Router ----------
const PAGES={};
const route=()=>{const h=location.hash.slice(1);return !h||h==='inicio'?'panel':h};
function render(){
  const r=route(); window.scrollTo(0,0); document.body.classList.toggle('editing',!!S.edit);
  $('#app').innerHTML=shell(); bindShell();
  let key=r.startsWith('m-')?'modulo':r; if(!U.samples.length&&!['nueva-muestra','perfil'].includes(key)) key='bienvenida'; const P=PAGES[key]||PAGES.panel;
  const main=$('#main'); main.innerHTML=`<div class="page">${P.html(r)}</div>`; P.bind&&P.bind(main,r);
  countUp(main); animateMarks(main);
}
const go=h=>{ if(S.edit&&route()!==h)S.edit=false; if(location.hash==='#'+h) render(); else location.hash=h; };
const rerender=()=>{const y=scrollY;render();scrollTo(0,y)};
// Barra del modo "Personalizar"
function editBar(what,keys){return S.edit?`<div class="editbar" role="region" aria-label="Personalizar"><span style="color:var(--lav2)">${ic('sliders',22)}</span><div style="flex:1;min-width:200px"><b>Personaliza ${what}</b><div class="small muted">Arrastra ${ic('grip',14,'vertical-align:-2px')} para mover, o usa las flechas. El ojo oculta lo que no quieras ver.</div></div>
  <button class="btn ghost m" id="ereset" data-keys='${JSON.stringify(keys)}'>Restablecer</button><button class="btn primary m" id="edone">${ic('check',18)}Listo</button></div>`:''}
function bindEditBar(root){const r=$('#ereset',root),d=$('#edone',root),p=$('#eopen',root);
  if(p)p.onclick=()=>{S.edit=true;rerender()};
  if(d)d.onclick=()=>{S.edit=false;rerender();toast('Diseño guardado','check')};
  if(r)r.onclick=()=>{const L=getLayout();for(const k of JSON.parse(r.dataset.keys))delete L[k];try{localStorage.setItem(LAYOUT_KEY(),JSON.stringify(L))}catch(e){}rerender();toast('Orden original restablecido','history')}}
const editBtn=()=>S.edit?'':`<button class="btn ghost m" id="eopen" aria-label="Personalizar el orden">${ic('sliders',18)}<span class="hide-m">Personalizar</span></button>`;

function patchSVG(c){return `<svg width="104" height="104" viewBox="0 0 120 120"><circle cx="60" cy="60" r="56" fill="none" stroke="${c.color}" stroke-width="2" stroke-dasharray="3 6"/><circle cx="60" cy="60" r="46" fill="#1C1D3D" stroke="${c.color}" stroke-width="2"/>
  <text x="60" y="68" text-anchor="middle" font-family="Space Grotesk" font-weight="700" font-size="26" fill="${c.color}">${c.initials}</text>
  <path d="M60 4l1.5 3.5 3.5 1.5-3.5 1.5L60 14l-1.5-3.5L55 9l3.5-1.5z" fill="#F0FFF1"/><circle cx="104" cy="60" r="2" fill="#F0FFF1"/><circle cx="16" cy="60" r="2" fill="#F0FFF1"/></svg>`}

// ---------- Agregar tripulante ----------
const CREW_COLORS=['#B3E9C7','#A994E0','#FFD23F','#C2F8CB','#FF5A5F','#B4B2D1','#F0FFF1'];
const esc=t=>String(t).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function crewModal(fromShell){
  const f={name:'',role:'',age:35,weight:70,height:1.72,waterGoal:2500,color:CREW_COLORS[CREW.length%CREW_COLORS.length]};
  const ini=n=>(n.trim().split(/\s+/).filter(Boolean).slice(0,2).map(w=>w[0]).join('')||'?').toUpperCase();
  const sc=document.createElement('div');sc.className='scrim';
  const field=(k,label,type='text',extra='')=>`<label class="fld"><span class="small muted">${label}</span><input class="inp" data-k="${k}" type="${type}" value="${f[k]}" ${extra}></label>`;
  sc.innerHTML=`<form class="modal rg" id="crewform" style="width:760px;display:grid;grid-template-columns:220px 1fr;gap:32px;align-items:start" novalidate>
    <div style="text-align:center"><div id="prev">${patchSVG({...f,initials:'?'})}</div><div id="prevname" style="font:600 18px var(--ff-h);margin-top:8px">Nuevo tripulante</div><div id="prevrole" class="muted small">Rol</div>
      <div class="cap muted" style="margin-top:20px">Color de la insignia</div><div class="row" style="gap:8px;justify-content:center;flex-wrap:wrap;margin-top:10px">${CREW_COLORS.map(c=>`<button type="button" class="sw ${c===f.color?'on':''}" data-c="${c}" style="background:${c}" aria-label="Color ${c}"></button>`).join('')}</div></div>
    <div><div class="between"><h2>Agregar tripulante</h2><button type="button" class="iconbtn" id="cx" style="width:44px;height:44px;border:0">${ic('x')}</button></div>
      <p class="muted small">Su línea base se crea con su primera muestra.</p>
      <div class="grid rg" style="grid-template-columns:1fr 1fr;gap:14px;margin-top:18px">
        <div style="grid-column:span 2">${field('name','Nombre completo','text','placeholder="Ej. Lucía Mendoza" autocomplete="off"')}</div>
        <div style="grid-column:span 2">${field('role','Rol en la misión','text','placeholder="Ej. Bióloga de a bordo" list="roles"')}<datalist id="roles"><option>Comandante</option><option>Piloto</option><option>Ingeniero de vuelo</option><option>Especialista de misión</option><option>Oficial médica</option><option>Científica de a bordo</option></datalist></div>
        ${field('age','Edad (años)','number','min="18" max="80"')}${field('weight','Peso (kg)','number','min="30" max="200"')}
        ${field('height','Estatura (m)','number','min="1" max="2.3" step="0.01"')}${field('waterGoal','Meta de agua (ml/día)','number','min="1000" max="5000" step="100"')}
      </div><p class="small" id="ferr" style="color:var(--crit);min-height:20px;margin-top:10px"></p>
      <div class="row" style="gap:12px;justify-content:flex-end;margin-top:6px"><button type="button" class="btn ghost" id="cancel">Cancelar</button><button type="submit" class="btn primary" id="savecrew">${ic('plus')}Agregar a la tripulación</button></div></div></form>`;
  document.body.appendChild(sc);
  const close=()=>sc.remove(); $('#cx',sc).onclick=close; $('#cancel',sc).onclick=close; sc.onclick=e=>{if(e.target===sc)close()};
  const paint=()=>{$('#prev',sc).innerHTML=patchSVG({...f,initials:ini(f.name)});$('#prevname',sc).textContent=f.name.trim()||'Nuevo tripulante';$('#prevrole',sc).textContent=f.role.trim()||'Rol'};
  $$('.inp',sc).forEach(i=>i.oninput=()=>{f[i.dataset.k]=i.type==='number'?+i.value:i.value;$('#ferr',sc).textContent='';paint()});
  $$('.sw',sc).forEach(b=>b.onclick=()=>{f.color=b.dataset.c;$$('.sw',sc).forEach(x=>x.classList.toggle('on',x===b));paint()});
  setTimeout(()=>$('.inp[data-k="name"]',sc).focus(),50);
  $('#crewform',sc).onsubmit=async e=>{e.preventDefault();
    const err=$('#ferr',sc); const name=f.name.trim(), role=f.role.trim();
    if(name.length<3){err.textContent='Escribe el nombre completo.';$('.inp[data-k="name"]',sc).focus();return}
    if(!role){err.textContent='Escribe el rol en la misión.';$('.inp[data-k="role"]',sc).focus();return}
    if(!(f.age>=18&&f.age<=80)||!(f.weight>=30&&f.weight<=200)||!(f.height>=1&&f.height<=2.3)){err.textContent='Revisa edad, peso y estatura.';return}
    const slug=name.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,20);
    const c={id:`${slug||'trip'}-${Date.now().toString(36).slice(-4)}`,name:esc(name),role:esc(role),initials:ini(name),color:f.color,age:f.age,weight:f.weight,height:f.height,
      dose:0,hr:70,bp:'120/80',water:0,waterGoal:Math.round(f.waterGoal||2500),sleep:7,sessions:0,energy:0,protein:0,mood:2};
    const btn=$('#savecrew',sc);btn.disabled=true;btn.textContent='Guardando…';
    try{ await DB.addCrew(c); close(); toast(`${c.name} se unió a la tripulación`,'user');
      DB.use(c.id);S.edit=false;go('panel'); }
    catch(x){ err.textContent='No se pudo guardar en la base de datos. Intenta de nuevo.';btn.disabled=false;btn.innerHTML=`${ic('plus')}Agregar a la tripulación`; }
  };
}

// ---------- Bienvenida (tripulante sin muestras) ----------
PAGES.bienvenida={
  html:()=>`<div class="card empty" style="padding:72px 32px;margin-top:24px">
    <svg width="220" height="170" viewBox="0 0 220 170"><circle cx="110" cy="96" r="52" fill="#8367C7" opacity=".55"/><ellipse cx="110" cy="96" rx="100" ry="22" fill="none" stroke="#F0FFF1" stroke-opacity=".5" transform="rotate(-14 110 96)"/>
     <g transform="translate(150 6) rotate(35)"><path d="M14 0c8 6 10 16 9 28H5C4 16 6 6 14 0z" fill="#F0FFF1"/><circle cx="14" cy="13" r="4" fill="#0E34A0"/><path d="M5 22l-6 8 7-1zM23 22l6 8-7-1z" fill="#A994E0"/><path d="M9 28h10l-5 12z" fill="#FFD23F"><animate attributeName="opacity" values="1;.5;1" dur=".4s" repeatCount="indefinite"/></path></g>
     <path d="M30 30l1.5 3.5 3.5 1.5-3.5 1.5L30 40l-1.5-3.5L25 35l3.5-1.5zM190 140l1 2.5 2.5 1-2.5 1-1 2.5-1-2.5-2.5-1 2.5-1z" fill="#F0FFF1"/></svg>
    <h1 style="font-size:32px;line-height:40px">Te damos la bienvenida, ${firstName()}</h1>
    <p class="muted" style="max-width:520px">Todavía no hay muestras tuyas. Con la primera creamos tu línea base personal, y desde ahí la app calcula tus rangos, gráficas y recomendaciones.</p>
    <button class="btn primary" style="margin-top:8px" onclick="go('nueva-muestra')">${ic('flask')}Registrar mi primera muestra</button></div>`,
  bind(){}
};

// ---------- Water glass ----------
function glassSVG(w=150,id='g'){
  const frac=Math.min(1,U.water/U.waterGoal), top=14, bot=172, y=top+(1-frac)*(bot-top);
  return `<svg class="glass" id="${id}" width="${w}" viewBox="0 0 140 190" role="button" aria-label="Agregar 250 ml de agua">
   <defs><clipPath id="${id}c"><path d="M22 12 L118 12 L107 170 Q106 176 99 176 L41 176 Q34 176 33 170 Z"/></clipPath>
   <linearGradient id="${id}w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#A994E0" stop-opacity=".85"/><stop offset="1" stop-color="#0E34A0" stop-opacity=".95"/></linearGradient></defs>
   <g clip-path="url(#${id}c)"><g class="water" style="transform:translateY(${y}px);transition:transform .9s cubic-bezier(.2,.8,.2,1)">
     <g class="wave"><path d="M0 4 Q15 -4 30 4 T60 4 T90 4 T120 4 T150 4 T180 4 T210 4 V200 H0Z" fill="url(#${id}w)"/></g>
     <circle class="bub" cx="55" cy="150" r="3" fill="#F0FFF1" style="animation-delay:0s"/><circle class="bub" cx="80" cy="140" r="2" fill="#F0FFF1" style="animation-delay:.5s"/><circle class="bub" cx="68" cy="160" r="2.5" fill="#F0FFF1" style="animation-delay:1s"/>
   </g></g>
   <path d="M22 12 L118 12 L107 170 Q106 176 99 176 L41 176 Q34 176 33 170 Z" fill="none" stroke="#F0FFF1" stroke-width="3" stroke-linejoin="round"/>
   <path d="M30 24 L38 150" stroke="#F0FFF1" stroke-opacity=".35" stroke-width="4" stroke-linecap="round"/>
   <path d="M18 10 h104" stroke="#F0FFF1" stroke-width="3" stroke-linecap="round"/></svg>`;
}
function bindGlass(root,id,onUpdate){
  const g=$('#'+id,root); if(!g) return;
  g.onclick=()=>{ const before=U.water<U.waterGoal; U.water=Math.min(U.waterGoal+500,U.water+250); DB.run('addWater',U.id,250);
    const frac=Math.min(1,U.water/U.waterGoal), y=14+(1-frac)*158; $('.water',g).style.transform=`translateY(${y}px)`;
    g.classList.add('fill');setTimeout(()=>g.classList.remove('fill'),900);
    onUpdate&&onUpdate();
    if(before&&U.water>=U.waterGoal){ burst(g.parentElement,12,'#B3E9C7',true);
      U.alerts.filter(a=>a.module==='hidratacion'&&a.status==='active').forEach(a=>{a.status='resolved';DB.run('resolveAlert',a.id)});
      const wr=U.recs.find(r=>r.module==='hidratacion'&&!r.done); if(wr){wr.done=true;DB.run('setRec',wr.id,true)}
      toast(status('hidratacion')==='ok'?'¡Meta de agua cumplida! Hidratación vuelve a Estable':'¡Meta de agua cumplida!'); setTimeout(()=>{ if(route()==='panel'||route()==='m-hidratacion') rerender(); },1300); }
    else burst(g.parentElement,5,'#A994E0');
  };
}

// ---------- P02 Panel ----------
function healthScore(){const w=MODS.filter(m=>status(m.id)==='warn').length,c=MODS.filter(m=>status(m.id)==='crit').length;return {s:Math.max(5,100-w*12-c*30),w:w+c,c}}
function todayLabel(){const d=new Date(MISSION.start+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+MISSION.day-1);const t=d.toLocaleDateString('es-CO',{weekday:'long',day:'numeric',month:'long',timeZone:'UTC'});return t[0].toUpperCase()+t.slice(1)}
function recCard(r,compact=false){
  const m=MOD[r.module]||MODS[0];const pc={Alta:'warn',Media:'info',Baja:'ok'}[r.priority];
  return `<div class="rec ${r.done?'done':''}" data-id="${r.id}"><button class="chk" aria-label="Marcar como hecho">${ic('check',22)}</button>
   <div style="flex:1;min-width:0"><div class="rt" style="font-weight:600">${r.text}</div>${compact?'':`<div class="small muted" style="margin-top:4px">${r.why}</div>`}
   <div class="row" style="margin-top:10px;gap:8px;flex-wrap:wrap"><span class="chip info" style="height:24px">${ic(m.icon,13)}${m.name}</span><span class="chip ${pc}" style="height:24px">Prioridad ${r.priority.toLowerCase()}</span></div></div></div>`;
}
function bindRecs(root,after){
  $$('.rec .chk',root).forEach(b=>b.onclick=e=>{e.stopPropagation();const el=b.closest('.rec');const r=U.recs.find(x=>x.id===el.dataset.id);
    r.done=!r.done; el.classList.toggle('done',r.done); DB.run('setRec',r.id,r.done);
    if(r.done){comet(b);burst(b,8,'#B3E9C7');toast('¡Bien hecho! Recomendación completada'); after&&setTimeout(after,700);} });
}
const ORGANS={estres:'Cerebro',inmunidad:'Ganglios',cardio:'Corazón',metabolismo:'Estómago',renal:'Riñones',hidratacion:'Vejiga',osea:'Huesos',radiacion:'Piel y ADN'};
// Cuerpo humano interactivo: cada órgano toma el color del estado de su módulo
function bodyMap(sel){const col=id=>SC[status(id)],al=id=>status(id)!=='ok'?'organ-alert':'';
  const o=(id,shape)=>`<g class="organ ${al(id)} ${sel===id?'sel':''}" data-mod="${id}" tabindex="0" role="button" aria-label="${ORGANS[id]} · ${MOD[id].name}: ${ST[status(id)][2]}" style="--oc:${col(id)}">${shape}</g>`;
  return `<svg class="bodymap" viewBox="0 0 200 360" width="210" role="group" aria-label="Mapa del cuerpo: toca un órgano para ver su estado">
    <defs><filter id="aura" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="5"/></filter></defs>
    <g class="silh-aura" style="--oc:${col('radiacion')}" filter="url(#aura)"><circle cx="100" cy="40" r="27"/><path d="M60 80Q100 66 140 80L152 150Q148 200 140 214L60 214Q52 200 48 150Z"/><path d="M58 84Q38 94 32 150L28 214M142 84Q162 94 168 150L172 214M80 214L74 334M120 214L126 334"/></g>
    <g class="silh"><circle cx="100" cy="40" r="26"/><rect x="91" y="64" width="18" height="14" rx="4"/><path d="M60 80Q100 66 140 80L152 150Q148 200 140 214L60 214Q52 200 48 150Z"/>
      <path class="limb" d="M58 84Q38 94 32 150L28 214M142 84Q162 94 168 150L172 214"/><path class="limb leg" d="M80 214L74 334M120 214L126 334"/></g>
    ${o('estres','<path d="M84 38c-2-10 6-17 16-17s18 7 16 17c3 4 0 11-6 11H90c-6 0-9-7-6-11z"/><path class="ln" d="M92 30q4 4 0 8M104 27q-3 5 2 9M110 36q-4 2-2 6"/>')}
    ${o('inmunidad','<circle class="hit" cx="88" cy="74" r="10"/><circle class="hit" cx="112" cy="74" r="10"/><circle class="hit" cx="68" cy="100" r="10"/><circle class="hit" cx="132" cy="100" r="10"/><circle cx="88" cy="74" r="4.5"/><circle cx="112" cy="74" r="4.5"/><circle cx="68" cy="100" r="4.5"/><circle cx="132" cy="100" r="4.5"/><circle cx="84" cy="206" r="4"/><circle cx="116" cy="206" r="4"/>')}
    ${o('cardio','<path class="beat" d="M113 102c4-6 14-4 14 4 0 8-14 16-14 16s-14-8-14-16c0-8 10-10 14-4z"/>')}
    ${o('metabolismo','<path d="M80 132c8-6 22-4 24 4 2 10-6 20-18 20-8 0-12-6-10-12 1-4 6-4 6-8 0-2-3-3-2-4z"/>')}
    ${o('renal','<ellipse cx="80" cy="170" rx="8" ry="13"/><ellipse cx="120" cy="170" rx="8" ry="13"/>')}
    ${o('hidratacion','<path d="M88 196c0-6 6-8 12-8s12 2 12 8c0 7-6 11-12 11s-12-4-12-11z"/>')}
     ${o('osea','<rect class="hit" x="66" y="216" width="68" height="96" rx="12"/><path class="bone" d="M81 228L77 300M119 228L123 300"/><circle cx="81" cy="226" r="5"/><circle cx="119" cy="226" r="5"/><circle cx="77" cy="302" r="5"/><circle cx="123" cy="302" r="5"/>')}
    ${o('radiacion','<circle class="hit" cx="158" cy="56" r="24"/><circle cx="158" cy="56" r="11"/><path class="ln" d="M158 38v-5M158 79v-5M140 56h-5M181 56h-5M146 44l-3-3M173 71l-3-3M146 68l-3 3M173 41l-3 3"/>')}
  </svg>`}
function organDetail(id){const m=MOD[id],s=status(id);
  return `<div class="row" style="gap:10px;flex-wrap:wrap"><span style="color:${SC[s]}">${ic(m.icon,22)}</span><b>${ORGANS[id]}</b><span class="small muted">· ${m.name}</span>${chip(s)}</div>
    <div class="num" style="font:700 26px var(--ff-h);margin-top:8px">${m.key()}</div><div class="small muted">${m.sub()}</div>
    <button class="btn ${s==='ok'?'ghost':'primary'} m" style="margin-top:12px" onclick="go('m-${id}')">Ver ${m.name.toLowerCase()} ${ic('right',16)}</button>`}
const legend=()=>`<div class="legend" role="note" aria-label="Código de color">${['ok','warn','crit'].map(s=>`<span style="color:${SC[s]}">${ic(ST[s][1],14)}<span>${ST[s][2]}</span></span>`).join('')}</div>`;
const PANEL_W={
  muestra:{name:'Nueva muestra',span:2,html(){const st=sampleState();return `<div class="card samplecard ${st.due?'due':''}" data-cdclass style="display:flex;align-items:center;gap:18px;padding:18px 22px;flex-wrap:wrap">
      <span data-cdring="64">${sampleRing(st)}</span>
      <div style="flex:1;min-width:180px"><div style="font:600 20px var(--ff-h)" data-cd="title">${st.title}</div><div class="small muted" data-cd="sub">${st.sub}</div></div>
      <button class="btn ${st.due?'primary':'ghost'}" onclick="go('nueva-muestra')">${ic('flask')}${st.due?'Registrar ahora':'Registrar muestra'}</button></div>`}},
  estado:{name:'Estado del cuerpo',span:2,html(){const hs=healthScore();const al=activeAlerts().sort((a,b)=>sevOrder[a.severity]-sevOrder[b.severity])[0];
    const worstId=[...MODS].sort((a,b)=>sevOrder[status(a.id)]-sevOrder[status(b.id)])[0].id; S.organ=S.organ&&MOD[S.organ]?S.organ:worstId;
    return `<div class="card stk" style="display:flex;gap:28px;align-items:flex-start;padding:24px 28px">
      <div style="text-align:center;flex:none"><div id="bodywrap">${bodyMap(S.organ)}</div>${legend()}</div>
      <div style="flex:1;min-width:0;display:flex;flex-direction:column;gap:16px">
        <div class="row" style="gap:14px"><svg width="56" height="56" viewBox="0 0 56 56" aria-label="Puntaje ${hs.s} de 100" role="img" style="flex:none"><circle cx="28" cy="28" r="23" fill="none" stroke="var(--bg)" stroke-width="6"/><circle class="ringfg" cx="28" cy="28" r="23" fill="none" stroke="${SC[hs.c?'crit':hs.w?'warn':'ok']}" stroke-width="6" stroke-linecap="round" stroke-dasharray="${2*Math.PI*23}" stroke-dashoffset="${2*Math.PI*23}" data-off="${2*Math.PI*23*(1-hs.s/100)}" transform="rotate(-90 28 28)"/><text x="28" y="33" text-anchor="middle" font-family="Space Grotesk" font-weight="700" font-size="16" fill="var(--text)">${hs.s}</text></svg>
          <div><h2 style="font-size:22px;line-height:28px">${hs.w?`${hs.w} ${hs.w>1?'sistemas necesitan':'sistema necesita'} atención`:'Todo tu cuerpo está estable'}</h2><p class="muted small">Toca un órgano para ver su estado · última muestra: día ${U.samples.at(-1).day}</p></div></div>
        ${al?`<div class="row" style="gap:12px;padding:12px 14px;border-radius:14px;background:${al.severity==='crit'?'rgba(255,90,95,.14)':'rgba(255,210,63,.12)'};flex-wrap:wrap">${chip(al.severity)}<span style="flex:1;min-width:160px;font-weight:600">${al.title}</span><button class="btn ghost m" onclick="go('m-${al.module}')">Ver qué hacer ${ic('right',16)}</button></div>`:''}
        <div class="organcard" id="orgcard" aria-live="polite">${organDetail(S.organ)}</div>
      </div></div>`}},
  hoy:{name:'Qué hacer hoy',span:1,html(){const top3=U.recs.filter(r=>!r.done).sort((a,b)=>PRIO[a.priority]-PRIO[b.priority]).slice(0,3);
    return `<div class="card"><div class="between" style="margin-bottom:12px"><h3>Qué hacer hoy</h3><a href="#recomendaciones" class="small" style="color:var(--lav2);min-height:44px;display:flex;align-items:center">Ver todo</a></div>
      <div class="grid" style="gap:10px">${top3.map(r=>recCard(r,true)).join('')||'<p class="muted small">¡Todo hecho por hoy!</p>'}</div></div>`}},
  agua:{name:'Agua de hoy',span:1,html(){return `<div class="card"><div class="between"><h3>Agua de hoy</h3><span class="cap muted">Toca el vaso: +250 ml</span></div>
      <div class="row" style="gap:20px;margin-top:12px"><div class="glass-wrap">${glassSVG(120,'pg')}</div>
      <div><div class="num" style="font:700 32px var(--ff-h)" id="wtxt">${(U.water/1000).toFixed(2)} L</div><div class="muted small">de ${(U.waterGoal/1000).toFixed(1)} L</div>
       <div class="range" style="margin-top:14px;width:140px"><div class="band" id="wbar" style="left:0;width:${Math.min(100,U.water/U.waterGoal*100)}%;background:var(--lav2);transition:width .8s var(--ease)"></div></div>
       <div class="cap muted" style="margin-top:8px" id="wleft">${U.water>=U.waterGoal?'¡Meta cumplida!':`Faltan ${U.waterGoal-U.water} ml`}</div></div></div></div>`}},
  modulos:{name:'Tus módulos',span:2,html(){const L=getLayout();const def=[...MODS].sort((a,b)=>sevOrder[status(a.id)]-sevOrder[status(b.id)]).map(m=>m.id);
    const order=ordered(def,L.mods);
    return `<div class="wbody"><div class="between" style="margin:4px 2px 12px"><h3>Tus módulos</h3><span class="cap muted hide-m">${S.edit?'Arrastra cada tarjeta a donde quieras':'Toca uno para ver el detalle'}</span></div>
      <div class="mgrid" id="mgrid">${order.map(id=>{const m=MOD[id],s=status(id);return `<div class="card hov mcard ${s}" data-sid="${id}" role="link" tabindex="0" aria-label="${m.name}: ${ST[s][2]}" onclick="if(!S.edit)go('m-${id}')" onkeydown="if(event.key==='Enter'&&!S.edit)go('m-${id}')" style="position:relative">
        <button class="grip mgrip" aria-label="Arrastrar ${m.name}">${ic('grip',18)}</button>
        <div class="between"><div class="mi">${ic(m.icon,22)}</div>${chip(s)}</div>
        <div><div class="small muted">${m.name}</div><div class="mval">${m.key()}</div><div class="cap muted">${m.sub()}</div></div>
        ${S.edit?`<div class="row" style="gap:4px;justify-content:center"><button class="mv mmv" data-d="-1" aria-label="Mover ${m.name} antes">${ic('left',18)}</button><button class="mv mmv" data-d="1" aria-label="Mover ${m.name} después">${ic('right',18)}</button></div>`:spark(series(m.primary,7).map(Number),160,30,s==='ok'?'#A994E0':s==='crit'?'#FF5A5F':'#FFD23F')}</div>`}).join('')}</div></div>`}},
};
PAGES.panel={
  html(){const na=activeAlerts().length;
    return `<div class="top"><div class="grow"><h1 style="font-size:32px;line-height:40px">Hola, ${firstName()}</h1><p class="muted">${todayLabel()} · Día ${MISSION.day} de ${MISSION.total}</p></div>
      ${editBtn()}<button class="iconbtn hide-m ${na?'wig':''}" onclick="go('alertas')" aria-label="Alertas">${ic('bell',22)}${na?`<span class="badge">${na}</span>`:''}</button>
      <button class="btn primary hide-m" onclick="go('nueva-muestra')">${ic('flask')}Nueva muestra<span class="cdpill" data-cd="short">${sampleState().short}</span></button></div>
    ${editBar('tu panel',['panel','panelHidden','mods'])}
    ${widgetGrid('panel',PANEL_W,[])}`;
  },
  bind(root){
    setTimeout(()=>$$('.ringfg',root).forEach(r=>r.style.strokeDashoffset=r.dataset.off),80);
    const pick=id=>{S.organ=id;$('#bodywrap',root).innerHTML=bodyMap(id);$('#orgcard',root).innerHTML=organDetail(id);bindOrgans()};
    const bindOrgans=()=>$$('.organ',root).forEach(g=>{g.onclick=()=>pick(g.dataset.mod);g.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();pick(g.dataset.mod);$(`.organ[data-mod="${g.dataset.mod}"]`,root)?.focus()}}});
    if($('#bodywrap',root))bindOrgans();
    bindGlass(root,'pg',()=>{$('#wtxt').textContent=(U.water/1000).toFixed(2)+' L';$('#wbar').style.width=Math.min(100,U.water/U.waterGoal*100)+'%';$('#wleft').textContent=U.water>=U.waterGoal?'¡Meta cumplida!':`Faltan ${U.waterGoal-U.water} ml`});
    bindRecs(root,()=>rerender()); bindEditBar(root); bindWidgetGrid(root);
    const mg=$('#mgrid',root); if(mg){const save=()=>setLayout({mods:$$('.mcard',mg).map(c=>c.dataset.sid)});
      sortable(mg,{item:'.mcard',handle:'.mgrip',onChange:save});
      $$('.mmv',mg).forEach(b=>b.onclick=e=>{e.stopPropagation();moveBy(b.closest('.mcard'),+b.dataset.d,'.mcard');save()});}
  }
};

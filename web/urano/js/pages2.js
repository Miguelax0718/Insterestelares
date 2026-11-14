// ---------- Shared illustrations ----------
function body(sel=true,w=150){
  const z=(id,el)=>el.replace('<','<').replace('/>',` class="zone ${S.zones.has(id)?'on':''}" data-z="${id}" fill="#A994E0" fill-opacity=".15" stroke="#A994E0" stroke-width="1.5"/>`);
  return `<svg width="${w}" viewBox="0 0 120 240" class="bodysvg">
   ${z('cabeza','<circle cx="60" cy="26" r="20"/>')}
   ${z('pecho','<rect x="34" y="52" width="52" height="46" rx="14"/>')}
   ${z('abdomen','<rect x="36" y="100" width="48" height="30" rx="8"/>')}
   ${z('espalda baja','<rect x="36" y="132" width="48" height="24" rx="10"/>')}
   <rect x="14" y="56" width="16" height="80" rx="8" fill="none" stroke="#5F5980" stroke-width="1.5"/><rect x="90" y="56" width="16" height="80" rx="8" fill="none" stroke="#5F5980" stroke-width="1.5"/>
   ${z('piernas','<path d="M38 160h44l-4 74h-14l-4-56-4 56H42z"/>')}</svg>`;
}
function bindBody(root){ $$('.zone',root).forEach(p=>p.onclick=()=>{const id=p.dataset.z;S.zones.has(id)?S.zones.delete(id):S.zones.add(id);p.classList.toggle('on');const l=$('#zonelist',root);if(l)l.textContent=S.zones.size?[...S.zones].join(', '):'Ninguna zona marcada'}); }
function togs(list,set,cls='tg'){return list.map(([k,l,i])=>`<button class="tog ${set.has(k)?'on':''} ${cls}" data-k="${k}">${i?ic(i,18):''}${l}</button>`).join('')}
function bindTogs(root,cls,set){$$('.'+cls,root).forEach(b=>b.onclick=()=>{const k=b.dataset.k;set.has(k)?set.delete(k):set.add(k);b.classList.toggle('on')})}

// ---------- P03 Nueva muestra ----------
const STEPS=['Método','Contexto','Revisión','Análisis'];
const ILL={
 cpu:`<svg class="ill" width="110" height="90" viewBox="0 0 110 90"><rect x="15" y="10" width="80" height="70" rx="14" fill="#1C1D3D" stroke="#A994E0" stroke-width="2"/><rect x="28" y="22" width="54" height="26" rx="6" fill="#0E34A0"/><path d="M34 36h8l4-8 6 14 4-6h12" stroke="#B3E9C7" stroke-width="2" fill="none" stroke-linecap="round"/><circle cx="40" cy="64" r="6" fill="#B3E9C7"/><rect x="54" y="60" width="28" height="8" rx="4" fill="#5F5980"/></svg>`,
 strip:`<svg class="ill" width="110" height="90" viewBox="0 0 110 90"><rect x="10" y="38" width="90" height="16" rx="4" fill="#F0FFF1"/>${['#B3E9C7','#F2A93B','#A994E0','#8367C7','#C2F8CB','#FF7A7A'].map((c,i)=>`<rect x="${36+i*10}" y="41" width="7" height="10" rx="1.5" fill="${c}"/>`).join('')}<rect x="10" y="38" width="22" height="16" rx="4" fill="#B4B2D1"/><circle cx="84" cy="22" r="12" fill="none" stroke="#A994E0" stroke-width="2"/><path d="M92 30l8 8" stroke="#A994E0" stroke-width="3" stroke-linecap="round"/></svg>`,
 pencil:`<svg class="ill" width="110" height="90" viewBox="0 0 110 90"><rect x="18" y="10" width="62" height="72" rx="8" fill="#1C1D3D" stroke="#A994E0" stroke-width="2"/><path d="M30 28h38M30 40h30M30 52h34M30 64h20" stroke="#5F5980" stroke-width="3" stroke-linecap="round"/><path d="M96 20 62 64l-4 12 12-4 34-44z" fill="#F2A93B"/><path d="M58 76l4-12 8 8z" fill="#F0FFF1"/></svg>`,
};
function beaker(){const f=S.vol/800,y=30+(1-f)*130;return `<svg width="110" viewBox="0 0 110 180"><defs><clipPath id="bk"><path d="M20 20h70v140a10 10 0 0 1-10 10H30a10 10 0 0 1-10-10z"/></clipPath></defs>
 <g clip-path="url(#bk)"><rect id="bkw" x="0" y="${y}" width="110" height="200" fill="#F2A93B" fill-opacity=".55" style="transition:y .5s var(--ease)"/></g>
 <path d="M14 20h82M20 20v140a10 10 0 0 0 10 10h50a10 10 0 0 0 10-10V20" fill="none" stroke="#F0FFF1" stroke-width="2.5"/>${[0,1,2,3].map(i=>`<path d="M20 ${50+i*30}h14" stroke="#B4B2D1" stroke-width="1.5"/><text x="40" y="${54+i*30}" font-size="9" fill="#B4B2D1">${600-i*150}</text>`).join('')}</svg>`}
function miniGlasses(n,filled,cls='mg'){return Array.from({length:n},(_,i)=>`<svg class="minig ${cls}" data-i="${i}" width="36" height="48" viewBox="0 0 36 48"><defs><clipPath id="${cls}${i}"><path d="M5 4h26l-3 40H8z"/></clipPath></defs><g clip-path="url(#${cls}${i})"><rect class="w" x="0" y="${i<filled?8:48}" width="36" height="${i<filled?40:0}" fill="#A994E0"/></g><path d="M5 4h26l-3 40H8z" fill="none" stroke="#F0FFF1" stroke-width="2" stroke-linejoin="round"/></svg>`).join('')}
function setMini(root,cls,filled){$$('.'+cls,root).forEach((g,i)=>{const r=$('rect.w',g);r.setAttribute('y',i<filled?8:48);r.setAttribute('height',i<filled?40:0)})}

PAGES['nueva-muestra']={
  html(){
    const st=S.wizard; const pos=i=>12.5+i*25;
    return `<div class="top"><div class="grow"><h1 style="font-size:32px;line-height:40px">Nueva muestra</h1><p class="muted">Cuatro pasos y listo. Tarda unos 2 minutos.</p></div></div>
    <div class="traj"><svg width="100%" height="96" style="position:absolute;inset:0" preserveAspectRatio="none" viewBox="0 0 100 96"><path d="M12.5 58 Q25 30 37.5 58 T62.5 58 T87.5 58" stroke="#5F5980" stroke-width=".4" stroke-dasharray="1 1.4" fill="none" vector-effect="non-scaling-stroke"/></svg>
      ${STEPS.map((s,i)=>`<div class="planet ${i<st?'done':i===st?'cur':''}" style="left:${pos(i)}%"><div class="ball"></div><div class="small" style="font-weight:${i===st?600:400};color:${i===st?'var(--text)':'var(--text2)'}">${i+1}. ${s}</div></div>`).join('')}
      <svg class="rocket" id="rocket" style="left:${pos(st)}%" viewBox="0 0 40 40"><g transform="rotate(45 20 20)"><path d="M20 4c6 5 8 12 7 20H13c-1-8 1-15 7-20z" fill="#F0FFF1"/><circle cx="20" cy="15" r="3.5" fill="#0E34A0"/><path d="M13 22l-5 6 6-1zM27 22l5 6-6-1z" fill="#A994E0"/><path d="M16 25h8l-4 9z" fill="#F2A93B"><animate attributeName="opacity" values="1;.5;1" dur=".4s" repeatCount="indefinite"/></path></g></svg></div>
    <div class="steps-vp"><div class="steps-track" id="track" style="transform:translateX(-${st*100}%)">
     <section><div class="grid rg" style="grid-template-columns:repeat(3,1fr)">${[['sensor','Sensor automático','Lectura directa del equipo de la estación','cpu'],['tira','Tira reactiva (foto)','Toma una foto de la tira y la app lee los colores','strip'],['manual','Manual','Escribe los valores tú mismo','pencil']].map(([k,t,d,il])=>`<button class="card hov optcard ${S.method===k?'sel':''}" data-m="${k}">${ILL[il]}<h2>${t}</h2><p class="small muted">${d}</p></button>`).join('')}</div>
      <p class="cap muted" style="margin-top:16px">¿Quieres ver el estado de error? <button class="cap" id="simerr" style="color:var(--lav2);text-decoration:underline">Simular fallo del sensor</button></p></section>
     <section><div class="grid rg" style="grid-template-columns:1fr 1fr">
       <div class="card"><h3>Volumen de la muestra</h3><div class="row" style="gap:28px;margin-top:12px"><div id="bkwrap">${beaker()}</div><div><div class="num" style="font:700 40px var(--ff-h)" id="voltxt">${S.vol} ml</div>
        <div class="stepper" style="margin-top:12px"><button id="vminus" aria-label="Menos">${ic('minus',24)}</button><button id="vplus" aria-label="Más">${ic('plus',24)}</button></div><p class="cap muted" style="margin-top:8px">Hora de la muestra: 07:30</p></div></div></div>
       <div class="card"><h3>Líquidos desde la última muestra</h3><p class="small muted">Cada vaso son 250 ml. Toca para llenar.</p><div class="row" style="gap:10px;margin-top:16px;flex-wrap:wrap" id="ctxg">${miniGlasses(8,S.glassesCtx,'cg')}</div>
        <p class="num" style="margin-top:12px;font-weight:600" id="ctxml">${S.glassesCtx*250} ml</p><div class="hr"></div>
        <h3>Ejercicio de hoy</h3><div class="row" style="gap:10px;margin-top:12px;flex-wrap:wrap">${togs([['correr','Correr','run'],['bici','Bicicleta','bike'],['fuerza','Fuerza','dumb']],S.ex,'tex')}</div></div>
       <div class="card" style="grid-column:span 2;display:flex;gap:32px;align-items:center"><div>${body(true,130)}</div><div style="flex:1"><h3>¿Sientes algo?</h3><p class="small muted">Toca una zona del cuerpo o elige un síntoma.</p><p class="small" style="margin-top:8px;color:var(--warn)" id="zonelist">${S.zones.size?[...S.zones].join(', '):'Ninguna zona marcada'}</p>
        <div class="row" style="gap:10px;margin-top:16px;flex-wrap:wrap">${togs([['ardor','Ardor'],['fatiga','Fatiga'],['fiebre','Fiebre'],['dolor de cabeza','Dolor de cabeza']],S.sympt,'tsy')}</div>
        <div class="between" style="margin-top:20px;max-width:420px"><div><div style="font-weight:600">¿Tomaste medicación?</div><div class="small muted">Algunos medicamentos cambian la lectura</div></div><button class="switch ${S.med?'on':''}" id="med" aria-label="Medicación"></button></div></div></div>
     </div></section>
     <section><div class="grid rg" style="grid-template-columns:repeat(4,1fr)">${[['Método',{sensor:'Sensor automático',tira:'Tira reactiva',manual:'Manual'}[S.method]||'Sin elegir',S.method==='tira'?'cam':S.method==='manual'?'pencil':'cpu',0],['Volumen',S.vol+' ml','flask',1],['Líquidos',S.glassesCtx*250+' ml','drop',1],['Síntomas',[...S.sympt,...S.zones].join(', ')||'Ninguno','heart',1]].map(([t,v,i,s])=>`<div class="card"><div class="mi" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;background:rgba(169,148,224,.14);color:var(--lav2)">${ic(i,22)}</div><div class="small muted" style="margin-top:14px">${t}</div><div style="font:600 18px var(--ff-h);margin-top:2px">${v}</div><button class="btn ghost m edit" data-s="${s}" style="margin-top:16px">${ic('pencil',16)}Editar</button></div>`).join('')}</div></section>
     <section><div class="card" id="analysis" style="display:flex;align-items:center;gap:48px;padding:40px"></div></section>
    </div></div>
    <div class="between" style="margin-top:28px;${st===3?'visibility:hidden':''}"><button class="btn ghost" id="back" ${st===0?'disabled':''}>${ic('left')}Atrás</button>
      <button class="btn primary" id="next" style="min-width:200px" ${st===0&&!S.method?'disabled':''}>${st===2?'Analizar muestra':'Continuar'}${ic('right')}</button></div>`;
  },
  bind(root){
    const setStep=s=>{S.wizard=s;rerender()};
    $$('.optcard',root).forEach(b=>b.onclick=()=>{S.method=b.dataset.m;$$('.optcard',root).forEach(o=>o.classList.toggle('sel',o===b));$('#next',root).disabled=false});
    $('#next',root).onclick=()=>setStep(S.wizard+1); $('#back',root).onclick=()=>setStep(S.wizard-1);
    $('#simerr',root).onclick=()=>{S.err=true;S.wizard=3;rerender()};
    const vol=d=>{S.vol=Math.max(50,Math.min(800,S.vol+d));$('#voltxt').textContent=S.vol+' ml';$('#bkw').setAttribute('y',30+(1-S.vol/800)*130)};
    $('#vplus',root).onclick=()=>vol(50);$('#vminus',root).onclick=()=>vol(-50);
    $$('.cg',root).forEach(g=>g.onclick=()=>{const i=+g.dataset.i;S.glassesCtx=S.glassesCtx===i+1?i:i+1;setMini(root,'cg',S.glassesCtx);$('#ctxml').textContent=S.glassesCtx*250+' ml'});
    bindTogs(root,'tex',S.ex);bindTogs(root,'tsy',S.sympt);bindBody(root);
    $('#med',root).onclick=e=>{S.med=!S.med;e.currentTarget.classList.toggle('on')};
    $$('.edit',root).forEach(b=>b.onclick=()=>setStep(+b.dataset.s));
    if(S.wizard===3) (S.err?showError():runAnalysis());
  }
};
function runAnalysis(){
  const a=$('#analysis'); const names=['Volumen','Densidad','Osmolalidad','Calcio','Oxalato','Citrato','Ácido úrico','pH','8-OHdG','Isoprostanos','Leucocitos','Nitritos','Sodio','Potasio','Cortisol','Melatonina','Glucosa','Cetonas'];
  a.innerHTML=`<svg width="200" height="200" viewBox="0 0 200 200" class="vial-orbit"><circle cx="100" cy="100" r="80" fill="none" stroke="#5F5980" stroke-dasharray="2 6"/><circle cx="100" cy="100" r="58" fill="none" stroke="#5F5980" stroke-opacity=".5"/>
    <g class="orbit" style="transform-origin:100px 100px;animation-duration:3s"><circle cx="100" cy="20" r="5" fill="#B3E9C7"/></g><g class="orbit" style="transform-origin:100px 100px;animation-duration:5s;animation-direction:reverse"><circle cx="100" cy="42" r="4" fill="#A994E0"/></g><g class="orbit" style="transform-origin:100px 100px;animation-duration:7s"><circle cx="180" cy="100" r="3" fill="#F2A93B"/></g>
    <rect x="86" y="62" width="28" height="80" rx="12" fill="none" stroke="#F0FFF1" stroke-width="2.5"/><rect x="88" y="96" width="24" height="44" rx="10" fill="#F2A93B" fill-opacity=".7"><animate attributeName="fill-opacity" values=".5;.9;.5" dur="1.2s" repeatCount="indefinite"/></rect><rect x="82" y="56" width="36" height="10" rx="3" fill="#A994E0"/></svg>
    <div style="flex:1"><h2 style="font-size:26px">Analizando 18 biomarcadores…</h2><p class="muted" style="margin-top:4px">Comparando con tu línea base personal</p>
    <div class="range" style="margin-top:20px;height:12px"><div class="band" id="anbar" style="left:0;width:0;background:var(--text);transition:width .2s linear"></div></div>
    <div class="row" id="bmfly" style="gap:8px;flex-wrap:wrap;margin-top:20px;min-height:80px"></div></div>`;
  let i=0; const t=setInterval(()=>{ if(!$('#bmfly')||S.err){clearInterval(t);return}
    $('#bmfly').insertAdjacentHTML('beforeend',`<span class="chip info bm-fly">${ic('check',13)}${names[i]}</span>`); i++; $('#anbar').style.width=(i/names.length*100)+'%';
    if(i>=names.length){clearInterval(t);const d={method:S.method||'sensor',volume_ml:S.vol,fluids_ml:S.glassesCtx*250,exercise:[...S.ex],symptoms:[...S.sympt],zones:[...S.zones],medication:S.med};
      DB.saveSample(d).catch(e=>{console.warn(e);toast('No se pudo guardar la muestra','alc')}).finally(()=>setTimeout(()=>{S.wizard=0;if(!U.samples.length){toast('Tu muestra se está procesando. Aparecerá en unos minutos.','clock');go('panel')}else go('resultados')},500))} },170);
}
function showError(){
  const a=$('#analysis');
  a.innerHTML=`<svg width="200" height="170" viewBox="0 0 200 170"><rect x="40" y="30" width="120" height="110" rx="18" fill="#1C1D3D" stroke="#FF7A7A" stroke-width="2.5"/><rect x="58" y="48" width="84" height="40" rx="8" fill="#2F3061"/><path d="M66 68h14l6-10 8 18 6-8h12" stroke="#5F5980" stroke-width="2.5" fill="none"/><path d="M118 52l-8 14h10l-8 16" stroke="#FF7A7A" stroke-width="3" fill="none" stroke-linecap="round"/><circle cx="70" cy="112" r="8" fill="#FF7A7A"><animate attributeName="opacity" values="1;.3;1" dur="1s" repeatCount="indefinite"/></circle><rect x="88" y="108" width="50" height="8" rx="4" fill="#5F5980"/></svg>
  <div style="flex:1"><span class="chip crit">${ic('alc',15)}Error de lectura</span><h2 style="font-size:26px;margin-top:12px">No se pudo leer la muestra</h2><p class="muted" style="margin-top:6px">El sensor no detectó suficiente volumen. Revisa que el recipiente esté bien colocado.</p>
  <div class="row" style="gap:12px;margin-top:24px"><button class="btn primary" id="retry">Reintentar</button><button class="btn ghost" id="manual">${ic('pencil')}Ingresar manual</button></div></div>`;
  $('#retry').onclick=()=>{S.err=false;runAnalysis()};
  $('#manual').onclick=()=>{S.err=false;S.method='manual';S.wizard=1;rerender()};
}

// ---------- P04 Resultados ----------
const CONST_POS={hidratacion:[90,70],renal:[200,40],osea:[310,90],radiacion:[430,50],inmunidad:[540,110],cardio:[140,180],estres:[330,200],metabolismo:[480,190]};
const CONST_LINES=[['hidratacion','renal'],['renal','osea'],['osea','radiacion'],['radiacion','inmunidad'],['hidratacion','cardio'],['cardio','estres'],['estres','metabolismo'],['metabolismo','inmunidad'],['osea','estres']];
const METH={sensor:'Sensor automático',tira:'Tira reactiva',manual:'Manual'};
const METH_IC={sensor:'cpu',tira:'cam',manual:'pencil'};
function changes(){const L=S_LAST();if(L<1)return [];return MODS.map(m=>({m,from:status(m.id,L-1),to:status(m.id)})).filter(c=>c.from!==c.to)}
function keyBm(m,i=S_LAST()){return m.bms.find(k=>sevOf(k,i)!=='ok'&&!BM[k].bool)||m.bms.find(k=>sevOf(k,i)!=='ok')||m.primary}
PAGES.resultados={
  html(){
    const ch=changes(), last=U.samples.at(-1); const ids=ch.map(c=>c.m.id);
    const verb=c=>c.to==='ok'?'volvió a normal':c.to==='crit'?'pasó a crítico':'pasó a atención';
    const issues=MODS.filter(m=>status(m.id)!=='ok');
    const title=ch.length?ch.map(c=>`${c.m.name} ${verb(c)}`).join(' y '):issues.length?`Sin cambios: ${issues.map(m=>m.name.toLowerCase()).join(' y ')} sigue${issues.length>1?'n':''} en atención`:'Todo sigue en tu rango personal';
    const show=(ch.length?ch.map(c=>c.m):issues).slice(0,4);
    const recs=U.recs.filter(r=>!r.done&&(ids.includes(r.module)||issues.some(m=>m.id===r.module))).sort((a,b)=>PRIO[a.priority]-PRIO[b.priority]).slice(0,2);
    const col={ok:'#B3E9C7',warn:'#F2A93B',crit:'#FF7A7A'};
    return `<div class="top"><div class="grow"><h1 style="font-size:32px;line-height:40px">Resultados de la muestra</h1><p class="muted row" style="gap:8px">${ic(METH_IC[last.method]||'cpu',16)}Día ${last.day} · ${METH[last.method]||last.method} · ${Object.keys(last.values).length} biomarcadores</p></div>
      <button class="btn ghost" id="cmp">${ic('history')}Comparar con muestra anterior</button></div>
    <div class="card rg" style="display:grid;grid-template-columns:620px 1fr;gap:32px;align-items:center">
      <svg viewBox="0 0 620 250" width="100%">${CONST_LINES.map(([a,b])=>`<line x1="${CONST_POS[a][0]}" y1="${CONST_POS[a][1]}" x2="${CONST_POS[b][0]}" y2="${CONST_POS[b][1]}" stroke="#5F5980" stroke-width="1" stroke-dasharray="3 4"/>`).join('')}
       ${MODS.map(m=>{const [x,y]=CONST_POS[m.id],st=status(m.id),c=ids.includes(m.id)||st!=='ok',cl=col[st];return `<g style="cursor:pointer" onclick="go('m-${m.id}')">
        ${ids.includes(m.id)?`<circle cx="${x}" cy="${y}" r="14" fill="${cl}" opacity=".25"><animate attributeName="r" values="12;22;12" dur="2s" repeatCount="indefinite"/><animate attributeName="opacity" values=".35;0;.35" dur="2s" repeatCount="indefinite"/></circle>`:''}
        <path transform="translate(${x-(c?11:7)} ${y-(c?11:7)}) scale(${c?.92:.58})" d="M12 2l2.6 6.9L22 9.3l-5.8 4.6L18.2 21 12 17l-6.2 4 2-7.1L2 9.3l7.4-.4z" fill="${cl}"/>
        <text x="${x}" y="${y+28}" text-anchor="middle" font-size="12" fill="${c?'#F0FFF1':'#B4B2D1'}" font-weight="${c?600:400}">${m.name}</text></g>`}).join('')}</svg>
      <div><div class="cap muted" style="letter-spacing:.08em">RESUMEN</div><h2 style="font-size:26px;line-height:34px;margin-top:6px">${title}</h2>
       <p class="muted" style="margin-top:8px">${MODS.length-issues.length} de ${MODS.length} sistemas están en tu rango personal. Toca una estrella para ver el detalle.</p>
       <div class="row" style="gap:8px;margin-top:16px;flex-wrap:wrap">${issues.map(m=>`<a href="#m-${m.id}" style="text-decoration:none">${chip(status(m.id))}</a><span class="small" style="margin-right:8px">${m.name}</span>`).join('')}</div></div></div>
    ${show.length?`<h2 style="margin:32px 0 16px">${ch.length?'Lo que cambió':'Lo que sigue en atención'}</h2>
    <div class="grid rg" style="grid-template-columns:repeat(${Math.min(2,show.length)},1fr)">${show.map(m=>{const k=keyBm(m),b=BM[k],st=status(m.id);const prev=val(k,S_LAST()-1),cur=val(k);
      const f=v=>b.bool?(v?'Positivo':'Negativo'):`${(+v).toFixed(b.d)}${b.u?' '+b.u:''}`;const r=rangeOf(k);
      return `<div class="card hov" onclick="go('m-${m.id}')"><div class="between"><div class="row">${ic(m.icon,22,'color:var(--lav2)')}<h3>${m.name} · ${b.n}</h3></div>${chip(st)}</div>
        <div class="row" style="gap:16px;margin-top:16px;align-items:baseline;flex-wrap:wrap"><span class="num muted" style="font:600 24px var(--ff-h)">${f(prev)}</span>${ic('right',20,'color:var(--text2)')}<span class="num" style="font:700 36px var(--ff-h);color:${{ok:'var(--ok)',warn:'var(--warn)',crit:'var(--crit)'}[sevOf(k)]}">${f(cur)}</span></div>
        <p class="small muted" style="margin-top:6px">${b.bool?'Lo esperado es negativo':`Tu rango: ${r.lo}–${r.hi}${b.u?' '+b.u:''}`}</p></div>`}).join('')}</div>`:''}
    <h2 style="margin:32px 0 16px">Todos los biomarcadores</h2>
    <div class="grid" style="gap:12px">${MODS.map((m,k)=>{const open=status(m.id)!=='ok';return `<div class="card" style="padding:0 24px"><button class="between accbtn" style="width:100%;height:68px" data-k="${k}"><span class="row">${ic(m.icon,20,'color:var(--lav2)')}<b>${m.name}</b><span class="small muted">${m.bms.length} biomarcadores</span></span><span class="row">${chip(status(m.id))}<span class="chev ${open?'open':''}">${ic('down')}</span></span></button>
      <div class="acc ${open?'open':''}"><div><div style="padding-bottom:12px">${m.bms.map(b=>bmRow(bmObj(b))).join('')}</div></div></div></div>`}).join('')}</div>
    ${recs.length?`<div class="between" style="margin:32px 0 16px"><h2>Recomendaciones para ti</h2><button class="btn ghost m" onclick="go('recomendaciones')">Ver todas ${ic('right',16)}</button></div>
    <div class="grid rg" style="grid-template-columns:1fr 1fr">${recs.map(r=>recCard(r)).join('')}</div>`:''}`;
  },
  bind(root){
    $$('.accbtn',root).forEach(b=>b.onclick=()=>{const acc=b.nextElementSibling;acc.classList.toggle('open');$('.chev',b).classList.toggle('open');animateMarks(acc)});
    $('#cmp',root).onclick=()=>toast(`Comparando con la muestra del día ${U.samples.at(-2)?.day??'—'}`,'history');
    bindRecs(root);
  }
};

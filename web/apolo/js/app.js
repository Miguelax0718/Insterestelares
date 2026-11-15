// =====================================================================
//  APOLO · interfaz (mascota + círculos flotantes + chat)
//  Los datos salen de db.js (demo, REST o Supabase) y la lógica de
//  estados de core.js. Aquí solo vive la UI.
// =====================================================================
const A={tips:false,lastAct:Date.now(),given:new Set(),spT:null,vis:[],open:null,ctx:null,voice:false,hc:false,listening:false,typing:null};
try{A.tips=localStorage.getItem('apolo-autotips')==='1';A.hc=localStorage.getItem('apolo-hc')==='1';A.voice=localStorage.getItem('apolo-voice')==='1'}catch(e){}
const BASE=['radiacion','renal','hidratacion','inmunidad','osea','estres','cardio','metabolismo'];
const SHORT={hidratacion:'Agua',renal:'Riñones',osea:'Huesos',radiacion:'Radiación',inmunidad:'Defensas',cardio:'Corazón',estres:'Sueño',metabolismo:'Energía'};
const SAY_ST={ok:'está estable',warn:'necesita atención',crit:'está en estado crítico'};
const first=()=>U.name.split(' ')[0];
const norm=t=>t.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').trim();
const esc=t=>String(t).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;
const ranked=()=>MODS.map(m=>({m,s:status(m.id)})).sort((a,b)=>sevOrder[a.s]-sevOrder[b.s]||BASE.indexOf(a.m.id)-BASE.indexOf(b.m.id));
const stChip=(s,size=14)=>{const [c,i,w]=ST[s];return `<span class="st ${c}">${ic(i,size)}${w}</span>`};
const avatar=(c,s=36)=>`<span class="av" style="--c:${c.color};width:${s}px;height:${s}px;font-size:${s*.38}px">${esc(c.initials||'?')}</span>`;

// ---------- Cielo ----------
function sky(){const cv=$('#sky'),x=cv.getContext('2d');let st=[],w,h;
  const size=()=>{w=cv.width=innerWidth*devicePixelRatio;h=cv.height=innerHeight*devicePixelRatio;
    st=Array.from({length:Math.round(innerWidth*innerHeight/5200)},()=>({x:Math.random()*w,y:Math.random()*h,r:(Math.random()*1.1+.3)*devicePixelRatio,p:Math.random()*6.3,v:.4+Math.random()}))};
  const draw=t=>{x.clearRect(0,0,w,h);for(const s of st){const a=A.hc?.5:.25+.45*(.5+.5*Math.sin(s.p+t/1000*s.v));x.globalAlpha=a;x.fillStyle='#F0FFF1';x.beginPath();x.arc(s.x,s.y,s.r,0,7);x.fill()}
    if(!reduced())requestAnimationFrame(draw)};
  size();addEventListener('resize',size);requestAnimationFrame(draw);
  const comet=()=>{const c=$('.comet');if(c&&!reduced()){c.classList.remove('go');void c.offsetWidth;c.style.top=(10+Math.random()*40)+'vh';c.classList.add('go')}setTimeout(comet,14000+Math.random()*12000)};setTimeout(comet,5000);}

// ---------- Estructura ----------
function shell(){
  $('#app').innerHTML=`
  <header class="top">
    <div class="brand">${window.APOLO_BACK?`<a class="back" href="${esc(window.APOLO_BACK)}" aria-label="Volver a AstraMed">${ic('left',22)}</a>`:''}<span class="logo">${ic('paw',20)}</span><b>APOLO</b><span class="mission muted" id="mission"></span></div>
    <div class="top-r">
      <button class="pill" id="samplePill"></button>
      <button class="who" id="whoBtn" aria-haspopup="true" aria-expanded="false"></button>
    </div>
  </header>
  <main class="stage">
    <div class="side sl" id="sl" aria-label="Tus datos"></div>
    <section class="pet" aria-label="Chat con Apolo">
      <div class="said" id="said" aria-hidden="true"></div>
      <div class="bubble" id="bubble"><p id="btext" aria-live="polite"></p><div class="chips" id="chips"></div></div>
      <button class="dogbtn" id="dogbtn" aria-label="Acariciar a Apolo"><span id="doghost"></span></button>
    </section>
    <div class="side sr" id="sr" aria-label="Más datos"></div>
  </main>
  <form class="ask" id="ask" autocomplete="off">
    <input id="q" enterkeyhint="send" placeholder="Pregúntale a Apolo…" aria-label="Escríbele a Apolo">
    <button type="submit" class="send" aria-label="Enviar">${ic('send',20)}</button>
    <button type="button" class="mic" id="mic" aria-label="Hablarle a Apolo">${ic('mic',26)}</button>
  </form>
  <div id="sheet"></div><div id="menu"></div>`;
  Dog.mount($('#doghost'));
  $('#dogbtn').onclick=()=>{Dog.wiggle();const tips=[`¡Guau! Estoy aquí para ti, ${first()}.`,'¿Me cuentas cómo te sientes hoy?','Si tocas un círculo te muestro todo lo de ese dato.','Puedes decirme “tomé 500 ml” y lo anoto.'];say(tips[Math.floor(Math.random()*tips.length)],baseChips())};
  $('#ask').onsubmit=e=>{e.preventDefault();const v=$('#q').value.trim();if(!v)return;$('#q').value='';ask(v)};
  $('#mic').onclick=listen;
  $('#whoBtn').onclick=e=>{e.stopPropagation();menu()};
  $('#samplePill').onclick=()=>answerSample();
  document.body.classList.toggle('hc',A.hc);
  addEventListener('keydown',e=>{if(e.key==='Escape'){closeSheet();closeMenu()}});
}

function paint(){
  $('#mission').textContent=`Día ${MISSION.day} · ${MISSION.name}`;
  $('#whoBtn').innerHTML=`${avatar(U,32)}<span class="who-n">${esc(first())}</span>${ic('down',18)}`;
  $('#whoBtn').setAttribute('aria-label',`Tripulante: ${U.name}. Cambiar de tripulante`);
  paintSample();resetOrbs();Dog.setMood(crewStatus());
}
function paintSample(){const st=sampleState(),p=$('#samplePill');
  p.className='pill'+(st.due?' due':'');
  p.innerHTML=`${ic(st.due?'flask':'clock',18)}<span class="pl-l">${st.due?'Toca tomar muestra':'Muestra en'}</span><b class="num">${st.due?'Ahora':st.short}</b>`;
  p.setAttribute('aria-label',st.title+'. '+st.sub);}
setInterval(()=>U&&paintSample(),30000);

// ---------- Círculos: aparecen cuando se piden ----------
// Al empezar solo salen los datos en alerta. Los demás salen del perrito
// cuando el tripulante pregunta por ellos (o pide "muéstrame todo").
const maxOrbs=()=>innerWidth<640?6:8;
const seedOf=id=>[...id].reduce((a,c)=>a+c.charCodeAt(0),0);
function resetOrbs(){A.vis=ranked().filter(x=>x.s!=='ok').slice(0,4).map(x=>x.m.id);orbs()}
function showOrbs(ids,{glowIt=true}={}){const fresh=ids.filter(id=>!A.vis.includes(id));
  A.vis.push(...fresh);
  while(A.vis.length>maxOrbs()){const keep=new Set(ids);const i=A.vis.findIndex(id=>!keep.has(id)&&status(id)==='ok');A.vis.splice(i<0?A.vis.findIndex(id=>!keep.has(id)):i,1)}
  orbs(fresh);if(glowIt)ids.forEach(glow)}
function hideOrb(id){const b=$(`.orb[data-m="${id}"]`),done=()=>{A.vis=A.vis.filter(x=>x!==id);orbs()};
  if(!b||reduced())return done();const d=toDog(b);
  b.animate([{transform:'none',opacity:1},{transform:`translate(${d.x}px,${d.y}px) scale(.1)`,opacity:0}],{duration:380,easing:'cubic-bezier(.5,0,.75,0)'}).onfinish=done}
function toDog(el){const a=el.getBoundingClientRect(),b=$('#dogbtn').getBoundingClientRect();return {x:b.left+b.width/2-(a.left+a.width/2),y:b.top+b.height/2-(a.top+a.height/2)}}
function orbs(fresh=[]){
  const order=A.vis.map(id=>({m:MOD[id],s:status(id)}));
  const cap=Math.ceil(order.length/2)||1;
  const html=(list,side)=>list.map(({m,s},i)=>{const k=m.key(),sz=s==='crit'?'L':s==='warn'?'M':'S',sd=seedOf(m.id),dur=6+sd%3;
    return `<div class="ow" style="--dur:${dur}s;--delay:-${((performance.now()/1000+sd)%dur).toFixed(2)}s;--dx:${sd%2?-6:6}px;--dy:${8+sd%4*2}px;--zz:${(i%2?1:-1)*(side==='l'?1:-1)}">
    <button class="orb s-${s} z-${sz}" data-m="${m.id}" aria-label="${m.name}: ${ST[s][2]}. ${k}, ${m.sub()}. Ver detalle">
      ${s!=='ok'?'<span class="halo" aria-hidden="true"></span>':''}
      <span class="ob-ic">${ic(m.icon,30)}</span>
      <span class="ob-v num">${esc(k)}</span>
      <span class="ob-n">${SHORT[m.id]}</span>
      ${stChip(s,14)}
    </button></div>`}).join('');
  const L=order.filter((_,i)=>i%2===0),Rr=order.filter((_,i)=>i%2===1);
  $('#sl').innerHTML=html(L,'l');$('#sr').innerHTML=html(Rr,'r');
  const many=innerWidth>=1000&&order.length>4;
  $('.stage').style.setProperty('--n',many?Math.ceil(cap/2):cap);$('.stage').classList.toggle('many',many);
  $('.stage').classList.toggle('empty',!order.length);
  $$('.orb[data-m]').forEach(b=>b.onclick=()=>openDetail(b.dataset.m,b));
  if(!reduced())fresh.forEach((id,j)=>{const b=$(`.orb[data-m="${id}"]`);if(!b)return;const d=toDog(b);
    b.animate([{transform:`translate(${d.x}px,${d.y}px) scale(.1)`,opacity:0},{opacity:1,offset:.35},{transform:'none',opacity:1}],{duration:700,delay:j*90,easing:'cubic-bezier(.2,.9,.25,1.15)',fill:'backwards'})});
}
let rzT;addEventListener('resize',()=>{clearTimeout(rzT);rzT=setTimeout(()=>{if(!U)return;if(A.vis.length>maxOrbs())A.vis=A.vis.slice(0,maxOrbs());orbs()},150)});

// ---------- Burbuja de chat ----------
function say(text,chips=[],{voice=true}={}){
  const p=$('#btext');clearInterval(A.typing);p.textContent='';
  const box=$('#chips');box.innerHTML='';
  const done=()=>{p.textContent=text;box.innerHTML=chips.map((c,i)=>`<button class="chip" data-i="${i}">${c.icon?ic(c.icon,16):''}${esc(c.t)}</button>`).join('');
    $$('.chip',box).forEach(b=>b.onclick=()=>{const c=chips[+b.dataset.i];c.fn?c.fn():ask(c.q||c.t)})};
  const b=$('#bubble');b.classList.remove('say');void b.offsetWidth;b.classList.add('say');
  const db=$('#dogbtn');db.classList.add('speaking');clearTimeout(A.spT);A.spT=setTimeout(()=>db.classList.remove('speaking'),Math.min(9000,1400+text.length*45));
  if(reduced()){done();Dog.talk(600)}
  else{let i=0;const step=Math.max(1,Math.ceil(text.length/90));Dog.talk(text.length/step*16+200);
    A.typing=setInterval(()=>{i+=step;p.textContent=text.slice(0,i);if(i>=text.length){clearInterval(A.typing);done()}},16)}
  if(voice&&A.voice&&'speechSynthesis' in window){speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(text.replace(/[·•]/g,','));u.lang='es-ES';u.pitch=1.25;u.rate=1.05;speechSynthesis.speak(u)}
}
function heard(t){const s=$('#said');s.textContent=t;s.classList.remove('show');void s.offsetWidth;s.classList.add('show')}
const baseChips=()=>[{t:'¿Cómo estoy?'},{t:'Dame un consejo',icon:'spark',fn:giveTip},{t:'Muéstrame todo',fn:showAll}];
function showAll(){const ids=ranked().map(x=>x.m.id).slice(0,maxOrbs());showOrbs(ids,{glowIt:false});
  say(ids.length<8?`Aquí tienes tus ${ids.length} datos más importantes. Tócalos para ver más.`:'¡Aquí están todos tus datos! Toca cualquiera para ver más.',[{t:'Solo lo urgente',fn:()=>{resetOrbs();say('Listo, solo lo urgente a la vista.',baseChips())}},{t:'¿Cómo estoy?'}])}

// ---------- “Cerebro” del chat (reglas simples, sin internet) ----------
const KEYS={hidratacion:/agua|hidrat|sed|beb|liquid/,renal:/rinon|renal|calculo|piedra|calcio|oxalato/,osea:/hueso|osea|ntx|ctx|fractur/,radiacion:/radiac|solar|tormenta|dosis|msv|eva/,
  inmunidad:/infecc|inmun|defens|nitrit|leucocit/,cardio:/corazon|cardio|sodio|potasio|sal\b|presion/,estres:/estres|sueno|dorm|melatonin|cortisol|ansie|cansad/,metabolismo:/metab|energ|comida|comer|ceton|proteina|hambre/};
function ask(raw){A.lastAct=Date.now();heard(raw);const t=norm(raw);
  let m;
  if(m=t.match(/(\d+[.,]?\d*)\s*(ml|mililitros?|l\b|litros?|vasos?)/)){if(/tome|bebi|tomo|bebo|agrega|anota|registra|suma/.test(t)||/vaso/.test(m[2])){
    const n=parseFloat(m[1].replace(',','.')),u=m[2];return addWater(Math.round(u.startsWith('vaso')?n*250:u.startsWith('l')?n*1000:n),true)}}
  if((m=t.match(/(\d+)\s*(min|minutos?|h\b|horas?)/))&&/ejercicio|entren|hice|corri|bici|pesas|fuerza|cinta|gym/.test(t)){const n=+m[1];return addExercise(m[2].startsWith('h')?n*60:n,true)}
  if(/gracias|genial|bien hecho|buen chico|lindo/.test(t))return say(`¡Guau! 🐾 Para eso estoy, ${first()}.`,baseChips());
  if(/(muestra|ensena|ver|dame)(me)? (todo|todos)|todos mis datos|todo$/.test(t))return showAll();
  if(/oculta|limpia|quita (los )?circulos|menos circulos/.test(t))return resetOrbs(),say('Listo, dejé a la vista solo lo que está en alerta.',baseChips());
  if(/cambiar|otro tripulante|cambia de|tripulantes|perfil/.test(t))return menu(),say('Elige quién va a usar APOLO ahora.',[]);
  const mod=Object.keys(KEYS).find(k=>KEYS[k].test(t));
  if(/por que|porque|para que sirve|importa/.test(t))return answerWhy(mod||A.ctx||ranked()[0].m.id);
  if(mod)return answerModule(mod);
  if(/muestra|orina|cuando toca|siguiente toma/.test(t))return answerSample();
  if(/como estoy|resumen|estado|como voy|todo bien|mis datos|alerta/.test(t))return answerSummary();
  if(/consejo|tip\b/.test(t))return giveTip();
  if(/que hago|recomend|ayuda|que debo|hoy/.test(t))return answerTodo();
  if(/^(hola|buen|hey|holi|que tal|saludos)/.test(t))return greet();
  say('Mmm, no estoy seguro de haber entendido 🐶. Puedo contarte cómo estás, qué hacer hoy o explicarte cualquier círculo.',baseChips());
}
function greet(){const list=ranked(),bad=list.filter(x=>x.s!=='ok'),st=sampleState();A.ctx=list[0].m.id;
  let t=`¡Hola, ${first()}! `;
  if(!U.samples.length)t+='Todavía no tengo tus datos. Cuando tomes tu primera muestra te digo cómo estás.';
  else if(bad[0]?.s==='crit')t+=`Hay algo urgente: tu dato de ${bad[0].m.name.toLowerCase()} ${SAY_ST.crit}. Toca el círculo rojo y te digo qué hacer.`;
  else if(bad.length)t+=`Casi todo va bien. ${bad.length===1?'Solo un dato necesita':`${bad.length} datos necesitan`} atención: ${bad.map(x=>x.m.name.toLowerCase()).join(' y ')}.`;
  else t+='¡Todo está estable hoy! Pregúntame por cualquier dato y te lo muestro 🐾';
  if(st.due&&U.samples.length)t+=' Ah, y ya toca tu muestra de orina.';
  const ch=bad[0]?[{t:`Ver ${SHORT[bad[0].m.id].toLowerCase()}`,fn:()=>openDetail(bad[0].m.id)},{t:'¿Qué hago hoy?'},{t:'Muéstrame todo',fn:showAll}]:baseChips();
  if(st.due)ch.unshift({t:'Ya tomé la muestra',icon:'flask',fn:submitSample});
  say(t,ch);
}
function answerModule(id){const m=MOD[id],s=status(id);A.ctx=id;showOrbs([id]);
  const r=recsFor(id)[0];
  say(`Tu ${m.name.toLowerCase()} ${SAY_ST[s]}: ${m.key()}, ${m.sub()}.${r?` Lo más importante ahora: ${r.text.charAt(0).toLowerCase()+r.text.slice(1)}.`:s==='ok'?' ¡Vas muy bien!':''}`,
    [{t:'Ver detalle',fn:()=>openDetail(id)},{t:'¿Por qué importa?'},{t:'¿Cómo estoy?'}]);}
function answerWhy(id){const m=MOD[id];A.ctx=id;showOrbs([id]);say(m.why,[{t:'Ver detalle',fn:()=>openDetail(id)},{t:'¿Qué hago hoy?'}])}
function answerSummary(){const list=ranked(),c=list.filter(x=>x.s==='crit'),w=list.filter(x=>x.s==='warn');showOrbs(c.concat(w).map(x=>x.m.id).slice(0,maxOrbs()));
  if(!U.samples.length)return say('Aún no tengo muestras tuyas. Con la primera creo tu línea base personal.',[{t:'Ya tomé la muestra',icon:'flask',fn:submitSample}]);
  const nm=a=>a.map(x=>SHORT[x.m.id].toLowerCase()).join(', ');
  let t=c.length||w.length?`${c.length?`${c.length} dato crítico (${nm(c)})`:''}${c.length&&w.length?' y ':''}${w.length?`${w.length} en atención (${nm(w)})`:''}. Lo demás está estable.`:'Todo está estable. ¡Excelente trabajo! 🐾';
  say(t.charAt(0).toUpperCase()+t.slice(1),(c.concat(w).slice(0,2).map(x=>({t:`Ver ${SHORT[x.m.id].toLowerCase()}`,fn:()=>answerModule(x.m.id)}))).concat([{t:'¿Qué hago hoy?'}]));}
function recsFor(id){const all=U.recs.filter(r=>!r.done&&(!id||r.module===id));return all.sort((a,b)=>PRIO[a.priority]-PRIO[b.priority]||sevOrder[status(a.module)]-sevOrder[status(b.module)])}
function answerTodo(){const r=recsFor()[0],st=sampleState();
  if(!r){const w=U.water<U.waterGoal?`Te faltan ${((U.waterGoal-U.water)/1000).toFixed(1)} L de agua`:'Ya cumpliste tu meta de agua';
    return say(`${w} y llevas ${U.exMin} de ${U.exGoal} min de ejercicio. ${st.due?'Y toca tu muestra.':''}`.trim(),[{t:'Tomé 250 ml',fn:()=>addWater(250,true)},{t:'Hice 15 min',fn:()=>addExercise(15,true)}])}
  A.ctx=r.module;showOrbs([r.module]);
  say(`${r.text}. ${r.why}`,[{t:'¡Hecho!',icon:'check',fn:()=>toggleRec(r.id,true)},{t:'Otra cosa'},{t:'Ver detalle',fn:()=>openDetail(r.module)}]);}
function answerSample(){const st=sampleState();
  if(st.due)return say(`${st.title}. ${st.sub}. Recuerda: muestra del chorro medio y pásala por el sensor.`,[{t:'Ya la tomé',icon:'flask',fn:submitSample},{t:'¿Cómo se toma?',fn:howSample}]);
  say(`Tu próxima muestra es ${st.sub.replace('Programada ','')}, en ${fmtDur(st.next-new Date())}. Te aviso cuando toque 🐾`,[{t:'¿Cómo se toma?',fn:howSample},{t:'¿Cómo estoy?'}]);}
function howSample(){say('Es fácil: 1) lávate las manos, 2) deja ir el primer chorro, 3) llena el recipiente con el chorro medio y 4) ciérralo y ponlo en el sensor. ¡Listo!',[{t:'Ya la tomé',icon:'flask',fn:submitSample}])}
async function submitSample(){await DB.saveSample({method:'sensor'});paint();say(`¡Muestra recibida! 🐾 Ya analicé tus datos. La siguiente es en ${fmtDur(sampleState().next-new Date())}.`,[{t:'¿Cómo estoy?'}]);burst($('#samplePill'))}
function toggleRec(id,done){const r=U.recs.find(x=>x.id===id);if(!r)return;r.done=done;DB.run('setRec',id,done);if(done){Dog.wiggle();say('¡Buen trabajo! Lo marqué como hecho ✨',[{t:'¿Qué más hago?',q:'¿Qué hago hoy?'}])}if(A.open)openDetail(A.open,null,true)}
function glow(id){const b=$(`.orb[data-m="${id}"]`);if(!b)return;b.classList.remove('ping');void b.offsetWidth;b.classList.add('ping')}

// ---------- Consejos espontáneos ----------
// Si el tripulante no ha interactuado en un rato, Apolo le da un consejo
// basado en sus datos (recomendaciones pendientes, agua, ejercicio, sueño,
// muestra) o uno general de salud en el espacio. No repite hasta agotarlos.
const GENERAL=[
  'Cada hora, estira cuello y espalda un minuto. En microgravedad la columna se alarga y duele si no la mueves.',
  'Descansa la vista: mira por la ventana hacia la Tierra 20 segundos cada 20 minutos de pantalla.',
  'Come a tus horas aunque no tengas hambre. En misiones largas es fácil comer menos de lo que necesitas.',
  'Habla un rato con alguien de la tripulación o con tu familia. Sentirse acompañado también es salud.',
  'Antes de dormir baja las luces de tu cabina. Ayuda a que tu cuerpo produzca melatonina.',
];
function tipCandidates(){const out=[],st=sampleState();
  recsFor().forEach(r=>out.push({k:'r'+r.id,mod:r.module,t:`${r.text}. ${r.why}`,ch:[{t:'¡Hecho!',icon:'check',fn:()=>toggleRec(r.id,true)}]}));
  if(st.due&&U.samples.length)out.push({k:'due',t:'No olvides tu muestra de orina, ya está pendiente. Con ella actualizo tus datos.',ch:[{t:'Ya la tomé',icon:'flask',fn:submitSample}]});
  else if(!st.due&&st.next-new Date()<60*60000)out.push({k:'soon',t:`Tu próxima muestra es en ${fmtDur(st.next-new Date())}. Ve tomando agua para que salga bien.`,ch:[]});
  if(U.water<U.waterGoal)out.push({k:'w'+Math.floor(U.water/500),mod:'hidratacion',t:`¿Un vaso de agua? Te faltan ${((U.waterGoal-U.water)/1000).toFixed(1)} L para tu meta. En el espacio casi no se siente sed.`,ch:[{t:'Tomé 250 ml',fn:()=>addWater(250,true)}]});
  if(U.exMin<U.exGoal)out.push({k:'e'+Math.floor(U.exMin/15),mod:'osea',t:`Te faltan ${U.exGoal-U.exMin} min de ejercicio hoy. Con 15 min de fuerza ya ayudas a tus huesos.`,ch:[{t:'Hice 15 min',fn:()=>addExercise(15,true)}]});
  if(U.sleep<7)out.push({k:'sleep',mod:'estres',t:`Anoche dormiste ${hm(U.sleep)}. Intenta acostarte un poco antes hoy; dormir bien protege tus defensas.`,ch:[]});
  GENERAL.forEach((t,i)=>out.push({k:'g'+i,t,ch:[]}));
  return out}
function giveTip(){const all=tipCandidates();let c=all.find(x=>!A.given.has(x.k));
  if(!c){A.given.clear();c=all[0]}A.given.add(c.k);
  Dog.wiggle();if(c.mod){A.ctx=c.mod;showOrbs([c.mod])}
  say('Consejo: '+c.t,c.ch.concat([{t:'Otro consejo',fn:giveTip},{t:'Gracias',fn:()=>say('¡De nada! Aquí estoy si me necesitas 🐾',[])}]));
  A.lastAct=Date.now()}
let tipGap=25000;
setInterval(()=>{if(!U||!A.tips||!U.samples.length)return;
  const busy=A.open||$('#menu')?.classList.contains('on')||A.listening||$('#q')?.value||document.visibilityState!=='visible';
  if(busy){A.lastAct=Date.now();return}
  if(Date.now()-A.lastAct>tipGap){giveTip();tipGap=40000+Math.random()*30000}},4000);
['pointerdown','keydown'].forEach(ev=>addEventListener(ev,()=>A.lastAct=Date.now(),{passive:true}));

// ---------- Registro de agua y ejercicio ----------
function addWater(ml,talk){if(!(ml>=50&&ml<=2000)){say('Puedo anotar entre 50 y 2000 ml de una vez.',[]);return false}
  U.water+=ml;DB.run('addWater',U.id,ml);showOrbs(['hidratacion'],{glowIt:false});orbs();if(A.open==='hidratacion')openDetail('hidratacion',null,true);
  const left=U.waterGoal-U.water;if(talk!==false)say(`¡Anotado! +${ml} ml. ${left>0?`Te faltan ${(left/1000).toFixed(1)} L para tu meta.`:'¡Cumpliste tu meta de agua de hoy! 💧'}`,[{t:'Tomé 250 ml',fn:()=>addWater(250,true)},{t:'¿Cómo estoy?'}]);
  Dog.wiggle();return true}
function addExercise(min,talk){if(!(min>=1&&min<=300)){say('Puedo anotar entre 1 y 300 minutos de ejercicio.',[]);return false}
  U.exMin+=min;U.sessions+=1;DB.run('addExercise',U.id,{type:'fuerza',min});showOrbs(['osea'],{glowIt:false});if(A.open==='osea')openDetail('osea',null,true);
  if(talk!==false)say(`¡Guau, ${min} min más! Llevas ${U.exMin} de ${U.exGoal} min hoy. El ejercicio de fuerza protege tus huesos 🦴`,[{t:'¿Cómo están mis huesos?',q:'huesos'}]);
  Dog.wiggle();return true}

// ---------- Detalle de un círculo ----------
function bmLine(k){const b=bmObj(k),s=sevOf(k);
  if(b.t)return `<li class="bm"><span class="bm-n">${b.n}</span><span class="bm-v">${b.t}</span><span class="bm-bar"></span>${stChip(s,13)}</li>`;
  const p=v=>Math.max(0,Math.min(100,(v-b.min)/(b.max-b.min)*100));
  return `<li class="bm"><span class="bm-n">${b.n}</span><span class="bm-v num">${fx(k)} <small>${b.u}</small></span>
    <span class="bm-bar" aria-hidden="true"><i class="band" style="left:${p(b.lo)}%;width:${p(b.hi)-p(b.lo)}%"></i><i class="dot s-${s}" style="left:${p(b.v)}%"></i></span>${stChip(s,13)}</li>`}
function logBox(id){
  if(id==='hidratacion'){const pct=Math.min(100,U.water/U.waterGoal*100);
    return `<div class="log"><div class="log-h"><b>Agua de hoy</b><span class="num">${(U.water/1000).toFixed(1)} / ${(U.waterGoal/1000).toFixed(1)} L</span></div>
    <div class="prog"><i style="width:${pct}%"></i></div>
    <div class="log-r"><button class="qb" data-w="250">+250 ml</button><button class="qb" data-w="500">+500 ml</button>
    <form class="cf" data-k="w" novalidate><input type="number" inputmode="numeric" min="50" max="2000" placeholder="Otra (ml)" aria-label="Cantidad de agua en mililitros"><button class="qb">Anotar</button></form></div></div>`}
  if(id==='osea'){const pct=Math.min(100,U.exMin/U.exGoal*100);
    return `<div class="log"><div class="log-h"><b>Ejercicio de hoy</b><span class="num">${U.exMin} / ${U.exGoal} min</span></div>
    <div class="prog"><i style="width:${pct}%"></i></div>
    <div class="log-r"><button class="qb" data-e="15">+15 min</button><button class="qb" data-e="30">+30 min</button>
    <form class="cf" data-k="e" novalidate><input type="number" inputmode="numeric" min="1" max="300" placeholder="Otro (min)" aria-label="Minutos de ejercicio"><button class="qb">Anotar</button></form></div></div>`}
  return ''}
function openDetail(id,from,refresh){const m=MOD[id],s=status(id),recs=U.recs.filter(r=>r.module===id);A.open=id;A.ctx=id;
  const vals=series(m.primary,14).map(Number).filter(v=>!isNaN(v));
  const html=`<div class="scrim" data-close></div>
  <div class="card s-${s}" role="dialog" aria-modal="true" aria-labelledby="dt">
    <div class="grab" aria-hidden="true"></div>
    <header class="c-h"><span class="c-ic">${ic(m.icon,26)}</span><div><h2 id="dt">${m.name}</h2><p class="muted small">${m.measures}</p></div>
      <button class="x" data-close aria-label="Cerrar">${ic('x',22)}</button></header>
    <div class="c-key"><div><b class="num">${esc(m.key())}</b><span class="muted">${esc(m.sub())}</span></div>${stChip(s,16)}</div>
    ${logBox(id)}
    ${recs.length?`<h3>Qué hacer</h3><ul class="recs">${recs.map(r=>`<li class="${r.done?'done':''}"><button class="rk" data-r="${r.id}" aria-pressed="${r.done}" aria-label="Marcar como hecho">${ic('check',18)}</button><div><b>${esc(r.text)}</b><p class="muted small">${esc(r.why)}</p></div></li>`).join('')}</ul>`:
      `<p class="calm">${s==='ok'?'Todo en orden aquí. Sigue con tu rutina 🐾':'Revisa los valores de abajo y consulta con la oficial médica si tienes síntomas.'}</p>`}
    ${U.samples.length?`<h3>Lo que dice tu orina</h3><ul class="bms">${m.bms.map(bmLine).join('')}</ul>
    ${vals.length>1?`<div class="trend"><span class="muted small">${BM[m.primary].n} · últimas ${vals.length} muestras</span>${spark(vals,300,56,'var(--lav2)')}</div>`:''}`:''}
    <details class="why"><summary>¿Por qué importa en el espacio?</summary><p>${m.why}</p></details>
    <div class="c-act"><button class="btn" id="askApolo">${ic('paw',20)} Pregúntale a Apolo</button>${s==='ok'?`<button class="btn ghost" id="hideO">${ic('eyeoff',20)} Quitar de la vista</button>`:''}</div>
  </div>`;
  const root=$('#sheet');root.innerHTML=html;root.classList.add('on');
  const card=$('.card',root);
  if(!refresh&&!reduced()){const narrow=innerWidth<760;
    if(from&&!narrow){const a=from.getBoundingClientRect(),b=card.getBoundingClientRect();
      card.animate([{transform:`translate(${a.left+a.width/2-(b.left+b.width/2)}px,${a.top+a.height/2-(b.top+b.height/2)}px) scale(.2)`,opacity:0,borderRadius:'50%'},{transform:'none',opacity:1}],{duration:420,easing:'cubic-bezier(.2,.9,.25,1.1)'})}
    else card.animate([{transform:narrow?'translateY(100%)':'scale(.9)',opacity:narrow?1:0},{transform:'none',opacity:1}],{duration:340,easing:'cubic-bezier(.2,.8,.2,1)'});
    $('.scrim',root).animate([{opacity:0},{opacity:1}],{duration:250})}
  $$('[data-close]',root).forEach(b=>b.onclick=closeSheet);
  $$('.rk',root).forEach(b=>b.onclick=()=>toggleRec(b.dataset.r,b.getAttribute('aria-pressed')!=='true'));
  $$('[data-w]',root).forEach(b=>b.onclick=()=>addWater(+b.dataset.w,true));
  $$('[data-e]',root).forEach(b=>b.onclick=()=>addExercise(+b.dataset.e,true));
  $$('.cf',root).forEach(f=>f.onsubmit=e=>{e.preventDefault();const v=+$('input',f).value;const ok=f.dataset.k==='w'?addWater(v,true):addExercise(v,true);if(!ok)$('input',f).focus()});
  $('#askApolo').onclick=()=>{closeSheet();answerModule(id)};
  $('#hideO')&&($('#hideO').onclick=()=>{closeSheet();setTimeout(()=>hideOrb(id),240)});
  if(!refresh){$('.x',root).focus({preventScroll:true});glow(id)}
  // arrastrar hacia abajo para cerrar (celular)
  let y0=null;const g=$('.grab',root);g.onpointerdown=e=>{y0=e.clientY;g.setPointerCapture(e.pointerId)};
  g.onpointermove=e=>{if(y0!=null)card.style.transform=`translateY(${Math.max(0,e.clientY-y0)}px)`};
  g.onpointerup=e=>{if(y0!=null&&e.clientY-y0>90)closeSheet();else card.style.transform='';y0=null};
}
function closeSheet(){const root=$('#sheet');if(!root.classList.contains('on'))return;const id=A.open;A.open=null;
  const card=$('.card',root),done=()=>{root.classList.remove('on');root.innerHTML='';$(`.orb[data-m="${id}"]`)?.focus({preventScroll:true})};
  if(reduced()||!card)return done();
  card.animate([{opacity:1},{transform:innerWidth<760?'translateY(100%)':'scale(.92)',opacity:innerWidth<760?1:0}],{duration:220,easing:'ease-in'}).onfinish=done;
  $('.scrim',root).animate([{opacity:1},{opacity:0}],{duration:220,fill:'forwards'})}

// ---------- Menú de tripulante ----------
function menu(){const root=$('#menu');if(root.classList.contains('on'))return closeMenu();
  root.innerHTML=`<div class="scrim" data-close></div><div class="pop" role="dialog" aria-label="Cambiar de tripulante">
    <p class="cap muted">Tripulación</p>
    <div class="crew">${CREW.map(c=>{const u=DB.cache[c.id],s=u&&u.samples.length?(()=>{const keep=U;U=u;const r=crewStatus();U=keep;return r})():'ok';
      return `<button class="cm ${c.id===U.id?'on':''}" data-id="${c.id}">${avatar(c,40)}<span class="cm-t"><b>${esc(c.name)}</b><span class="muted small">${esc(c.role)}</span></span>${stChip(s,13)}${c.id===U.id?`<span class="ck">${ic('check',18)}</span>`:''}</button>`}).join('')}</div>
    <button class="cm add" id="addC">${ic('plus',20)} Agregar tripulante</button>
    <form class="addf" id="addF" hidden><input id="nName" placeholder="Nombre y apellido" aria-label="Nombre"><input id="nRole" placeholder="Rol (ej. Ingeniera de vuelo)" aria-label="Rol"><p class="err" id="nErr" role="alert"></p><button class="btn">Agregar</button></form>
    <hr>
    <label class="tg"><span>${ic('spark',20)} Consejos automáticos (sin preguntar)</span><input type="checkbox" id="tipT" ${A.tips?'checked':''}><i></i></label>
    <label class="tg"><span>${ic('contrast',20)} Modo cabina (alto contraste)</span><input type="checkbox" id="hcT" ${A.hc?'checked':''}><i></i></label>
    ${'speechSynthesis' in window?`<label class="tg"><span>${ic('vol',20)} Apolo habla en voz alta</span><input type="checkbox" id="vT" ${A.voice?'checked':''}><i></i></label>`:''}
  </div>`;
  root.classList.add('on');$('#whoBtn').setAttribute('aria-expanded','true');
  if(!reduced())$('.pop',root).animate([{opacity:0,transform:innerWidth<760?'translateY(40px)':'translateY(-8px) scale(.97)'},{opacity:1,transform:'none'}],{duration:240,easing:'cubic-bezier(.2,.8,.2,1)'});
  $$('[data-close]',root).forEach(b=>b.onclick=closeMenu);
  $$('.cm[data-id]',root).forEach(b=>b.onclick=()=>{closeMenu();closeSheet();if(b.dataset.id!==U.id){DB.use(b.dataset.id);paint();greet()}});
  $('#addC').onclick=()=>{$('#addF').hidden=false;$('#addC').hidden=true;$('#nName').focus()};
  $('#addF').onsubmit=async e=>{e.preventDefault();const n=$('#nName').value.trim(),r=$('#nRole').value.trim();
    if(n.length<3)return $('#nErr').textContent='Escribe el nombre (mínimo 3 letras).';
    const id=norm(n).replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||'tripulante';
    if(CREW.some(c=>c.id===id))return $('#nErr').textContent='Ya hay un tripulante con ese nombre.';
    const ini=n.split(/\s+/).map(w=>w[0]).join('').slice(0,2).toUpperCase(),cols=['#B3E9C7','#A994E0','#FFD9A0','#9FD8FF','#F5B8D0'];
    try{await DB.addCrew({id,name:n,role:r||'Tripulante',initials:ini,color:cols[CREW.length%cols.length],age:35,weight:70,height:1.7,dose:0,hr:70,bp:'120/80',water:0,waterGoal:2500,sleep:7,sessions:0,energy:60,protein:60,mood:2,exMin:0,exGoal:90});
      closeMenu();DB.use(id);paint();greet()}catch(err){$('#nErr').textContent=err.message}};
  $('#tipT').onchange=e=>{A.tips=e.target.checked;try{localStorage.setItem('apolo-autotips',A.tips?'1':'0')}catch(_){}};
  $('#hcT').onchange=e=>{A.hc=e.target.checked;document.body.classList.toggle('hc',A.hc);try{localStorage.setItem('apolo-hc',A.hc?'1':'0')}catch(_){}};
  $('#vT')&&($('#vT').onchange=e=>{A.voice=e.target.checked;try{localStorage.setItem('apolo-voice',A.voice?'1':'0')}catch(_){}if(!A.voice)speechSynthesis.cancel();else say('¡Guau! Ahora también te hablo en voz alta.',[])});
}
function closeMenu(){const root=$('#menu');if(!root.classList.contains('on'))return;root.classList.remove('on');root.innerHTML='';$('#whoBtn').setAttribute('aria-expanded','false')}

// ---------- Voz (dictado) ----------
function listen(){const SR=window.SpeechRecognition||window.webkitSpeechRecognition,mic=$('#mic');
  if(!SR){toast('Tu navegador no permite dictado. Escríbele a Apolo 🐾');$('#q').focus();return}
  if(A.listening){A.rec?.stop();return}
  const r=new SR();A.rec=r;r.lang='es-ES';r.interimResults=true;
  r.onstart=()=>{A.listening=true;mic.classList.add('on');Dog.perk(true);say('Te escucho…',[],{voice:false})};
  r.onresult=e=>{const t=[...e.results].map(x=>x[0].transcript).join('');$('#q').value=t;if(e.results[e.results.length-1].isFinal){$('#q').value='';ask(t)}};
  r.onerror=e=>{if(e.error==='not-allowed')toast('Permite el micrófono para hablarle a Apolo');};
  r.onend=()=>{A.listening=false;mic.classList.remove('on');Dog.perk(false)};
  try{r.start()}catch(e){}}

// ---------- Utilidades ----------
function toast(msg){let box=$('#toasts');const t=document.createElement('div');t.className='toast';t.textContent=msg;box.appendChild(t);setTimeout(()=>{t.classList.add('out');setTimeout(()=>t.remove(),300)},2600)}
function burst(el){if(!el||reduced())return;const r=el.getBoundingClientRect();
  for(let k=0;k<10;k++){const s=document.createElement('i');s.className='spk';const a=Math.PI*2*k/10,d=30+Math.random()*26;
    s.style.cssText=`left:${r.left+r.width/2}px;top:${r.top+r.height/2}px;--dx:${Math.cos(a)*d}px;--dy:${Math.sin(a)*d}px`;document.body.appendChild(s);setTimeout(()=>s.remove(),900)}}

// ---------- Arranque ----------
(async()=>{sky();shell();
  await DB.init();await DB.loadAll();
  let id=null;try{id=localStorage.getItem('apolo-user')}catch(e){}
  DB.use(CREW.some(c=>c.id===id)?id:CREW[0].id);
  paint();setTimeout(greet,350);
  if(DB.source==='demo'&&DB.error)toast('Sin conexión a la base de datos: uso datos de demostración');
})();

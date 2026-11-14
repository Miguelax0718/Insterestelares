// =====================================================================
//  GUÍAS ANIMADAS DE PROCEDIMIENTOS Y PRIMEROS AUXILIOS
//  Cada paso es una escena SVG animada con CSS (funciona offline).
//  Si el equipo exporta animaciones Lottie, basta con poner `lottie:'ruta.json'`
//  en el paso y cargar lottie-web: el reproductor la usa en lugar del SVG.
// =====================================================================
const G_INK='#F0FFF1',G_LAV='#A994E0',G_BLUE='#0E34A0',G_DIM='#5F5980';
const scene=(inner)=>`<svg viewBox="0 0 320 200" class="gsvg" aria-hidden="true">${inner}</svg>`;
const SCENES={
  // --- Tomar la muestra ---
  manos:scene(`<path d="M140 20h60v14h-14v12h-18V34h-28z" fill="${G_DIM}"/>${[0,1,2,3].map(i=>`<ellipse class="g-drop" style="animation-delay:${i*.35}s" cx="${170+(i%2)*6}" cy="58" rx="3" ry="5" fill="${G_LAV}"/>`).join('')}
    <g class="g-rub"><ellipse cx="146" cy="128" rx="34" ry="20" fill="#F0D7C0" transform="rotate(-18 146 128)"/></g><g class="g-rub2"><ellipse cx="190" cy="128" rx="34" ry="20" fill="#E7C6AE" transform="rotate(18 190 128)"/></g>
    ${[0,1,2,3,4].map(i=>`<circle class="g-bub" style="animation-delay:${i*.4}s" cx="${140+i*14}" cy="110" r="${4+i%3}" fill="none" stroke="${G_INK}" stroke-width="1.5"/>`).join('')}`),
  colector:scene(`<defs><clipPath id="gcup"><path d="M120 50h80l-8 120h-64z"/></clipPath></defs><g clip-path="url(#gcup)"><rect class="g-fill" x="110" y="50" width="100" height="120" fill="#FFD23F" fill-opacity=".75"/></g>
    <path d="M120 50h80l-8 120h-64z" fill="none" stroke="${G_INK}" stroke-width="3" stroke-linejoin="round"/><path d="M114 50h92" stroke="${G_INK}" stroke-width="3" stroke-linecap="round"/>
    ${[0,1,2].map(i=>`<path d="M${132} ${80+i*28}h10" stroke="${G_INK}" stroke-opacity=".6" stroke-width="2"/>`).join('')}<text x="160" y="190" text-anchor="middle" fill="${G_LAV}" font-size="11">Colector de microgravedad</text>`),
  sensor:scene(`<rect x="90" y="96" width="140" height="84" rx="16" fill="#1C1D3D" stroke="${G_LAV}" stroke-width="2.5"/><rect x="148" y="90" width="24" height="12" rx="3" fill="${G_DIM}"/>
    <circle class="g-blink" cx="114" cy="160" r="7" fill="#5BE38C"/><rect x="130" y="155" width="80" height="10" rx="5" fill="${G_DIM}"/>
    <g class="g-down"><rect x="150" y="20" width="20" height="64" rx="8" fill="none" stroke="${G_INK}" stroke-width="2.5"/><rect x="152" y="46" width="16" height="36" rx="6" fill="#FFD23F" fill-opacity=".8"/><rect x="146" y="14" width="28" height="9" rx="3" fill="${G_LAV}"/></g>`),
  registrar:scene(`<rect x="100" y="24" width="120" height="156" rx="16" fill="#1C1D3D" stroke="${G_LAV}" stroke-width="2.5"/><text x="160" y="52" text-anchor="middle" fill="${G_INK}" font-size="12" font-weight="700" letter-spacing="2">URANO</text>
    <circle cx="160" cy="108" r="32" fill="none" stroke="#5BE38C" stroke-width="3" stroke-opacity=".35"/><path class="g-draw" d="M144 108l11 11 21-23" fill="none" stroke="#5BE38C" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="124" y="152" width="72" height="12" rx="6" fill="${G_DIM}"/>`),
  // --- Leer la tira reactiva ---
  sumergir:scene(`<path d="M110 90h100l-8 90h-84z" fill="#FFD23F" fill-opacity=".25" stroke="${G_INK}" stroke-width="3"/><rect x="114" y="120" width="92" height="56" fill="#FFD23F" fill-opacity=".55"/>
    <g class="g-dip"><rect x="152" y="10" width="16" height="130" rx="3" fill="${G_INK}"/>${[0,1,2,3,4].map(i=>`<rect x="154" y="${80+i*11}" width="12" height="8" rx="1.5" fill="${['#5BE38C','#FFD23F','#A994E0','#8367C7','#FF5A5F'][i]}"/>`).join('')}</g><text x="240" y="60" fill="${G_LAV}" font-size="14" font-weight="700">1 s</text>`),
  esperar:scene(`<circle cx="160" cy="100" r="60" fill="none" stroke="${G_DIM}" stroke-width="10"/><circle class="g-sweep" cx="160" cy="100" r="60" fill="none" stroke="${G_LAV}" stroke-width="10" stroke-linecap="round" stroke-dasharray="377" transform="rotate(-90 160 100)"/>
    <text x="160" y="108" text-anchor="middle" fill="${G_INK}" font-size="28" font-weight="700" font-family="Space Grotesk">60 s</text><path d="M150 26h20M160 26v14" stroke="${G_INK}" stroke-width="4" stroke-linecap="round"/>`),
  comparar:scene(`<rect x="70" y="30" width="22" height="150" rx="4" fill="${G_INK}"/>${[0,1,2,3,4,5].map(i=>`<rect x="73" y="${40+i*22}" width="16" height="14" rx="2" fill="${G_DIM}"><animate attributeName="fill" values="${G_DIM};${['#5BE38C','#FFD23F','#A994E0','#8367C7','#C2F8CB','#FF5A5F'][i]}" dur="1.2s" begin="${i*.3}s" fill="freeze"/></rect>`).join('')}
    ${[0,1,2,3,4,5].map(i=>`<g transform="translate(140 ${40+i*22})">${['#C2F8CB','#5BE38C','#FFD23F','#FF5A5F'].map((c,j)=>`<rect x="${j*34}" width="26" height="14" rx="2" fill="${c}" fill-opacity="${.35+j*.15}"/>`).join('')}</g>`).join('')}
    <rect class="g-scan" x="60" y="36" width="230" height="20" rx="4" fill="none" stroke="${G_INK}" stroke-width="2"/>`),
  foto:scene(`<rect x="148" y="40" width="24" height="130" rx="4" fill="${G_INK}"/>${[0,1,2,3,4].map(i=>`<rect x="151" y="${54+i*22}" width="18" height="14" rx="2" fill="${['#5BE38C','#FFD23F','#A994E0','#8367C7','#FF5A5F'][i]}"/>`).join('')}
    <path d="M100 30v-14h24M220 30v-14h-24M100 170v14h24M220 170v14h-24" fill="none" stroke="${G_LAV}" stroke-width="4" stroke-linecap="round"/><rect class="g-flash" x="0" y="0" width="320" height="200" fill="#fff"/>`),
  // --- Refugio ante tormenta solar ---
  alerta:scene(`<g class="g-spin" style="transform-origin:110px 100px"><circle cx="110" cy="100" r="34" fill="#FFD23F"/>${[...Array(12)].map((_,i)=>`<path d="M110 100m${Math.cos(i*Math.PI/6)*44} ${Math.sin(i*Math.PI/6)*44}l${Math.cos(i*Math.PI/6)*14} ${Math.sin(i*Math.PI/6)*14}" stroke="#FFD23F" stroke-width="5" stroke-linecap="round"/>`).join('')}</g>
    <g class="g-pulse" style="transform-origin:230px 104px"><path d="M230 64l42 74h-84z" fill="#FF5A5F"/><path d="M230 90v24M230 124v4" stroke="#fff" stroke-width="6" stroke-linecap="round"/></g>`),
  blindaje:scene(`<rect x="210" y="50" width="90" height="110" rx="14" fill="#1C1D3D" stroke="${G_LAV}" stroke-width="4"/><path d="M226 66h58M226 144h58" stroke="${G_LAV}" stroke-width="3" stroke-dasharray="6 6"/><text x="255" y="182" text-anchor="middle" fill="${G_LAV}" font-size="11">Zona blindada</text>
    <path d="M30 140H205" stroke="${G_DIM}" stroke-width="3" stroke-dasharray="4 8"/><g class="g-walk"><circle cx="40" cy="100" r="14" fill="#2F3061" stroke="${G_INK}" stroke-width="3"/><path d="M33 98a7 6 0 0 1 14 0z" fill="${G_BLUE}"/><path d="M24 140c0-18 7-26 16-26s16 8 16 26z" fill="#2F3061" stroke="${G_INK}" stroke-width="3"/></g>`),
  provisiones:scene(`<circle cx="160" cy="84" r="16" fill="#2F3061" stroke="${G_INK}" stroke-width="3"/><path d="M152 82a8 7 0 0 1 16 0z" fill="${G_BLUE}"/><path d="M140 132c0-22 9-30 20-30s20 8 20 30z" fill="#2F3061" stroke="${G_INK}" stroke-width="3"/>
    ${[[96,140],[96,112],[96,84],[204,140],[204,112],[204,84],[132,152],[168,152]].map(([x,y],i)=>`<rect class="g-stack" style="animation-delay:${i*.35}s" x="${x}" y="${y}" width="${i>5?20:22}" height="26" rx="6" fill="${i%2?'#0E34A0':'#A994E0'}" fill-opacity=".85"/>`).join('')}`),
  esperarfin:scene(`<rect x="70" y="80" width="180" height="26" rx="13" fill="#1C1D3D" stroke="${G_DIM}" stroke-width="2"/><rect class="g-drain" x="72" y="82" width="176" height="22" rx="11" fill="#FF5A5F"/>
    <text x="160" y="140" text-anchor="middle" fill="${G_INK}" font-size="13">Dosímetro de cabina</text><circle cx="160" cy="42" r="18" fill="none" stroke="#5BE38C" stroke-width="3"/><path class="g-draw late" d="M151 42l6 6 11-12" fill="none" stroke="#5BE38C" stroke-width="4" stroke-linecap="round"/>`),
  // --- Dolor lumbar intenso ---
  avisar:scene(`<circle cx="110" cy="92" r="20" fill="#2F3061" stroke="${G_INK}" stroke-width="3"/><path d="M100 90a10 9 0 0 1 20 0z" fill="${G_BLUE}"/><path d="M84 160c0-28 12-40 26-40s26 12 26 40z" fill="#2F3061" stroke="${G_INK}" stroke-width="3"/>
    ${[0,1,2].map(i=>`<path class="g-wave" style="animation-delay:${i*.35}s" d="M${150+i*16} ${70-i*6}q${14+i*4} ${22+i*6} 0 ${44+i*12}" fill="none" stroke="${G_LAV}" stroke-width="4" stroke-linecap="round"/>`).join('')}
    <rect x="214" y="70" width="70" height="44" rx="10" fill="#1C1D3D" stroke="${G_LAV}" stroke-width="2"/><path d="M249 82v20M239 92h20" stroke="#FF5A5F" stroke-width="5" stroke-linecap="round"/>`),
  dolor:scene(`<rect x="40" y="100" width="240" height="14" rx="7" fill="url(#gpain)"/><defs><linearGradient id="gpain"><stop offset="0" stop-color="#5BE38C"/><stop offset=".5" stop-color="#FFD23F"/><stop offset="1" stop-color="#FF5A5F"/></linearGradient></defs>
    ${[0,2,4,6,8,10].map((n,i)=>`<text x="${40+i*48}" y="138" text-anchor="middle" fill="${G_INK}" font-size="12">${n}</text>`).join('')}<g class="g-slide"><circle cx="40" cy="107" r="13" fill="${G_INK}"/></g>
    <text x="160" y="70" text-anchor="middle" fill="${G_INK}" font-size="15" font-weight="600">¿Cuánto te duele?</text>`),
  agua:scene(`<defs><clipPath id="gglass"><path d="M126 40h68l-7 130h-54z"/></clipPath></defs><g clip-path="url(#gglass)"><rect class="g-fill" x="120" y="40" width="80" height="130" fill="${G_LAV}" fill-opacity=".8"/></g><path d="M126 40h68l-7 130h-54z" fill="none" stroke="${G_INK}" stroke-width="3" stroke-linejoin="round"/>
    <ellipse class="g-drop" cx="160" cy="20" rx="4" ry="6" fill="${G_LAV}"/><text x="236" y="110" fill="${G_LAV}" font-size="13" font-weight="700">250 ml</text>`),
  botiquin:scene(`<rect x="100" y="90" width="120" height="80" rx="12" fill="#FF5A5F"/><path d="M160 112v36M142 130h36" stroke="#fff" stroke-width="8" stroke-linecap="round"/><g class="g-lid" style="transform-origin:100px 90px"><rect x="96" y="74" width="128" height="20" rx="8" fill="#E04449"/></g>
    <rect x="148" y="60" width="24" height="16" rx="5" fill="none" stroke="#E04449" stroke-width="4"/><g class="g-pill"><rect x="236" y="96" width="34" height="14" rx="7" fill="${G_INK}"/><rect x="236" y="96" width="17" height="14" rx="7" fill="${G_LAV}"/></g>`),
};
const GUIDES={
  muestra:{title:'Cómo tomar la muestra',icon:'flask',steps:[
    {s:'manos',t:'Lávate las manos',d:'Usa las toallitas o el agua del módulo de higiene durante 20 segundos.'},
    {s:'colector',t:'Recolecta en el colector',d:'Ajusta el colector de microgravedad y llénalo hasta la marca media.'},
    {s:'sensor',t:'Coloca el vial en el sensor',d:'Inserta el vial hasta que la luz verde parpadee. No lo agites.'},
    {s:'registrar',t:'Regístrala en URANO',d:'Elige "Sensor automático" en Nueva muestra y sigue los cuatro pasos.'}]},
  tira:{title:'Cómo leer la tira reactiva',icon:'cam',steps:[
    {s:'sumergir',t:'Sumerge la tira 1 segundo',d:'Que todos los cuadros toquen la orina. Retira el exceso en el borde.'},
    {s:'esperar',t:'Espera 60 segundos',d:'Deja la tira en horizontal. Los colores cambian con el tiempo.'},
    {s:'comparar',t:'Compara los colores',d:'Alinea la tira con la tabla del frasco, cuadro por cuadro.'},
    {s:'foto',t:'Toma la foto',d:'Encuadra la tira con buena luz. URANO lee los colores por ti.'}]},
  refugio:{title:'Refugio ante tormenta solar',icon:'sun',mod:'radiacion',steps:[
    {s:'alerta',t:'Atiende la alerta',d:'Suspende lo que estés haciendo. Las partículas llegan en minutos.'},
    {s:'blindaje',t:'Ve a la zona blindada',d:'Muévete al módulo con más masa a tu alrededor, según el plan de la nave.'},
    {s:'provisiones',t:'Rodéate de agua y provisiones',d:'Las bolsas de agua y los alimentos frenan parte de la radiación.'},
    {s:'esperarfin',t:'Espera el aviso de fin',d:'No salgas hasta que el dosímetro vuelva a verde y control de misión lo confirme.'}]},
  dolor:{title:'Dolor lumbar intenso',icon:'kidney',mod:'renal',steps:[
    {s:'avisar',t:'Avisa a la oficial médica',d:'Un dolor fuerte en la espalda baja puede ser un cálculo renal. No esperes.'},
    {s:'dolor',t:'Registra el dolor',d:'Indica qué tan fuerte es del 0 al 10 y desde cuándo empezó.'},
    {s:'agua',t:'Bebe agua si no tienes náuseas',d:'Sorbos de 250 ml ayudan a diluir la orina mientras te evalúan.'},
    {s:'botiquin',t:'Sigue la indicación del botiquín',d:'Toma un medicamento solo si la oficial médica o el cirujano de vuelo lo indican.'}]},
};
const GUIDE_BY_MOD={renal:'dolor',radiacion:'refugio',inmunidad:'muestra',hidratacion:'tira'};
function openGuide(id){const g=GUIDES[id];if(!g)return;let i=0,playing=!matchMedia('(prefers-reduced-motion: reduce)').matches,timer=0;const DUR=5200;
  const sc=document.createElement('div');sc.className='scrim';
  sc.innerHTML=`<div class="modal gplayer" role="dialog" aria-label="Guía: ${g.title}"><div class="between"><span class="row small muted" style="gap:8px">${ic(g.icon,18)}Guía animada</span><button class="iconbtn" id="gx" style="width:44px;height:44px;border:0" aria-label="Cerrar">${ic('x')}</button></div>
    <h2 style="margin:4px 0 12px">${g.title}</h2><div class="gbars">${g.steps.map(()=>'<span class="gbar"><i></i></span>').join('')}</div>
    <div class="gscene" id="gscene"></div><div class="small muted" id="gstep" style="margin-top:12px"></div><h3 id="gt" style="font-size:20px;line-height:28px"></h3><p class="muted" id="gd" style="margin-top:4px;min-height:48px"></p>
    <div class="between" style="margin-top:14px"><button class="btn ghost m" id="gprev">${ic('left',18)}Anterior</button><button class="btn ghost m" id="gplay" aria-label="Pausar">${ic('pause',18)}</button><button class="btn primary m" id="gnext">Siguiente${ic('right',18)}</button></div>
    <p class="cap muted" style="margin-top:14px">Guía de demostración. Sigue siempre los protocolos de la misión y al cirujano de vuelo.</p></div>`;
  document.body.appendChild(sc);
  const show=()=>{const st=g.steps[i];clearTimeout(timer);
    const host=$('#gscene',sc);host.innerHTML='';
    if(st.lottie&&window.lottie){window.lottie.loadAnimation({container:host,renderer:'svg',loop:true,autoplay:true,path:st.lottie})}else host.innerHTML=SCENES[st.s];
    $('#gstep',sc).textContent=`Paso ${i+1} de ${g.steps.length}`;$('#gt',sc).textContent=st.t;$('#gd',sc).textContent=st.d;
    $$('.gbar',sc).forEach((b,k)=>{b.className='gbar'+(k<i?' done':k===i?' cur':'');const f=$('i',b);f.style.animation='none';void f.offsetWidth;f.style.animation='';f.style.animationPlayState=playing?'running':'paused'});
    $('#gprev',sc).disabled=i===0;$('#gnext',sc).innerHTML=i===g.steps.length-1?`${ic('check',18)}Listo`:`Siguiente${ic('right',18)}`;
    $('#gplay',sc).innerHTML=ic(playing?'pause':'play',18);$('#gplay',sc).setAttribute('aria-label',playing?'Pausar':'Reproducir');
    if(playing&&i<g.steps.length-1)timer=setTimeout(()=>{i++;show()},DUR);};
  const close=()=>{clearTimeout(timer);sc.remove();document.removeEventListener('keydown',key)};
  const key=e=>{if(e.key==='Escape')close();if(e.key==='ArrowRight'&&i<g.steps.length-1){i++;show()}if(e.key==='ArrowLeft'&&i>0){i--;show()}};
  document.addEventListener('keydown',key);
  $('#gx',sc).onclick=close;sc.onclick=e=>{if(e.target===sc)close()};
  $('#gprev',sc).onclick=()=>{if(i>0){i--;show()}};
  $('#gnext',sc).onclick=()=>{if(i<g.steps.length-1){i++;show()}else{close();toast('Guía completada','check')}};
  $('#gplay',sc).onclick=()=>{playing=!playing;show()};
  show();
}
document.addEventListener('click',e=>{const b=e.target.closest('.guide-open');if(b){e.preventDefault();e.stopPropagation();openGuide(b.dataset.g)}});
const guideCards=()=>`<div class="grid rg" style="grid-template-columns:repeat(4,minmax(0,1fr));gap:16px">${Object.entries(GUIDES).map(([k,g])=>`<button class="card hov guide-open gcard" data-g="${k}" aria-label="Abrir guía: ${g.title}">
  <div class="gthumb">${SCENES[g.steps[0].s]}</div><div class="row" style="gap:8px;margin-top:12px">${ic(g.icon,18,'color:var(--lav2)')}<b style="text-align:left">${g.title}</b></div><div class="small muted" style="text-align:left;margin-top:4px">${g.steps.length} pasos · 20 s</div></button>`).join('')}</div>`;

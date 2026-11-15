// =====================================================================
//  APOLO · la mascota (un perrito astronauta)
//  Todo es SVG + CSS: flota, parpadea, mueve las orejas, habla y cambia
//  de expresión según el estado de salud del tripulante.
// =====================================================================
const DOG_C={fur:'#FFF3E0',snout:'#FFFBF4',ear:'#E2A36B',ear2:'#C9844B',patch:'#EDBB88',ink:'#231E33',blush:'#FF9AA6',collar:'#8367C7',tag:'#F0FFF1'};

function dogSVG(){const c=DOG_C;
  return `<svg class="dog" viewBox="0 0 220 220" role="img" aria-label="Apolo, tu perrito asistente">
  <defs>
    <radialGradient id="dglass" cx="35%" cy="28%" r="80%"><stop offset="0" stop-color="#F0FFF1" stop-opacity=".16"/><stop offset=".55" stop-color="#A994E0" stop-opacity=".05"/><stop offset="1" stop-color="#A994E0" stop-opacity=".14"/></radialGradient>
    <radialGradient id="dfur" cx="45%" cy="35%" r="70%"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="${c.fur}"/></radialGradient>
  </defs>
  <circle class="helmet" cx="110" cy="110" r="100" fill="url(#dglass)" stroke="#F0FFF1" stroke-opacity=".28" stroke-width="2"/>
  <ellipse cx="110" cy="176" rx="36" ry="18" fill="#F4E2C6"/>
  <path d="M70 168q40 26 80 0l1 10q-41 26-82 0z" fill="${c.collar}"/>
  <g class="tag"><circle cx="110" cy="190" r="8" fill="${c.tag}"/><path d="M110 185.5l1.3 2.9 3.1.3-2.3 2.1.7 3.1-2.8-1.6-2.8 1.6.7-3.1-2.3-2.1 3.1-.3z" fill="${c.collar}"/></g>
  <g class="ear el"><path d="M68 64C40 62 24 96 27 130c2 26 18 40 33 33 12-6 11-30 15-50 4-21 12-47-7-49z" fill="${c.ear}"/><path d="M64 76c-14 4-22 28-21 50 1 13 6 22 13 22" fill="none" stroke="${c.ear2}" stroke-width="3" stroke-linecap="round" opacity=".5"/></g>
  <g class="ear er"><path d="M152 64c28-2 44 32 41 66-2 26-18 40-33 33-12-6-11-30-15-50-4-21-12-47 7-49z" fill="${c.ear}"/><path d="M156 76c14 4 22 28 21 50-1 13-6 22-13 22" fill="none" stroke="${c.ear2}" stroke-width="3" stroke-linecap="round" opacity=".5"/></g>
  <g class="head">
    <ellipse cx="110" cy="112" rx="63" ry="57" fill="url(#dfur)"/>
    <path d="M100 58q5-11 11-1q5-9 11 2" fill="none" stroke="${c.ear2}" stroke-width="3" stroke-linecap="round" opacity=".7"/>
    <ellipse cx="136" cy="100" rx="21" ry="18" fill="${c.patch}" opacity=".85"/>
    <path class="brow bl" d="M76 86q9-4 18-1" fill="none" stroke="${c.ink}" stroke-width="3" stroke-linecap="round"/>
    <path class="brow br" d="M126 85q9-3 18 1" fill="none" stroke="${c.ink}" stroke-width="3" stroke-linecap="round"/>
    <g class="eyes">
      <g class="eye"><ellipse cx="86" cy="104" rx="9.5" ry="11" fill="${c.ink}"/><g class="pupil"><circle cx="89" cy="100" r="3.4" fill="#fff"/><circle cx="83.5" cy="108" r="1.5" fill="#fff"/></g></g>
      <g class="eye"><ellipse cx="134" cy="104" rx="9.5" ry="11" fill="${c.ink}"/><g class="pupil"><circle cx="137" cy="100" r="3.4" fill="#fff"/><circle cx="131.5" cy="108" r="1.5" fill="#fff"/></g></g>
    </g>
    <ellipse cx="72" cy="126" rx="9" ry="5" fill="${c.blush}" opacity=".55"/>
    <ellipse cx="148" cy="126" rx="9" ry="5" fill="${c.blush}" opacity=".55"/>
    <ellipse cx="110" cy="130" rx="25" ry="18" fill="${c.snout}"/>
    <path d="M100 118q10-5 20 0q-1 9-10 11q-9-2-10-11z" fill="${c.ink}"/><ellipse cx="106" cy="119.5" rx="3" ry="1.6" fill="#fff" opacity=".6"/>
    <path class="mouth m-ok" d="M98 136q6 7 12 0q6 7 12 0" fill="none" stroke="${c.ink}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>
    <path class="mouth m-warn" d="M100 139q10 2 20 0" fill="none" stroke="${c.ink}" stroke-width="2.6" stroke-linecap="round"/>
    <ellipse class="mouth m-crit" cx="110" cy="139" rx="4.5" ry="5" fill="${c.ink}"/>
    <g class="mouth m-talk"><ellipse cx="110" cy="139" rx="8" ry="7" fill="#5B1F2E"/><ellipse cx="110" cy="143" rx="5" ry="3.4" fill="#FF7E8A"/></g>
    <path class="sweat" d="M163 76q5 8 0 12q-5-4 0-12z" fill="#9FD8FF"/>
  </g>
  <path d="M46 72a76 76 0 0 1 42-36" fill="none" stroke="#F0FFF1" stroke-opacity=".5" stroke-width="5" stroke-linecap="round"/>
  </svg>`}

const Dog={el:null,mood:'ok',talkT:null,
  mount(host){host.innerHTML=dogSVG();this.el=$('.dog',host);this.blinkLoop();
    window.addEventListener('pointermove',e=>this.look(e.clientX,e.clientY),{passive:true});},
  setMood(s){this.mood=s;if(!this.el)return;this.el.classList.remove('mood-ok','mood-warn','mood-crit');this.el.classList.add('mood-'+s);},
  talk(ms){if(!this.el)return;clearTimeout(this.talkT);this.el.classList.add('talk');this.talkT=setTimeout(()=>this.el.classList.remove('talk'),Math.max(400,ms));},
  stop(){clearTimeout(this.talkT);this.el?.classList.remove('talk')},
  blinkLoop(){const go=()=>{if(this.el){this.el.classList.add('blink');setTimeout(()=>this.el?.classList.remove('blink'),160)}setTimeout(go,2600+Math.random()*3400)};setTimeout(go,1800)},
  look(x,y){if(!this.el||matchMedia('(prefers-reduced-motion: reduce)').matches)return;const r=this.el.getBoundingClientRect();
    const dx=x-(r.left+r.width/2),dy=y-(r.top+r.height*.47),d=Math.hypot(dx,dy)||1,k=Math.min(1,d/300)*3;
    $$('.pupil',this.el).forEach(p=>p.style.transform=`translate(${dx/d*k}px,${dy/d*k}px)`)},
  perk(on){this.el?.classList.toggle('listen',on)},
  wiggle(){if(!this.el)return;this.el.classList.remove('wig');void this.el.getBoundingClientRect();this.el.classList.add('wig')},
};

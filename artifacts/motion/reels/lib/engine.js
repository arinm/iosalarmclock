/* Punctual motion engine — shared by every reel.
   Everything is a pure function of t (seconds): frames can be rendered in any order,
   in parallel, and sampled several times per frame for real motion blur. */
const $=id=>document.getElementById(id);
const NS='http://www.w3.org/2000/svg';
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
const seg=(t,a,b)=>clamp((t-a)/(b-a));
const lerp=(a,b,p)=>a+(b-a)*p;
const E={
  outExpo:p=>p>=1?1:1-Math.pow(2,-10*p),
  inExpo:p=>p<=0?0:Math.pow(2,10*p-10),
  inOutExpo:p=>p<=0?0:p>=1?1:p<.5?Math.pow(2,20*p-10)/2:(2-Math.pow(2,-20*p+10))/2,
  outCubic:p=>1-Math.pow(1-p,3),
  inCubic:p=>p*p*p,
  inOutCubic:p=>p<.5?4*p*p*p:1-Math.pow(-2*p+2,3)/2,
  inOutQuint:p=>p<.5?16*Math.pow(p,5):1-Math.pow(-2*p+2,5)/2,
  outBack:(p,s=1.70158)=>p<=0?0:1+(s+1)*Math.pow(p-1,3)+s*Math.pow(p-1,2),
  smooth:p=>p*p*(3-2*p)
};
const spring=(dt,damp=8,freq=1.8)=>dt<=0?0:1-Math.exp(-damp*dt)*Math.cos(2*Math.PI*freq*dt);
const pulse=(t,a,b)=>Math.sin(Math.PI*seg(t,a,b));
const mix=(a,b,p)=>a.map((v,i)=>v+(b[i]-v)*p);
const rgba=(c,a=(c[3]??1))=>`rgba(${c[0]|0},${c[1]|0},${c[2]|0},${(+a).toFixed(3)})`;
const COL={peach:[255,168,133],peachRaw:[245,140,107],sage:[143,199,160],amber:[226,178,62],txt:[244,244,247],muted:[166,166,176],ink:[31,14,6],card:[28,28,36],off:[58,58,66]};
function keyed(K,t){for(let i=0;i<K.length-1;i++){const a=K[i],b=K[i+1];if(t<=b[0]){const p=E.smooth(seg(t,a[0],b[0]));return a.slice(1).map((v,j)=>lerp(v,b[j+1],p));}}return K[K.length-1].slice(1);}
function sv(tag,attrs,parent){const e=document.createElementNS(NS,tag);for(const k in attrs)e.setAttribute(k,attrs[k]);if(parent)parent.appendChild(e);return e;}
function el(tag,cls,html,parent){const e=document.createElement(tag);if(cls)e.className=cls;if(html!=null)e.innerHTML=html;if(parent)parent.appendChild(e);return e;}
function show(e,on){(typeof e==='string'?$(e):e).style.visibility=on?'visible':'hidden';return on;}
function tf(e,s){e.style.transform=s;}
function op(e,v){e.style.opacity=(+v).toFixed(3);}

const ICON={
  skip:'<svg width="30" height="26" viewBox="0 0 30 26"><path d="M2 2 20 13 2 24Z" fill="currentColor"/><rect x="22" y="2" width="5" height="22" rx="1.6" fill="currentColor"/></svg>',
  check:'<svg width="58" height="58" viewBox="0 0 58 58"><circle cx="29" cy="29" r="27" fill="rgba(143,199,160,.22)"/><path class="chkP" d="M17 30l8 8 16-17" fill="none" stroke="#8FC7A0" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round" pathLength="100" stroke-dasharray="100 200" stroke-dashoffset="100"/></svg>',
  clock:(s=58,c='#A6A6B0',w=2)=>`<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" style="display:block"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.6 2"/><path d="M5 4.5 3 6.5M19 4.5l2 2"/></svg>`,
  tick:(s=28)=>`<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>`,
  pause:(s=30)=>`<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="5" width="4.2" height="14" rx="1.4"/><rect x="13.8" y="5" width="4.2" height="14" rx="1.4"/></svg>`,
  moon:(s=30)=>`<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor"><path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z"/></svg>`
};

/* ---------- the mark: "the missing hour" ---------- */
function buildMark(svg,{inset=1,color='#FFA885'}={}){
  const root=sv('g',{transform:inset===1?'':`translate(512 512) scale(${inset}) translate(-512 -512)`},svg);
  const g=sv('g',{},root), st=sv('g',{fill:'none',stroke:color,'stroke-linecap':'round'},g);
  const arcs=(p,inner)=>{ if(inner){sv('path',{d:'M203 458 A 320 320 0 0 0 203 654','stroke-width':36},p);sv('path',{d:'M821 458 A 320 320 0 0 1 821 654','stroke-width':36},p);}
    else{sv('path',{d:'M132 500 A 386 386 0 0 0 132 612','stroke-width':30},p);sv('path',{d:'M892 500 A 386 386 0 0 1 892 612','stroke-width':30},p);} };
  const echoes=[0,1].map(()=>{const e=sv('g',{opacity:0},st);arcs(e,false);return e;});
  const w2=sv('g',{opacity:0},st);arcs(w2,false);
  const w1=sv('g',{opacity:0},st);arcs(w1,true);
  const bL=sv('path',{d:'M340 384 A 100 100 0 0 1 266 286','stroke-width':54,opacity:0},st);
  const bR=sv('path',{d:'M684 384 A 100 100 0 0 0 758 286','stroke-width':54,opacity:0},st);
  const ring=sv('circle',{cx:512,cy:556,r:244,'stroke-width':54,pathLength:100,transform:'rotate(-19 512 556)','stroke-dasharray':'0 200',opacity:0},st);
  const hM=sv('line',{x1:512,y1:556,x2:512,y2:556,'stroke-width':44,opacity:0},st);
  const hH=sv('line',{x1:512,y1:556,x2:512,y2:556,'stroke-width':44,opacity:0},st);
  const dot=sv('circle',{cx:512,cy:556,r:0,fill:color},g);
  return {g,echoes,w1,w2,bL,bR,ring,hM,hH,dot};
}
function drawMark(M,lt,{ringFreq=13}={}){
  const o={};
  M.dot.setAttribute('r',(34*Math.max(0,spring(lt-0.04,9,2.0))).toFixed(2));
  const pr=E.inOutQuint(seg(lt,0.30,1.10)); o.pr=pr;
  M.ring.setAttribute('stroke-dasharray',`${(93*pr).toFixed(3)} 200`); M.ring.setAttribute('opacity',pr>0.003?1:0);
  const th=(-19+360*0.93*pr)*Math.PI/180; o.tip=[512+244*Math.cos(th),556+244*Math.sin(th)];
  const hm=clamp(spring(lt-0.56,7.5,1.9),0,1.2), hh=clamp(spring(lt-0.68,7.5,1.9),0,1.2);
  M.hM.setAttribute('y2',(556-164*hm).toFixed(2)); M.hM.setAttribute('opacity',hm>0.01?1:0);
  M.hH.setAttribute('x2',(512+102*hh).toFixed(2)); M.hH.setAttribute('y2',(556-62*hh).toFixed(2)); M.hH.setAttribute('opacity',hh>0.01?1:0);
  const env=seg(lt,1.12,1.20)*(1-E.inOutCubic(seg(lt,1.40,1.95))); o.env=env;
  const ph=Math.sin(2*Math.PI*ringFreq*lt);
  [[M.bL,0.86,303,335,1],[M.bR,0.93,721,335,-1]].forEach(([b,s,ax,ay,dir])=>{
    const p=seg(lt,s,s+0.45), e=E.outBack(p,2.4);
    b.setAttribute('opacity',clamp(p*5).toFixed(3));
    b.setAttribute('transform',`translate(0 ${((1-e)*70).toFixed(2)}) rotate(${(dir*10*ph*env).toFixed(2)} ${ax} ${ay+50}) translate(${ax} ${ay}) scale(${(0.35+0.65*e).toFixed(4)}) translate(${-ax} ${-ay})`);
  });
  const p1=E.outCubic(seg(lt,1.12,1.45)), p2=E.outCubic(seg(lt,1.22,1.55)), flick=0.82+0.18*Math.sin(2*Math.PI*6.5*lt)*env;
  M.w1.setAttribute('opacity',(p1*flick).toFixed(3)); M.w1.setAttribute('transform',`translate(512 556) scale(${(0.78+0.22*p1).toFixed(4)}) translate(-512 -556)`);
  M.w2.setAttribute('opacity',(0.72*p2*flick).toFixed(3)); M.w2.setAttribute('transform',`translate(512 556) scale(${(0.78+0.22*p2).toFixed(4)}) translate(-512 -556)`);
  [1.30,1.56].forEach((s,i)=>{const p=seg(lt,s,s+0.65),e=E.outCubic(p);
    M.echoes[i].setAttribute('opacity',(p>0&&p<1?0.6*(1-p):0).toFixed(3));
    M.echoes[i].setAttribute('transform',`translate(512 556) scale(${(1+0.55*e).toFixed(4)}) translate(-512 -556)`);});
  M.g.setAttribute('transform',`rotate(${(3.2*ph*env).toFixed(3)} 512 556)`);
  return o;
}
/* re-ring a finished mark (alarm going off again) */
function ringMark(M,t,t0,dur=0.9){
  const lt=t-t0, env=seg(lt,0,0.08)*(1-E.inOutCubic(seg(lt,dur*0.45,dur))), ph=Math.sin(2*Math.PI*13*lt);
  M.g.setAttribute('transform',`rotate(${(3.4*ph*env).toFixed(3)} 512 556)`);
  [[M.bL,303,335,1],[M.bR,721,335,-1]].forEach(([b,ax,ay,dir])=>b.setAttribute('transform',`rotate(${(dir*11*ph*env).toFixed(2)} ${ax} ${ay+50})`));
  [0,1].forEach(i=>{const p=seg(lt,0.08+i*0.24,0.08+i*0.24+0.6),e=E.outCubic(p);
    M.echoes[i].setAttribute('opacity',(p>0&&p<1?0.65*(1-p):0).toFixed(3));
    M.echoes[i].setAttribute('transform',`translate(512 556) scale(${(1+0.6*e).toFixed(4)}) translate(-512 -556)`);});
  return env;
}

/* ---------- masked words ---------- */
function setWords(line,parts){ line.innerHTML=''; return parts.map(p=>{const m=el('span','m',null,line);return el('span','w',p,m);}); }
function wordsIn(ws,t,st,{stg=.07,dur=.62,dist=125,skew=7}={}){
  ws.forEach((w,i)=>{const e=E.outExpo(seg(t,st+i*stg,st+i*stg+dur));op(w,t>st+i*stg?1:0);tf(w,`translateY(${(dist*(1-e)).toFixed(2)}%) skewY(${(skew*(1-e)).toFixed(2)}deg)`);});
}
function wordsInOut(ws,t,st,out,{stg=.07,dur=.62,ostg=.035,odur=.36,dist=125}={}){
  ws.forEach((w,i)=>{const e=E.outExpo(seg(t,st+i*stg,st+i*stg+dur)), x=E.inExpo(seg(t,out+i*ostg,out+i*ostg+odur));
    op(w,(t>st+i*stg&&x<0.999)?1:0);   // hidden before its cue and after its exit: no glyph tips peeking under the mask
    tf(w,`translateY(${(dist*(1-e)-dist*x).toFixed(2)}%) skewY(${(7*(1-e)-6*x).toFixed(2)}deg)`);});
}

/* ---------- drifting dust ---------- */
function Dust(canvas,n=110,seed=1234567){
  const W=canvas.width,H=canvas.height; let s=seed; const r=()=>((s=(s*16807)%2147483647)/2147483647);
  const P=[...Array(n)].map(()=>({x:r()*W,y:r()*H,vx:(r()-.5)*14,vy:-4-r()*12,r:.7+r()*2.4,a:.05+r()*.22,ph:r()*6.28,z:.4+r()*1.2}));
  const ctx=canvas.getContext('2d');
  return {draw(t,{warp=0,cx=W/2,cy=H/2,dx=0,dy=0,boost=0,color=[255,214,196]}={}){ctx.clearRect(0,0,W,H);
    for(const p of P){let px=((p.x+p.vx*t*p.z)%W+W)%W, py=((p.y+p.vy*t*p.z)%H+H)%H;
      px=cx+(px-cx)*(1+warp*p.z)+dx*p.z; py=cy+(py-cy)*(1+warp*p.z)+dy*p.z;
      const a=p.a*(0.6+0.4*Math.sin(p.ph+t*1.7))*(1+boost);
      ctx.fillStyle=`rgba(${color[0]},${color[1]},${color[2]},${a.toFixed(3)})`; ctx.beginPath(); ctx.arc(px,py,p.r*p.z,0,6.2832); ctx.fill();}}};
}

/* ---------- environment layers ---------- */
const ENV={};
function buildEnv(){
  const st=$('stage'), W=CLIP.w, H=CLIP.h;
  st.insertAdjacentHTML('afterbegin',`<div id="bg" class="layer"></div><div id="glow"></div><div id="tint" class="layer"></div><div id="sun"></div><canvas id="dust" class="layer" width="${W}" height="${H}"></canvas>`);
  st.insertAdjacentHTML('beforeend',`<div id="flash" class="layer"></div><div id="streak1" class="streak"></div><div id="streak2" class="streak"></div><div id="vignette" class="layer"></div>`);
  ENV.dust=Dust($('dust'));
}
const envGlow=(x,y,o,s=1)=>{op($('glow'),o);tf($('glow'),`translate(${(x-800).toFixed(2)}px,${(y-800).toFixed(2)}px) scale(${s.toFixed(4)})`);};
const envSun=(x,y,o)=>{op($('sun'),o);tf($('sun'),`translate(${(x-850).toFixed(2)}px,${(y-850).toFixed(2)}px)`);};
const envTint=o=>op($('tint'),o);
const envFlash=o=>op($('flash'),o);
function envStreak(id,y,t,a,b,peak=.9){const p=seg(t,a,b);$(id).style.top=y+'px';op($(id),peak*Math.sin(Math.PI*p));tf($(id),`scaleX(${(0.2+1.1*E.outCubic(p)).toFixed(4)})`);}

/* ---------- heads-up notification (morphs into the skip pill) ---------- */
function buildNotif(parent,{title='Alarm in 15 minutes',body='Wake up · 6:30 AM',width=860}={}){
  const card=el('div','ncard',null,parent);
  card.innerHTML=`<div class="nA" style="width:${width}px"><div class="nhead"><div class="nicon"><svg viewBox="0 0 1024 1024" width="42" height="42" style="overflow:visible"></svg></div><span>PUNCTUAL</span><span class="ntime">now</span></div><div class="ntitle">${title}</div><div class="nbody">${body}</div><div class="nbtns"><div class="nbtn skip">${ICON.skip}Skip today</div><div class="nbtn open">Open</div></div></div><div class="nB">${ICON.check}<span>Skipped today <em>- still active</em></span></div>`;
  const icon=card.querySelector('.nicon svg'); drawMark(buildMark(icon,{inset:.74}),99);
  card.style.width=width+'px';
  const N={card,A:card.querySelector('.nA'),B:card.querySelector('.nB'),skip:card.querySelector('.nbtn.skip'),chk:card.querySelector('.chkP'),icon,width};
  N.h=N.A.getBoundingClientRect().height; card.style.height=N.h+'px';
  return N;
}
/* place + morph. g = {cx, cy (resting centre), drop (0..1+ spring), rot, morph 0..1, pill:{w,h,cy}} */
function drawNotif(N,t,{cx,cy,drop,rot=0,morph=0,pill={w:740,h:108,cy:cy},tB=0,tChk=0,fade=1}){
  const W=lerp(N.width,pill.w,morph), H=lerp(N.h,pill.h,morph), R=lerp(34,54,morph);
  const y=lerp(cy,pill.cy,morph)-(1-drop)*(cy+N.h);
  const c=N.card; c.style.left=(cx-W/2).toFixed(2)+'px'; c.style.top=(y-H/2).toFixed(2)+'px';
  c.style.width=W.toFixed(2)+'px'; c.style.height=H.toFixed(2)+'px'; c.style.borderRadius=R.toFixed(2)+'px';
  op(c,fade); tf(c,`rotate(${rot.toFixed(3)}deg)`);
  c.style.background=rgba(mix([28,28,36,.9],[36,62,46,.72],morph));
  c.style.borderColor=rgba(mix([255,255,255,.10],[143,199,160,.5],morph));
  c.style.boxShadow=`0 34px 100px rgba(0,0,0,.6), 0 0 ${(70*morph).toFixed(1)}px rgba(143,199,160,${(0.22*morph).toFixed(3)})`;
  const fa=clamp(morph*4); op(N.A,1-fa); tf(N.A,`scale(${(1-0.05*fa).toFixed(4)})`);
  op(N.B,tB); N.chk.setAttribute('stroke-dashoffset',(100*(1-E.outCubic(tChk))).toFixed(2));
}
/* the button's centre in stage space, for the finger */
function skipCentre(N,cx,cy){const r=N.skip.getBoundingClientRect(),c=N.card.getBoundingClientRect();return [cx-N.width/2+(r.left-c.left)+r.width/2, cy-N.h/2+(r.top-c.top)+r.height/2];}

/* ---------- finger tap ---------- */
function tapFX(touch,ripple,t,{x,y,t0,from=[150,190],maxR=360}){
  const tin=E.outCubic(seg(t,t0,t0+.26)), press=pulse(t,t0+.28,t0+.46);
  op(touch,0.92*seg(t,t0,t0+.1)*(1-seg(t,t0+.48,t0+.66)));
  tf(touch,`translate(${lerp(x+from[0],x,tin).toFixed(2)}px,${lerp(y+from[1],y,tin).toFixed(2)}px) scale(${(lerp(1.3,1,tin)*(1-0.2*press)).toFixed(4)})`);
  const rp=seg(t,t0+.32,t0+.96), rr=24+maxR*E.outCubic(rp);
  op(ripple,rp>0&&rp<1?0.75*(1-rp):0); ripple.style.width=ripple.style.height=(2*rr).toFixed(2)+'px';
  tf(ripple,`translate(${(x-rr).toFixed(2)}px,${(y-rr).toFixed(2)}px)`);
  return press;
}

/* ---------- week strip ---------- */
function buildWeek(parent,{top,size=96,gap=22,on=[1,2,3,4,5],font=36}={}){
  const wk=el('div','week',null,parent); wk.style.top=top+'px'; wk.style.gap=gap+'px';
  return 'SMTWTFS'.split('').map((L,i)=>{const d=el('div','day '+(on.includes(i)?'on':'off'),`<span>${L}</span><svg viewBox="0 0 104 104"><line x1="28" y1="78" x2="76" y2="26" stroke="#8FC7A0" stroke-width="7" stroke-linecap="round" pathLength="100" stroke-dasharray="100 200" stroke-dashoffset="100"/></svg><i class="ring2"></i><i class="ring2"></i>`,wk);
    d.style.width=d.style.height=size+'px'; d.style.fontSize=font+'px'; return d;});
}
function dayPop(d,t,st,extra=1){const p=clamp(spring(t-st,8,1.8),0,1.3);op(d,clamp((t-st)/0.1));tf(d,`scale(${((0.3+0.7*p)*extra).toFixed(4)})`);}
function daySkip(d,p){const on=d.classList.contains('on');
  d.style.background=rgba(mix(on?[245,140,107,.22]:[255,255,255,.04],[143,199,160,.10],p)); d.style.color=rgba(mix(on?[255,168,133,1]:[94,94,104,1],[143,199,160,1],p));
  d.style.boxShadow=`inset 0 0 0 ${(3*p).toFixed(2)}px rgba(143,199,160,${(0.7*p).toFixed(3)})`;
  d.querySelector('line').setAttribute('stroke-dashoffset',(100*(1-p)).toFixed(2));}
function dayArm(d,p,t,r0){
  d.style.background=rgba(mix([245,140,107,.22],[255,168,133,1],p)); d.style.color=rgba(mix([255,168,133,1],[31,14,6,1],p));
  d.style.boxShadow=`0 0 ${(70*p).toFixed(1)}px rgba(255,150,110,${(0.65*p).toFixed(3)})`;
  d.querySelectorAll('.ring2').forEach((rg,i)=>{const q=seg(t,r0+i*.26,r0+.65+i*.26);op(rg,q>0&&q<1?0.85*(1-q):0);tf(rg,`scale(${(1+0.95*E.outCubic(q)).toFixed(4)})`);});
}
function centreOf(e){const r=e.getBoundingClientRect();return [r.left+r.width/2,r.top+r.height/2];}

/* ---------- phone with the real home screen ---------- */
const CLOCK_S=(s=15)=>`<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.6 2"/></svg>`;
const PHONE_HOME=`<div class="sb"><span>6:33</span><span class="sbr"><svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="#fff"/><rect x="5" y="5" width="3" height="7" rx="1" fill="#fff"/><rect x="10" y="2" width="3" height="10" rx="1" fill="#fff"/><rect x="15" y="0" width="3" height="12" rx="1" fill="#fff"/></svg><svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" stroke="#fff" opacity=".5"/><rect x="2" y="2" width="18" height="9" rx="2" fill="#fff"/><rect x="25" y="4" width="2" height="5" rx="1" fill="#fff" opacity=".5"/></svg></span></div>
<div class="gear pc"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/></svg></div>
<div class="ptitle pc">Alarms</div>
<div class="hero pc"><div class="hl">NEXT ALARM</div><div class="ht">7:15 AM</div><div class="hr">${CLOCK_S()}Rings in <b>42m</b></div><div class="hring"><svg class="heroMark" viewBox="0 0 1024 1024" width="44" height="44" style="overflow:visible"></svg></div></div>
<div class="acard pc"><div class="at">6:30 AM</div><div class="al">Wake up</div><div class="tog on"><i></i></div><div class="dd"><span>S</span><span class="a">M</span><span class="a">T</span><span class="a">W</span><span class="a">T</span><span class="a">F</span><span>S</span></div><div><span class="skipc">${ICON.tick(15)}Skipped today - still active</span></div></div>
<div class="acard pc"><div class="at">7:15 AM</div><div class="al">Gym</div><div class="tog on"><i></i></div><div class="dd"><span>S</span><span class="a">M</span><span>T</span><span class="a">W</span><span>T</span><span class="a">F</span><span>S</span></div><div class="chip">${CLOCK_S(14)}Rings in <b>42m</b></div></div>
<div class="acard pc"><div class="at">8:00 AM</div><div class="al">Meds</div><div class="tog tog3"><i></i></div><div class="dd"><span class="a">S</span><span class="a">M</span><span class="a">T</span><span class="a">W</span><span class="a">T</span><span class="a">F</span><span class="a">S</span></div></div>`;
function buildPhone(parent,{x,y,html=PHONE_HOME}){
  const wrap=el('div','phwrap',null,parent); wrap.style.left=x+'px'; wrap.style.top=y+'px';
  const ph=el('div','phone','<div class="island"></div><div class="scr">'+html+'</div><div class="fab pc">+</div>',wrap);
  ph.querySelectorAll('.heroMark').forEach(s=>drawMark(buildMark(s,{inset:.74}),99));
  return {wrap,ph,pcs:[...ph.querySelectorAll('.pc')]};
}

/* ---------- vertical end card ---------- */
function buildLockup(parent,{tag='Skip <span class="s">today.</span> Keep <span class="a">tomorrow.</span>',store='ON THE APP STORE · FOR IPHONE',cy=740}={}){
  const root=el('div','layer',null,parent);
  const glow=el('div','lglow',null,root), tile=el('div','tile','<svg viewBox="0 0 1024 1024"></svg>',root);
  const M=buildMark(tile.querySelector('svg'),{inset:.74});
  const name=el('div','wmName','<span class="m"><span class="w">Punctual</span></span>',root);
  const sub=el('div','wmSub','Smart Alarm Clock',root), tg=el('div','ltag',tag,root), sto=el('div','lstore',store,root);
  name.style.top=(cy+196)+'px'; sub.style.top=(cy+400)+'px'; tg.style.top=(cy+540)+'px'; sto.style.top=(cy+636)+'px';
  return {root,glow,tile,M,nameW:name.querySelector('.w'),sub,tg,sto,cy};
}
function renderLockup(L,t,t0,speed=1,{markReady=false}={}){
  const T=t; t=t0+(t-t0)*speed;   // speed>1 compresses the whole end card (reels)
  const cx=CLIP.w/2, cy=L.cy;
  // markReady: the mark was already on screen (a scene shrank it into the tile) — no rebuild
  const ts=markReady?1:clamp(spring(t-t0,7,1.5),0,1.2);
  tf(L.tile,`translate(${cx-150}px,${cy-150}px) scale(${(0.62+0.38*ts).toFixed(4)})`);
  if(markReady) op(L.tile,seg(T,t0,t0+0.22));
  const r=markReady?(drawMark(L.M,99),{pr:1,env:0}):drawMark(L.M,(t-t0-0.06)*1.55);
  op(L.glow,0.75+0.25*r.env); tf(L.glow,`translate(${cx-600}px,${cy-600}px) scale(${(1+0.04*Math.sin(2*Math.PI*0.8*T)).toFixed(4)})`);
  const n=E.outExpo(seg(t,t0+1.0,t0+1.6)); tf(L.nameW,`translateY(${(112*(1-n)).toFixed(2)}%)`);
  L.nameW.style.backgroundPosition=`${lerp(130,-30,E.inOutCubic(seg(t,t0+1.95,t0+2.65))).toFixed(2)}% 0`;
  [[L.sub,1.3],[L.tg,1.62],[L.sto,1.86]].forEach(([e,d])=>{const p=E.outExpo(seg(t,t0+d,t0+d+0.5));op(e,p);tf(e,`translateY(${(20*(1-p)).toFixed(2)}px)`);});
  return r;
}

/* ---------- boot ---------- */
function boot(scene){
  window.__ready=(async()=>{
    await document.fonts.ready;
    const W=CLIP.w,H=CLIP.h;
    for(const e of [document.documentElement,document.body,$('stage')]){e.style.width=W+'px';e.style.height=H+'px';}
    buildEnv(); scene.init();
    window.render=t=>scene.render(t);
    window.render(0); return true;
  })();
}

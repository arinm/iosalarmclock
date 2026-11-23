/* 07 "Are you up?" — a lock-screen hook (Stop, back to sleep, the quiet check,
   the ring once more), then the real app filmed in the simulator, then the end card.
   The capture is pre-cut into frames/<take>-<lang>/NNNN.jpg at 60 fps, aligned so
   the switch flips at 6.65 s and the card leaves at 8.75 s (see README in capture/). */
const JA=window.LANG==='ja'; if(JA) document.documentElement.classList.add('ja');
const S=JA?{
  date:'11月20日(金)', a1t:'起床', a1s:'6:30', a2t:'起きましたか？', a2s:'6:37', snooze:'スヌーズ', stop:'停止',
  now:'今', nTitle:'起きましたか？', nBody:'「起きました」をタップしないと、6:37にもう一度鳴ります。', nBtn:'起きました',
  tag:'「停止」のあとも、<span class="a">ちゃんと確認。</span>', sub:'目覚まし時計・アラーム', store:'App Store で配信中 · iPhone 用',
  tog:[832,1205], btn:[785,933]
}:{
  date:'Friday, November 20', a1t:'Wake up', a1s:'6:30 AM', a2t:'Are you up?', a2s:'6:37 AM', snooze:'Snooze', stop:'Stop',
  now:'now', nTitle:'Are you up?', nBody:"Tap I'm up, or the alarm rings again at 6:37 AM.", nBtn:"I'm up",
  tag:'Tapped Stop? <span class="a">We’ll check.</span>', sub:'Smart Alarm Clock', store:'ON THE APP STORE · FOR IPHONE',
  tog:[832,1241], btn:[818,933]
};
const TXT=JA?{
  tx1:[['<span class="a">「停止」</span>を'],['タップして…']], tx2:[['…また','寝ちゃった？']],
  tx3:[['5分後、'],['<span class="s">静かに確認。</span>']], tx4:[['返事がなければ、'],['<span class="a">もう一度</span>','鳴ります。']],
  tx5:[['起きたら、'],['<span class="s">タップひとつ。</span>']]
}:{
  tx1:[['Tapped','<span class="a">Stop…</span>']], tx2:[['…and','fell','back'],['asleep?']],
  tx3:[['5','minutes','later,'],['a','<span class="s">quiet</span>','<span class="s">check.</span>']],
  tx4:[['No','answer?'],['It','rings','<span class="a">once</span>','<span class="a">more.</span>']],
  tx5:[['Up?','One','tap,'],['and','it','stays','<span class="s">quiet.</span>']]
};
const WIN={tx1:[-0.25,1.30],tx2:[1.48,2.80],tx3:[3.00,4.74],tx4:[4.94,5.88],tx5:[6.12,9.24]};
const A0=5.90, B0=7.20, NA=108, NB=156;   // frames/a-*: reel 5.90.., frames/b-*: reel 7.20..
let Wd={},G={},A1,A2,L,STARS=[],cur={};

function buildAlert(title,sub,snooze=true){   // the re-ring has no Snooze (scheduleTransient)
  const a=el('div','alert',`<div class="aTop"><div class="aIcon"><svg viewBox="0 0 1024 1024"></svg></div><div><div class="aTitle">${title}</div><div class="aSub">${sub}</div></div></div><div class="aBtns">${snooze?`<div class="aBtn sn">${S.snooze}</div>`:''}<div class="aBtn st">${S.stop}</div></div>`,$('world'));
  $('world').insertBefore(a,$('qn'));
  const M=buildMark(a.querySelector('svg'),{inset:.74}); drawMark(M,99);
  return {a,M,st:a.querySelector('.st'),h:a.offsetHeight};
}
function init(){
  for(const id in TXT){$(id).innerHTML=TXT[id].map(()=>'<div class="line"></div>').join('');const lines=$(id).querySelectorAll('.line');Wd[id]=TXT[id].flatMap((ws,i)=>setWords(lines[i],ws));G[id+'h']=$(id).offsetHeight;}
  $('stage').insertBefore($('night'),$('dust'));
  $('lkDate').textContent=S.date;
  $('lkTime').innerHTML='6:3<span class="roll"><span id="digits">'+[0,1,2,3,4,5,6,7,8,9].map(d=>`<i>${d}</i>`).join('')+'</span></span>';
  A1=buildAlert(S.a1t,S.a1s); A2=buildAlert(S.a2t,S.a2s,false);
  G.acy=1012; tf(A1.a,`translate(100px,${G.acy-A1.h/2}px)`); G.stop=centreOf(A1.st);
  $('qn').innerHTML=`<div class="nhead"><div class="nicon"><svg viewBox="0 0 1024 1024" width="42" height="42"></svg></div><span>PUNCTUAL</span><span class="ntime">${S.now}</span></div><div class="ntitle">${S.nTitle}</div><div class="nbody">${S.nBody}</div><div class="nbtns"><div class="nbtn up">${S.nBtn}</div></div>`;
  drawMark(buildMark($('qn').querySelector('svg'),{inset:.74}),99);
  G.qh=$('qn').offsetHeight; G.qcy=1000;
  $('pro').innerHTML='<svg width="26" height="26" viewBox="0 0 24 24" fill="#E2B23E"><path d="M12 2.5l2.6 6.1 6.6.6-5 4.4 1.5 6.5L12 16.7 6.3 20.1l1.5-6.5-5-4.4 6.6-.6z"/></svg>PUNCTUAL PRO';
  G.pro=[$('pro').offsetWidth,$('pro').offsetHeight];
  L=buildLockup($('end'),{cy:740,tag:S.tag}); L.sub.textContent=S.sub; L.sto.textContent=S.store;
  let s=987654; const r=()=>((s=(s*16807)%2147483647)/2147483647);
  for(let i=0;i<150;i++) STARS.push({x:r()*1080,y:r()*1250,r:.5+r()*1.8,a:.25+r()*.6,f:.4+r()*1.6,ph:r()*6.28});
}
function drawSky(t,dim){
  const c=$('dust'), x=c.getContext('2d'); x.clearRect(0,0,1080,1920);
  for(const p of STARS){const a=p.a*(0.55+0.45*Math.sin(p.ph+t*p.f*2.4))*dim; x.fillStyle=`rgba(235,240,255,${a.toFixed(3)})`; x.beginPath(); x.arc(p.x,p.y,p.r,0,6.2832); x.fill();}
}
/* an alarm going off: the mark re-rings every 0.42 s while on */
function ringing(M,t,a,b){ if(t<a||t>b) return ringMark(M,t,-9); const k=Math.floor((t-a)/0.42); return ringMark(M,t,a+k*0.42,0.9); }
function setFrame(id,dir,i){
  const src=`frames/${dir}-${JA?'ja':'en'}/${String(i).padStart(4,'0')}.jpg`;
  if(cur[id]===src) return null; cur[id]=src; const img=$(id); img.src=src; return img.decode().catch(()=>{});
}
function render(t){
  for(const id in WIN){const [a,b]=WIN[id],on=t>a-0.05&&t<b+0.5;show(id,on);if(!on)continue;
    wordsInOut(Wd[id],t,a,b,{odur:0.26});
    tf($(id),`translateY(${(322-G[id+'h']/2).toFixed(2)}px)`);}
  // night until the phone takes over
  const night=1-E.inOutCubic(seg(t,5.85,6.25)); op($('night'),night); drawSky(t,night);
  const my=118+6*Math.sin(2*Math.PI*0.2*t);
  tf($('moon'),`translate(948px,${my.toFixed(2)}px) scale(.7)`); op($('moon'),0.85*night);
  tf($('moonGlow'),`translate(948px,${my.toFixed(2)}px)`); op($('moonGlow'),0.7*night);
  // lock screen: bright while ringing, dim asleep, lit by the quiet notice
  const [lk]=keyed([[0,1],[1.3,1],[1.9,.38],[3.0,.38],[3.3,.72],[5.2,.72],[5.35,1],[5.85,1],[6.12,0]],t);
  show('lock',t<6.2); op($('lock'),lk); tf($('lock'),`scale(${(1.04-0.04*E.outExpo(seg(t,0,0.5))+0.03*E.inOutCubic(seg(t,5.85,6.15))).toFixed(4)})`);
  const [d]=keyed([[0,0],[1.95,0],[2.6,5],[4.95,5],[5.2,7]],t); tf($('digits'),`translateY(${(-d).toFixed(4)}em)`);
  // 6:30 — Wake up rings, the finger taps Stop
  const in1=E.outExpo(seg(t,-0.2,0.3)), x1=E.inOutCubic(seg(t,1.02,1.32));
  show(A1.a,t<1.4); op(A1.a,in1*(1-x1)); tf(A1.a,`translate(100px,${(G.acy-A1.h/2+60*(1-in1)+30*x1).toFixed(2)}px) scale(${(0.96+0.04*in1-0.08*x1).toFixed(4)})`);
  const e1=ringing(A1.M,t,0.15,0.97);
  tf(A1.st,`scale(${(1-0.08*pulse(t,0.86,1.04)).toFixed(4)})`);
  tapFX($('touch0'),$('ripple0'),t,{x:G.stop[0],y:G.stop[1],t0:0.58,from:[150,200],maxR:200});
  // z z z
  ['z0','z1','z2'].forEach((id,i)=>{const st=1.75+i*0.33,p=seg(t,st,st+1.3);
    op($(id),p>0&&p<1?Math.sin(Math.PI*p)*0.9:0);
    tf($(id),`translate(${(780+i*55+24*Math.sin(p*5+i)).toFixed(2)}px,${(740-i*30-220*p).toFixed(2)}px) rotate(${(-12+8*Math.sin(p*4)).toFixed(2)}deg)`);});
  // 6:35 — the quiet notice: no wiggle, no sound
  const qi=E.outExpo(seg(t,3.02,3.5)), qx=E.inCubic(seg(t,4.86,5.12));
  show('qn',t>3&&t<5.15); op($('qn'),qi*(1-qx)); tf($('qn'),`translate(100px,${(G.qcy-G.qh/2-50*(1-qi)-30*qx).toFixed(2)}px)`);
  const pp=clamp(spring(t-3.4,8,1.7),0,1.2), px=E.inCubic(seg(t,4.84,5.06));
  op($('pro'),clamp((t-3.4)/0.1)*(1-px)); tf($('pro'),`translate(${(540-G.pro[0]/2).toFixed(2)}px,${(G.qcy+G.qh/2+44+20*(1-pp)).toFixed(2)}px) scale(${(0.7+0.3*pp).toFixed(4)})`);
  $('pro').style.boxShadow=`0 0 ${(60*pulse(t,3.45,4.2)).toFixed(1)}px rgba(226,178,62,${(0.45*pulse(t,3.45,4.2)).toFixed(2)})`;
  // 6:37 — no answer: it rings once more
  const in2=E.outExpo(seg(t,5.22,5.55)), x2=E.inOutCubic(seg(t,5.86,6.12));
  show(A2.a,t>5.2&&t<6.15); op(A2.a,in2*(1-x2)); tf(A2.a,`translate(100px,${(G.acy-A2.h/2+60*(1-in2)).toFixed(2)}px) scale(${(0.96+0.04*in2+0.04*x2).toFixed(4)})`);
  const e2=ringing(A2.M,t,5.28,6.2);
  tf($('rglow'),`translate(540px,${G.acy}px) scale(${(1+0.06*Math.max(e1,e2)).toFixed(4)})`);
  op($('rglow'),0.85*Math.max(in1*(1-x1)*(t<0.97?1:1-seg(t,0.97,1.3)),in2*(1-x2)));
  envFlash(0.22*pulse(t,5.26,5.62));
  // the app, filmed: switch on (take A), then I'm up (take B)
  const pin=E.outExpo(seg(t,5.9,6.35)), pout=E.inOutCubic(seg(t,9.3,9.6));
  show('phwrap',t>5.88&&t<9.62); op($('phwrap'),clamp(pin*2.5)*(1-pout));
  tf($('phwrap'),`translateY(${(420*(1-pin)-40*pout).toFixed(2)}px) scale(${(0.96+0.04*pin-0.06*pout).toFixed(4)})`);
  op($('fadeB'),clamp(pin*2.5)*(1-pout));
  const jobs=[];
  if(t>5.88&&t<7.62) jobs.push(setFrame('capA','a',clamp(Math.round((t-A0)*60),0,NA-1)));
  if(t>7.3&&t<9.62) jobs.push(setFrame('capB','b',clamp(Math.round((t-B0)*60),0,NB-1)));
  op($('capB'),E.smooth(seg(t,7.36,7.56)));
  tapFX($('touch1'),$('ripple1'),t,{x:S.tog[0],y:S.tog[1],t0:6.26,from:[150,200],maxR:200});
  tapFX($('touch2'),$('ripple2'),t,{x:S.btn[0],y:S.btn[1],t0:8.31,from:[150,200],maxR:240});
  // end card
  show('end',t>9.5); if(t>9.5) renderLockup(L,t,9.62,1.6);
  const [gx,gy,go]=keyed([[0,540,1000,0],[5.9,540,1000,0],[6.3,540,1000,.32],[9.3,540,1000,.38],[9.7,540,740,.6],[12,540,760,.72]],t);
  envGlow(gx,gy,go);
  envStreak('streak1',740,t,10.02,10.32,.7);
  return Promise.all(jobs.filter(Boolean));
}
boot({init,render});

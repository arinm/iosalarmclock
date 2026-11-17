/* Shared bits for App Store banners: real app UI pieces + a QA overlay of Apple's template safe area. */
const DAYS=on=>'SMTWTFS'.split('').map((d,i)=>`<span class="${on.includes(i)?'a':''}">${d}</span>`).join('');
function alarmCard(parent,{time,label,days,foot,w=620}){
  const c=el('div','acardL card',`<div class="at">${time}</div><div class="al">${label}</div><div class="togL"><i></i></div><div class="ddL">${DAYS(days)}</div><div>${foot}</div>`,parent);
  c.style.width=w+'px'; return c;
}
const SKIPPED=()=>`<span class="pillL s">${ICON.tick(28)}Skipped today · still active</span>`;
const RINGS=()=>`<span class="chipL">${ICON.clock(30,'#d8d8de',2.2)}Rings in <b>7h 42m</b></span>`;
function place(e,x,y,{rot=0,s=1,o=1,blur=0}={}){e.style.left=x+'px';e.style.top=y+'px';tf(e,`rotate(${rot}deg) scale(${s})`);op(e,o);if(blur)e.style.filter=`blur(${blur}px)`;}
/* safe rectangle in CSS px (template measurement), shown only with banner.py ... safe */
function safeBox(x,y,w,h){const b=el('div',null,null,$('stage'));b.id='safe';Object.assign(b.style,{left:x+'px',top:y+'px',width:w+'px',height:h+'px'});}

/* Language: banner.py passes ?lang=xx (BANNER_LANG=ja). The tagline must say that
   Skip happens before the ring (not Stop) and that tomorrow still rings. */
const LANG=new URLSearchParams(location.search).get('lang')||'en';
document.documentElement.lang=LANG;
const TAG={
  en:['Skip <span class="s">today</span> before it rings.','<span class="a">Tomorrow</span> still rings.'],
  ja:['鳴る前に、<span class="s">今日</span>だけスキップ','<span class="a">明日</span>はいつも通り鳴る'],
  de:['<span class="s">Heute</span> überspringen, bevor er klingelt.','<span class="a">Morgen</span> klingelt er wie gewohnt.'],
  fr:['Ignorez <span class="s">aujourd’hui</span> avant qu’elle sonne.','<span class="a">Demain</span>, elle sonnera comme prévu.'],
  es:['Omite <span class="s">hoy</span> antes de que suene.','<span class="a">Mañana</span> sonará como siempre.'],
  'pt-BR':['Pule <span class="s">hoje</span> antes de tocar.','<span class="a">Amanhã</span> toca como sempre.']
}[LANG];

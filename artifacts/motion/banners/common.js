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

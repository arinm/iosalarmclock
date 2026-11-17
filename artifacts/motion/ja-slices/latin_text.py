"""Latin-script captions for the designed Slices: de, fr, es-ES, es-MX, pt-BR (en = self-test).
Run in the working folder of phones.py, text.py and erase.py, after them:
    SLICE_LANG=de python3 latin_text.py         # pano-de-final.png (+ -small) in the working folder
    SLICE_LANG=de python3 latin_text.py save    # also the store files, in app-store-screenshots/by-country/<lang ...>/;
                                                 # never overwrites: the earlier version moves to old/, the new one is -v2, -v3...
The en Slices use DM Sans Medium (wght 500, opsz 14): titles 104 px (slice 1: 140), subtitles 64 px,
line height 100%, white. Chromium draws it with Figma's kerning; PIL has no HarfBuzz here.
A role (title or subtitle) whose widest line passes MAXW shrinks for that slice; under ~90% re-break instead.
en self-test: ln -s pano-en.png pano-en-phones.png; SLICE_LANG=en python3 erase.py; SLICE_LANG=en python3 latin_text.py
"""
import os, sys, base64, math
import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright
L=os.environ.get('SLICE_LANG','de')
FONT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'fonts','DMSans[opsz,wght].ttf')
if not os.path.exists(FONT):
    sys.exit(f"missing {FONT}: get https://raw.githubusercontent.com/google/fonts/main/ofl/dmsans/DMSans%5Bopsz%2Cwght%5D.ttf (OFL)")
NB=' '
# slice: (title lines, subtitle lines); texts from app-store-listing-<lang>.md, line breaks chosen to fit
C={'en':{1:(["Skip today.","Never forget","tomorrow."],["The alarm that tells you","before it rings."]),   # the live en text, fixed 16 Nov 2026: s1 break, s3 dash, s5 ")", s6 grammar
         3:(["Always know","when it rings"],["A live countdown on every alarm.","“Rings in 6h 47m,”","updating in real time."]),
         4:(["Set it in seconds"],[]),
         5:(["Themes, app icons,","your own defaults."],[]),
         6:(["One tap skips","today or tomorrow."],[]),
         7:(["Go Pro when","you're ready"],["Vacation pause, alarm groups,","custom heads-ups, themes, and","your own sounds."])},
   'de':{1:(["Heute","überspringen,","morgen nie","vergessen"],["Der Wecker, der dich warnt,","bevor er klingelt."]),
         3:(["Immer wissen,","wann er klingelt"],["Ein Live-Countdown","bei jedem Wecker.","„Klingelt in 6"+NB+"h 47"+NB+"min“","aktualisiert sich in Echtzeit."]),
         4:(["In Sekunden","eingestellt"],[]),
         5:(["Designs, App-Symbole","und Standards –","ganz nach deinem Stil."],[]),
         6:(["Ein Tipp überspringt","heute oder","morgen."],[]),
         7:(["Mit Pro starten,","wenn du so weit bist"],["Urlaubspause, Weckergruppen,","eigene Vorwarnungen,","Designs und eigene Töne."])},
   'fr':{1:(["Ignorez","aujourd’hui,","sans oublier","demain"],["L’alarme qui vous prévient","avant de sonner."]),
         3:(["Sachez toujours","quand elle sonne"],["Un compte à rebours en direct","sur chaque alarme.","«"+NB+"Sonne dans 6 h 47 min"+NB+"»","se met à jour en temps réel."]),
         4:(["Réglez-la en","quelques secondes"],[]),
         5:(["Thèmes, icônes d’app","et réglages par défaut,","à votre façon."],[]),
         6:(["Un appui ignore","aujourd’hui ou","demain."],[]),
         7:(["Passez à Pro","quand vous voulez"],["Pause vacances, groupes d’alarmes,","pré-alertes personnalisées, thèmes","et vos propres sons."])},
   'es-ES':{1:(["Omite hoy,","sin olvidar","mañana"],["La alarma que te avisa","antes de sonar."]),
         3:(["Siempre sabrás","cuándo suena"],["Una cuenta atrás en vivo","en cada alarma.","“Suena en 6h 47m”","se actualiza en tiempo real."]),
         4:(["Prográmala","en segundos"],[]),
         5:(["Temas, iconos","y preferencias","a tu manera."],[]),
         6:(["Un toque omite","hoy o","mañana."],[]),
         7:(["Hazte Pro","cuando quieras"],["Pausa por vacaciones,","grupos de alarmas,","avisos previos personalizados,","temas y tus propios sonidos."])},
   'pt-BR':{1:(["Pule hoje,","sem esquecer","amanhã"],["O alarme que avisa","antes de tocar."]),
         3:(["Saiba sempre","quando toca"],["Contagem regressiva ao vivo","em cada alarme.","“Toca em 6h 47m”","se atualiza em tempo real."]),
         4:(["Configure","em segundos"],[]),
         5:(["Temas, ícones do app","e padrões,","do seu jeito."],[]),
         6:(["Um toque pula","hoje ou","amanhã."],[]),
         7:(["Passe para o Pro","quando quiser"],["Pausa nas férias, grupos de alarmes,","alertas prévios personalizados,","temas e seus próprios sons."])}}
C['es-MX']={**C['es-ES'],3:(["Siempre sabrás","cuándo suena"],["Una cuenta regresiva en vivo","en cada alarma.","“Suena en 6h 47m”","se actualiza en tiempo real."])}
# slice: align, title px, anchor ('top' = cap top of the first line, 'mid' = middle of cap top..last baseline),
#        anchor y, en gap last title baseline -> first subtitle baseline, (min cap top, max last baseline)
LAYOUT={1:('c',140,'top',708,151,(680,1480)),   # app icon above, the Home phone below
        3:('c',104,'mid',2293.1,133,(1850,2690)),
        4:('c',104,'mid',350.6,0,(110,600)),
        5:('c',104,'mid',341.6,0,(110,600)),
        6:('c',104,'mid',341.1,0,(110,600)),
        7:('l',104,'mid',2355.1,132,(1850,2690))}
SUB=64; CAPH=0.7; MAXW=1060; LEFT=114; CX=645; W,H=1290,2796
CSS="""@font-face{font-family:D;src:url(data:font/ttf;base64,%s)}
html,body{margin:0;background:transparent}
.l{position:absolute;white-space:pre;color:#fff;font-family:D;line-height:1;letter-spacing:0;
-webkit-font-smoothing:antialiased;font-optical-sizing:none;font-variation-settings:'wght' 500,'opsz' 14}
.m{display:inline-block;width:0;height:0;vertical-align:baseline}"""%base64.b64encode(open(FONT,'rb').read()).decode()
MEASURE="""items=>items.map(([t,px])=>{const d=document.createElement('div');d.className='l';d.style.fontSize=px+'px';
 const s=document.createElement('span');s.textContent=t;const m=document.createElement('span');m.className='m';
 d.append(s,m);document.body.append(d);
 const r=[s.getBoundingClientRect().width,m.getBoundingClientRect().top-d.getBoundingClientRect().top];d.remove();return r})"""
PLACE="""items=>document.body.replaceChildren(...items.map(([t,px,x,y])=>{const d=document.createElement('div');
 d.className='l';d.textContent=t;Object.assign(d.style,{fontSize:px+'px',left:x+'px',top:y+'px'});return d}))"""
img=Image.open(f'pano-{L}-clean.png').convert('RGB')
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={'width':W,'height':H},device_scale_factor=1)
    pg.set_content(f"<style>{CSS}</style>")
    assert pg.evaluate("document.fonts.load('104px D').then(f=>f.length)")==1, 'DM Sans did not load'
    def fit(lines,px):
        if not lines: return px,[]
        m=pg.evaluate(MEASURE,[[t,px] for t in lines]); widest=max(w for w,_ in m)
        if widest>MAXW:
            px=math.floor(px*MAXW/widest); m=pg.evaluate(MEASURE,[[t,px] for t in lines])
        return px,m
    for k,(tl,sl) in C[L].items():
        al,ts0,anchor,ay,gap0,(lo,hi)=LAYOUT[k]
        ts,tm=fit(tl,ts0); ss,sm=fit(sl,SUB)
        gap=gap0-0.159*(ts0-ts)-0.841*(SUB-ss)   # Figma: fixed space between the text boxes
        h=CAPH*ts+(len(tl)-1)*ts+((gap+(len(sl)-1)*ss) if sl else 0)
        b0=(ay if anchor=='top' else ay-h/2)+CAPH*ts
        items=[];y=b0
        for lines,px,m,pitch in [(tl,ts,tm,ts),(sl,ss,sm,ss)]:
            for t,(w,base) in zip(lines,m):
                items.append([t,px,(CX-w/2) if al=='c' else LEFT,y-base]); last=y; y+=pitch
            y+=gap-pitch
        warn=[]
        if ts<0.9*ts0 or (sl and ss<0.9*SUB): warn.append('shrunk under 90%: re-break')
        if b0-CAPH*ts<lo or last>hi: warn.append(f'outside {lo}..{hi}')
        print(f"slice {k}: title {ts}px x{len(tl)} widest {max(w for w,_ in tm):.0f}"
              +(f" | sub {ss}px x{len(sl)} widest {max(w for w,_ in sm):.0f}" if sl else "")
              +f" | cap top {b0-CAPH*ts:.0f}, last baseline {last:.0f}"+(f"  WARNING: {', '.join(warn)}" if warn else ""))
        pg.evaluate(PLACE,items)
        layer=Image.open(__import__('io').BytesIO(pg.screenshot(omit_background=True))).convert('RGBA')
        x0=(k-1)*W; tile=img.crop((x0,0,x0+W,H)).convert('RGBA')
        img.paste(Image.alpha_composite(tile,layer).convert('RGB'),(x0,0))
    b.close()
img.save(f'pano-{L}-final.png'); img.resize((img.width//4,img.height//4),Image.LANCZOS).save(f'pano-{L}-final-small.png')
if sys.argv[1:]==['save']:   # into the ASC upload folder of that store localization
    FOLDER={'en':'en-US English (U.S.)','de':'de German','fr':'fr French','es-ES':'es-ES Spanish (Spain)',
            'es-MX':'es-MX Spanish (Mexico)','pt-BR':'pt-BR Portuguese (Brazil)'}
    D=f"/Users/test/Project/alarm/artifacts/app-store-screenshots/by-country/{FOLDER[L]}/"
    def store(path):   # never overwrite: earlier versions move to old/, the new one gets -v2, -v3...
        d,f=os.path.split(path); b_,e=os.path.splitext(f); od=os.path.join(d,'old')
        ver=lambda n:f"{b_}{'' if n==1 else f'-v{n}'}{e}"
        n=1
        while any(os.path.exists(os.path.join(x,ver(n))) for x in (d,od)): n+=1
        for m in range(1,n):
            if os.path.exists(os.path.join(d,ver(m))):
                os.makedirs(od,exist_ok=True); os.rename(os.path.join(d,ver(m)),os.path.join(od,ver(m)))
        return os.path.join(d,ver(n))
    os.makedirs(D+"1290x2796",exist_ok=True)
    for i,k in enumerate([1,2,3,7,8,4,6,5]):   # the live en upload order
        s=img.crop(((k-1)*W,0,k*W,H))
        s.save(store(D+f"1290x2796/slice-{k}-{L}-1290x2796.png"))
        s.resize((1210,2622),Image.LANCZOS).crop((2,0,1208,2622)).save(store(D+f"{i+1:02d}-slice-{k}-{L}-1206x2622.png"))
    print('saved',D)

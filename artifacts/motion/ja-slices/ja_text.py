import numpy as np, os
from PIL import Image, ImageDraw, ImageFont
F="/System/Library/Fonts/ヒラギノ角ゴシック W%d.ttc"
img=Image.open('pano-ja-clean.png').convert('RGB'); d=ImageDraw.Draw(img)
# slice, align, title top, en gap title->sub, title size, title lines, sub lines
S=[(1,'c',703,103,112,["今日だけスキップ。","明日は忘れない。"],["鳴る前に知らせてくれる目覚まし。"]),
   (3,'c',2073,63,88,["いつ鳴るか、","ひと目でわかる"],["すべてのアラームに残り時間を表示。","「鳴るまであと6時間47分」が","リアルタイムで更新されます。"]),
   (4,'c',311,0,88,["数秒でセット"],[]),
   (5,'c',198,0,88,["テーマも、","アプリアイコンも、","初期設定も自分好みに。"],[]),
   (6,'c',198,0,88,["ワンタップで、","今日か明日を","スキップ。"],[]),
   (7,'l',2134,64,88,["必要になったら","Proへ"],["休暇中の一時停止、アラームのグループ、","事前通知のカスタマイズ、テーマ、","好きなサウンドも。"])]
SUB=52
for k,al,top,gap,ts,tl,sl in S:
    x0=(k-1)*1290; cx=x0+645; lx=x0+116
    y=top
    for lines,size,w,pitch in [(tl,ts,5,1.28),(sl,SUB,3,1.45)]:
        if not lines: continue
        f=ImageFont.truetype(F%w,size)
        for t in lines:
            bb=d.textbbox((0,0),t,font=f)
            x=cx-(bb[2]-bb[0])/2-bb[0] if al=='c' else lx-bb[0]
            d.text((x,y-bb[1]),t,font=f,fill=(255,255,255))
            y+=size*pitch
        y+=gap-size*(pitch-1)
out="/Users/test/Project/alarm/artifacts/app-store-screenshots/iphone-69/ja-slices"
os.makedirs(out,exist_ok=True)
for k in range(8):
    img.crop((k*1290,0,(k+1)*1290,2796)).save(f"{out}/slice-{k+1}-ja-1290x2796.png")
img.resize((img.width//4,img.height//4)).save('pano-ja-final-small.png')

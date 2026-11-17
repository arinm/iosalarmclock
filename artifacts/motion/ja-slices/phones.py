import numpy as np, cv2, json, os
from PIL import Image
R="/Users/test/Project/alarm/artifacts/app-store-screenshots/"
L=os.environ.get('SLICE_LANG','ja')   # store language; es-ES uses the es captures
CAP={'es-ES':'es'}.get(L,L)
M=json.load(open('matches.json'))
pano=np.asarray(Image.open('pano-en.png').convert('RGB')).astype(np.float32)
H_,W_=pano.shape[:2]
def Hrect(dst):
    return cv2.getPerspectiveTransform(np.float32([[0,0],[1320,0],[1320,2868],[0,2868]]),np.float32(dst))
jobs=[ # en capture, H source, localized capture
 ("iphone-17-pro-max-v2/png/01-Home.png",None,"01-Home.png"),
 ("iphone-17-pro-max-v2/png/02-Editor.png",None,"02-Editor.png"),
 ("iphone-17-pro-max-v2/png/03-Settings.png",None,"03-Settings.png"),
 (None,[[6635,685],[7556,685],[7556,2687],[6635,2687]],"06-SkipButton.png"),
 ("iphone-17-pro-max-v2/png/05-Detail.png",None,"05-Detail.png"),
]
out=pano.copy()
import sys
RADIUS=int(sys.argv[1]) if len(sys.argv)>1 else 180
for en,dst,cap in jobs:
    H=np.array(M[en]['H']) if en else Hrect(dst)
    jim=np.asarray(Image.open(R+f"iphone-17-pro-max-{CAP}/png/"+cap).convert('RGB')).astype(np.float32)
    wj=cv2.warpPerspective(jim,H,(W_,H_),flags=cv2.INTER_LANCZOS4)
    rr=np.zeros((2868,1320),np.uint8);r=RADIUS
    cv2.rectangle(rr,(r,0),(1320-r,2868),1,-1);cv2.rectangle(rr,(0,r),(1320,2868-r),1,-1)
    for cx,cy in [(r,r),(1320-r,r),(r,2868-r),(1320-r,2868-r)]: cv2.circle(rr,(cx,cy),r,1,-1)
    rect=cv2.warpPerspective(rr.astype(np.float32),H,(W_,H_))
    if en:
        eim=np.asarray(Image.open(R+en).convert('RGB')).astype(np.float32)
        we=cv2.warpPerspective(eim,H,(W_,H_),flags=cv2.INTER_LANCZOS4)
        d=np.abs(we-pano).sum(2)
        vis=((d<60)&(rect>0.99)).astype(np.uint8)
        vis=cv2.morphologyEx(vis,cv2.MORPH_CLOSE,np.ones((9,9),np.uint8))
        zone=np.zeros((2868,1320),np.float32);zone[20:230,380:940]=1   # Dynamic Island + camera only
        zone=cv2.warpPerspective(zone,H,(W_,H_))>0.5
        overlay=((we.sum(2)<40)&(d>8)&zone).astype(np.uint8)   # island, camera: device drawn over a black status bar
        overlay=cv2.morphologyEx(overlay,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
        ov=cv2.dilate(overlay,np.ones((3,3),np.uint8))
        last=(vis,ov)
        vis=vis&(1-ov)
    else:
        vis=np.roll(last[0],1290,axis=1)&(1-np.roll(last[1],1290,axis=1))   # same device frame as the previous phone, one slice to the right
    np.save(cap+'.mask.npy',vis)
    a=cv2.GaussianBlur(vis.astype(np.float32),(3,3),0)[...,None]
    out=out*(1-a)+wj*a
    ys,xs=np.nonzero(vis);print(cap,vis.sum(),xs.min(),xs.max(),ys.min(),ys.max())
Image.fromarray(out.clip(0,255).astype(np.uint8)).save(f'pano-{L}-phones.png')
Image.fromarray(out.clip(0,255).astype(np.uint8)).resize((W_//4,H_//4)).save(f'pano-{L}-phones-small.png')

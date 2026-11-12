import numpy as np, cv2, glob
from PIL import Image
pano=np.asarray(Image.open('pano-en.png').convert('RGB'))
H_,W_=pano.shape[:2]
phones=np.zeros((H_,W_),np.uint8)
for f in glob.glob('*.mask.npy'): phones|=np.load(f)
phones=cv2.dilate(phones,np.ones((161,161),np.uint8))
white=(pano.min(2)>170).astype(np.uint8)&(1-phones)
n,lab,st,_=cv2.connectedComponentsWithStats(white)
for k in range(8):
    x0=k*1290
    comps=[st[i] for i in range(1,n) if st[i][4]>30 and x0<=st[i][0]<x0+1290]
    if not comps: print(k+1,'none');continue
    ys=sorted(set())
    # group into lines by y
    lines=[]
    for c in sorted(comps,key=lambda c:c[1]):
        x,y,w,h,a=c
        for L in lines:
            if abs(L[1]-y)<40 or (y<L[3] and y+h>L[1]): L[0]=min(L[0],x);L[1]=min(L[1],y);L[2]=max(L[2],x+w);L[3]=max(L[3],y+h);break
        else: lines.append([x,y,x+w,y+h])
    print(k+1,[[v-(x0 if i%2==0 else 0) for i,v in enumerate(L)] for L in lines])
np.save('white.npy',white)

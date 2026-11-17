import numpy as np, cv2, os
from PIL import Image
L=os.environ.get('SLICE_LANG','ja')
pano=np.asarray(Image.open(f'pano-{L}-phones.png').convert('RGB'))
en=np.asarray(Image.open('pano-en.png').convert('RGB')).astype(int)
white=np.load('white.npy')
# antialiased text edges: anything noticeably lighter than the surrounding fill, near the white core
near=cv2.dilate(white,np.ones((15,15),np.uint8))
m=cv2.dilate(white,np.ones((7,7),np.uint8))
ys,xs=np.nonzero(white); print('text color',np.median(en[ys,xs],axis=0))
out=pano.copy()
# inpaint per slice to keep it fast
for k in range(8):
    sl=slice(k*1290,(k+1)*1290)
    if m[:,sl].any():
        out[:,sl]=cv2.inpaint(np.ascontiguousarray(pano[:,sl]),np.ascontiguousarray(m[:,sl]),9,cv2.INPAINT_TELEA)
Image.fromarray(out).save(f'pano-{L}-clean.png')
Image.fromarray(out).resize((W:=out.shape[1]//4,out.shape[0]//4)).save(f'pano-{L}-clean-small.png')
# snap inpainted pixels to the flat background colours (removes faint ghosts of the old letters)
cols=out.reshape(-1,3)[::97]
u,c=np.unique(cols,axis=0,return_counts=True)
pal=u[np.argsort(-c)[:4]].astype(int); print('palette',pal.tolist(),c[np.argsort(-c)[:4]])
ys,xs=np.nonzero(m)
px=out[ys,xs].astype(int)
dist=np.abs(px[:,None,:]-pal[None]).sum(2)
best=dist.argmin(1); ok=dist.min(1)<45
out[ys[ok],xs[ok]]=pal[best[ok]]
Image.fromarray(out).save(f'pano-{L}-clean.png')

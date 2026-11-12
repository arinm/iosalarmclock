import numpy as np, cv2, glob, json
from PIL import Image
P=f"/Users/test/Downloads/500+ App store screenshot templates (for Android and iOS apps) (Community)"
files=[f"{P} (11)/Slice 1.png",f"{P} (11)/Slice 2.png"]+[f"{P} (10)/Slice {i}.png" for i in range(3,7)]+[f"{P} (12)/Slice 7.png",f"{P} (10)/Slice 8.png"]
pano=np.concatenate([np.asarray(Image.open(f).convert('RGB')) for f in files],axis=1)
Image.fromarray(pano).save('pano-en.png')
g=cv2.cvtColor(pano,cv2.COLOR_RGB2GRAY)
sift=cv2.SIFT_create(40000)
kp2,d2=sift.detectAndCompute(g,None)
R="/Users/test/Project/alarm/artifacts/app-store-screenshots/"
caps=glob.glob(R+"iphone-17-pro-max/png/*.png")+glob.glob(R+"iphone-17-pro-max-v2/png/*.png")+glob.glob(R+"build21/0*.png")
bf=cv2.BFMatcher()
out={}
for c in caps:
    im=cv2.cvtColor(np.asarray(Image.open(c).convert('RGB')),cv2.COLOR_RGB2GRAY)
    kp1,d1=sift.detectAndCompute(im,None)
    m=[a for a,b in bf.knnMatch(d1,d2,k=2) if a.distance<0.7*b.distance]
    if len(m)<15: continue
    src=np.float32([kp1[a.queryIdx].pt for a in m]);dst=np.float32([kp2[a.trainIdx].pt for a in m])
    H,mask=cv2.findHomography(src,dst,cv2.RANSAC,4.0)
    inl=int(mask.sum())
    corners=cv2.perspectiveTransform(np.float32([[0,0],[1320,0],[1320,2868],[0,2868]])[None],H)[0]
    print(c.replace(R,''),len(m),inl,corners.round().tolist())
    out[c.replace(R,'')]=dict(inl=inl,H=H.tolist(),corners=corners.tolist())
json.dump(out,open('matches.json','w'))

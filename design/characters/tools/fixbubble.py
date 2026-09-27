import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
im=Image.open('fills/f535ecdcb123e438ba478d98e8788a89f9ff4de0').convert('RGBA')
a=np.array(im).astype(float)
x0,x1,y0,y1=650,1098,106,306
reg=a[y0:y1,x0:x1,:3]
lum=reg.mean(2); sat=reg.max(2)-reg.min(2)
text=(lum<205)|(sat>70)
# sample text colours
line1=a[140:215,x0:x1,:3][text[34:109]]; line2=a[225:300,x0:x1,:3][text[119:194]]
print('c1',np.median(line1,0),'c2',np.median(line2,0), 'dark1', np.percentile(line1.mean(1),5))
text[:22,:60]=False; text[:22,-15:]=False
m=Image.fromarray((text*255).astype('uint8')).filter(ImageFilter.MaxFilter(9))
mask=np.array(m)>0; mask[:22,:60]=False; mask[:22,-15:]=False
# fit on wider ring of clean interior pixels
X0,X1,Y0,Y1=640,1105,105,330
big=a[Y0:Y1,X0:X1,:3]; bl=big.mean(2); bs=big.max(2)-big.min(2)
clean=(bl>205)&(bs<70)&(a[Y0:Y1,X0:X1,3]>250)
# exclude text box area itself (with dilation) and the wave icon
ex=np.zeros_like(clean); ex[y0-Y0:y1-Y0,x0-X0:x1-X0]=mask
wave=np.zeros_like(clean); wave[295-Y0:360-Y0,820-X0:940-X0]=True
clean&=~ex; clean&=~wave
yy,xx=np.mgrid[Y0:Y1,X0:X1]
def feats(x,y):
    x=(x-870)/250; y=(y-220)/120
    return np.stack([x**i*y**j for i in range(5) for j in range(5) if i+j<=4],-1)
F=feats(xx[clean],yy[clean])
out=a.copy()
Fm=feats(*np.mgrid[y0:y1,x0:x1][::-1])
for c in range(3):
    coef,*_=np.linalg.lstsq(F,big[...,c][clean],rcond=None)
    pred=Fm@coef
    ch=out[y0:y1,x0:x1,c]
    ch[mask]=pred[mask]
# soft blend edge: feather mask
fm=np.array(m.filter(ImageFilter.GaussianBlur(2))).astype(float)/255
for c in range(3):
    orig=a[y0:y1,x0:x1,c]; filled=out[y0:y1,x0:x1,c]
    out[y0:y1,x0:x1,c]=orig*(1-fm)+filled*fm
res=Image.fromarray(np.clip(out,0,255).astype('uint8'))
res.save('f535_clean.png')

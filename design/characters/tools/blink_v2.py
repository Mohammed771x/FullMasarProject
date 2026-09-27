from PIL import Image, ImageDraw, ImageFilter
import numpy as np, json
eyes={'robot_head':[(191, 424, 386, 563), (506, 555, 686, 690)],
      'robot_hello':[(254,222,344,288),(418,290,500,354)],
      'robot_ask':[(324,224,420,292),(492,294,576,358)],
      'robot_guide':[(428,228,520,296),(266,284,364,358)]}
out={}
eyes={k:[(x0-12,y0-3,x1+12,y1+10) for (x0,y0,x1,y1) in v] for k,v in eyes.items()}
def fit_fill(a,box,pad,excl,protect=None):
    x0,y0,x1,y1=box
    X0,Y0,X1,Y1=x0-pad*2,y0-pad*2,x1+pad*2,y1+pad*2
    reg=a[Y0:Y1,X0:X1,:3].astype(float)
    yy,xx=np.mgrid[Y0:Y1,X0:X1]
    inner=(xx>=x0-pad)&(xx<=x1+pad)&(yy>=y0-pad)&(yy<=y1+pad)
    br=reg.max(2)
    ring=(~inner)&(br<120)&(a[Y0:Y1,X0:X1,3]>250)&(~excl[Y0:Y1,X0:X1])
    cx,cy,sx,sy=(x0+x1)/2,(y0+y1)/2,(X1-X0)/2,(Y1-Y0)/2
    def F(x,y):
        x=(x-cx)/sx; y=(y-cy)/sy
        return np.stack([x**i*y**j for i in range(4) for j in range(4) if i+j<=3],-1)
    A=F(xx[ring],yy[ring])
    res=a.copy().astype(float)
    Fi=F(xx,yy)
    feather=np.zeros(inner.shape); feather[inner]=1
    feather=np.array(Image.fromarray((feather*255).astype('uint8')).filter(ImageFilter.GaussianBlur(pad/2))).astype(float)/255
    if protect is not None:
        feather=feather*(1-protect[Y0:Y1,X0:X1])
    for c in range(3):
        coef,*_=np.linalg.lstsq(A,reg[...,c][ring],rcond=None)
        pred=np.clip(Fi@coef,0,255)
        res[Y0:Y1,X0:X1,c]=reg[...,c]*(1-feather)+pred*feather
    return res
for k,bxs in eyes.items():
    im=Image.open(f'out/{k}.png').convert('RGBA'); a=np.array(im).astype(int)
    led=(a[...,2]>200)&(a[...,1]>140)&(a[...,0]<170)
    excl=np.zeros(led.shape,bool)
    # other LED pixels (mouth) excluded from the ring fit
    for b in bxs: pass
    excl|=led
    ends=[]
    for b in bxs:
        x0,y0,x1,y1=b
        sub=led[y0:y1,x0:x1]; ys,xs=np.nonzero(sub)
        w=x1-x0
        L=(xs<w*0.3); R=(xs>w*0.7)
        # arc ends = lowest LED pixels in the left and right thirds
        lp=(x0+xs[L][np.argmax(ys[L])], y0+ys[L].max()); rp=(x0+xs[R][np.argmax(ys[R])], y0+ys[R].max())
        # stroke thickness ~ LED pixel count / arc length
        ends.append((lp,rp))
    af=a.astype(float)
    pad=14
    inbox=np.zeros(led.shape,bool)
    for b in bxs: inbox[b[1]:b[3],b[0]:b[2]]=True
    mouth=(led&~inbox).astype('uint8')*255
    prot=np.array(Image.fromarray(mouth).filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(4))).astype(float)/255
    for b in bxs: af=fit_fill(af.astype(int),b,pad,excl,prot)
    closed=Image.fromarray(np.clip(af,0,255).astype('uint8'))
    # draw closed LED eyes (a soft, gently curved line) with glow
    SS=4
    glow=Image.new('RGBA',(im.width*SS,im.height*SS),(0,0,0,0)); core=Image.new('RGBA',glow.size,(0,0,0,0)); hot=Image.new('RGBA',glow.size,(0,0,0,0))
    dg=ImageDraw.Draw(glow); dc=ImageDraw.Draw(core); dh=ImageDraw.Draw(hot)
    for (lp,rp),b in zip(ends,bxs):
        th=max(10,(b[3]-b[1])*0.24)
        mx,my=(lp[0]+rp[0])/2,(lp[1]+rp[1])/2
        for t in np.linspace(0,1,400):
            x=(1-t)**2*lp[0]+2*(1-t)*t*mx+t*t*rp[0]
            y=(1-t)**2*lp[1]+2*(1-t)*t*(my+th*1.1)+t*t*rp[1]-th*0.5
            X,Y=x*SS,y*SS
            r=th*SS/2; dc.ellipse((X-r,Y-r,X+r,Y+r),fill=(70,205,255,255))
            r2=th*SS*1.3; dg.ellipse((X-r2,Y-r2,X+r2,Y+r2),fill=(0,120,255,150))
            r3=th*SS*0.2; dh.ellipse((X-r3,Y-r3,X+r3,Y+r3),fill=(215,248,255,255))
    th=10
    glow=glow.resize(im.size,Image.LANCZOS).filter(ImageFilter.GaussianBlur(7))
    core=core.resize(im.size,Image.LANCZOS); hot=hot.resize(im.size,Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    closed.alpha_composite(glow); closed.alpha_composite(core); closed.alpha_composite(hot)
    # patch = union of eye boxes + margin
    X0=min(b[0] for b in bxs)-pad*2; Y0=min(b[1] for b in bxs)-pad*2
    X1=max(b[2] for b in bxs)+pad*2; Y1=max(b[3] for b in bxs)+pad*2
    patch=closed.crop((X0,Y0,X1,Y1))
    patch.save(f'out/{k}_blink.png',optimize=True)
    out[k]={'w':im.width,'h':im.height,'patch':[X0,Y0,X1,Y1]}
    # preview: open vs closed
    pv=Image.new('RGBA',(im.width*2,im.height),'white')
    pv.alpha_composite(im,(0,0)); c2=im.copy(); c2.alpha_composite(patch,(X0,Y0)); pv.alpha_composite(c2,(im.width,0))
    pv=pv.crop((0,0,pv.width,pv.height)); pv.thumbnail((1000,500)); pv.save(f'out/{k}_blinkpv.png')
json.dump(out,open('blink.json','w'),indent=1); print(json.dumps(out))

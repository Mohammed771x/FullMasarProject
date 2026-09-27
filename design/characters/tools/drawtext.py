import numpy as np
from PIL import Image, ImageDraw, ImageFont
orig=np.array(Image.open('fills/f535ecdcb123e438ba478d98e8788a89f9ff4de0').convert('RGBA')).astype(int)
def inkbox(y0,y1,x0=650,x1=1098):
    r=orig[y0:y1,x0:x1,:3]; t=(r.mean(2)<150)
    ys,xs=np.nonzero(t); return x0+xs.min(),y0+ys.min(),x0+xs.max(),y0+ys.max()
b1=inkbox(106,222,760,1000); b2=inkbox(222,300)
print('orig line1',b1,'line2',b2)
def font(sz,w='Black'):
    f=ImageFont.truetype('CairoVar.ttf',sz); f.set_variation_by_name(w); return f
def ink(txt,f):
    im=Image.new('L',(2000,400)); d=ImageDraw.Draw(im); d.text((50,50),txt,font=f,fill=255,direction='rtl',language='ar')
    return im.getbbox()
# calibrate sizes from the original strings
def fit(txt,target_w,w):
    for s in range(20,200):
        bb=ink(txt,font(s,w))
        if bb[2]-bb[0]>=target_w: return s
s2=fit('عقلّ اصطناعي متطور',b2[2]-b2[0],'Bold'); s1=fit('أنا',b1[2]-b1[0],'Black')
s1=int(s1*0.88); s2=int(s2*1.12); print('sizes',s1,s2)
import sys
L1,L2=sys.argv[1],sys.argv[2]
im=Image.open('f535_clean.png').convert('RGBA')
cx=(b2[0]+b2[2])/2
def put(txt,f,col,top):
    bb=ink(txt,f); w=bb[2]-bb[0]
    layer=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(layer)
    d.text((cx-w/2-(bb[0]-50),top-(bb[1]-50)),txt,font=f,fill=col,direction='rtl',language='ar')
    im.alpha_composite(layer); return w
w1=put(L1,font(s1,'Black'),(10,14,70,255),b1[1]+6)
w2=put(L2,font(s2,'Bold'),(12,70,245,255),b2[1]-4)
print('new widths',w1,w2)
im.save('robot_brain.png')
c=im.crop((600,50,1145,460)); bg=Image.new('RGBA',c.size,'white'); bg.alpha_composite(c); bg.save('new_zoom.png')

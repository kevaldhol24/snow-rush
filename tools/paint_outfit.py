import sys
sys.path.insert(0,'tools')
from gltf_mesh import load
from PIL import Image, ImageDraw, ImageFilter, ImageChops
SRC=sys.argv[1]; TEX=sys.argv[2]; OUT=sys.argv[3]; PREVIEW=sys.argv[4]
P,UV,I,g=load(SRC,'Sphere.005_Retopology.004')
base=Image.open(TEX).convert('RGB'); W,H=base.size
# classes: 0 keep(face/head), 1 jacket, 2 jacket accent (shoulders/upper sleeves), 3 collar, 4 gloves, 5 pants, 6 boots, 7 pants accent (knees)
COL={1:(236,92,44),2:(36,150,160),3:(30,40,60),4:(34,34,40),5:(40,56,92),6:(60,62,72),7:(30,42,72)}
mask=Image.new('L',(W,H),0); d=ImageDraw.Draw(mask)
def cls(x,y,z):
    ax=abs(x)
    if y>1.535: return 0
    if ax>0.665: return 4                    # hands -> gloves
    if y>1.42 and ax<0.13: return 3          # neck -> collar
    if ax>0.17 and y>1.15:                   # arms -> sleeves (upper part accent)
        return 2 if ax<0.36 else 1
    if y>=0.93: return 1                     # torso -> jacket
    if y<=0.13: return 6                     # feet -> boots
    if 0.42<y<0.58: return 7                 # knee panels
    return 5                                 # legs -> pants
for t in range(0,len(I),3):
    a,b,c=I[t],I[t+1],I[t+2]
    cx=(P[a][0]+P[b][0]+P[c][0])/3; cy=(P[a][1]+P[b][1]+P[c][1])/3; cz=(P[a][2]+P[b][2]+P[c][2])/3
    k=cls(cx,cy,cz)
    if k==0: continue
    poly=[(UV[v][0]*W, UV[v][1]*H) for v in (a,b,c)]
    d.polygon(poly, fill=k)
# grow labels into gutters so mip-maps don't bleed skin at seams
grown=mask
for _ in range(4):
    grown=ImageChops.lighter(grown, grown.filter(ImageFilter.MaxFilter(3)))
out=base.copy(); px=out.load(); mp=grown.load(); bp=base.load()
for y in range(H):
    for x in range(W):
        k=mp[x,y]
        if k:
            r,g_,b=bp[x,y]; l=(r*0.3+g_*0.59+b*0.11)/255.0
            s=0.82+0.30*l  # keep a hint of the sculpt shading (folds/AO)
            c=COL[k]; px[x,y]=(min(255,int(c[0]*s)),min(255,int(c[1]*s)),min(255,int(c[2]*s)))
out.save(OUT,optimize=True)
out.resize((512,512)).save(PREVIEW)
print('ok',W,H)

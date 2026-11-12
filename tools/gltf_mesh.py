import json,struct,sys
def load(path, mesh_name):
    g=json.load(open(path)); binp=path.rsplit('/',1)[0]+'/'+g['buffers'][0]['uri']; buf=open(binp,'rb').read()
    def acc(i):
        a=g['accessors'][i]; bv=g['bufferViews'][a['bufferView']]; off=bv.get('byteOffset',0)+a.get('byteOffset',0)
        n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]; ct={5126:'f',5123:'H',5125:'I',5121:'B'}[a['componentType']]
        sz=struct.calcsize(ct); stride=bv.get('byteStride',sz*n); out=[]
        for k in range(a['count']):
            v=struct.unpack_from('<'+ct*n, buf, off+k*stride); out.append(v if n>1 else v[0])
        return out
    for m in g['meshes']:
        if m['name']==mesh_name:
            p=m['primitives'][0]
            return acc(p['attributes']['POSITION']), acc(p['attributes']['TEXCOORD_0']), acc(p['indices']), g
    raise SystemExit('mesh not found: '+str([m['name'] for m in g['meshes']]))
if __name__=='__main__':
    P,UV,I,g=load(sys.argv[1], sys.argv[2])
    xs=[p[0] for p in P]; ys=[p[1] for p in P]; zs=[p[2] for p in P]
    print('verts',len(P),'tris',len(I)//3,'x',min(xs),max(xs),'y',min(ys),max(ys),'z',min(zs),max(zs))
    print('node transforms:',[ (n.get('name'), n.get('rotation'), n.get('scale'), n.get('translation')) for n in g['nodes'] if 'mesh' in n])

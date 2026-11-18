// Junta animações dos rigs KayKit (Rig_Medium_*.glb) num personagem sem animação.
// Os ossos são casados pelo nome; as animações viram parte do GLB de saída.
//
// Uso: node tools/merge_anims.js <personagem.glb> <saida.glb> <rig1.glb>[,<rig2.glb>...] [Anim1,Anim2,...]
// Os GLB de entrada são os que o editor Doriax gera em .doriax/imported/ a partir dos .fbx.
// Sem a lista de animações, copia todas (menos T-Pose).
const fs = require('fs');

function readGlb(path) {
    const b = fs.readFileSync(path);
    if (b.readUInt32LE(0) !== 0x46546C67) throw new Error(path + ' is not a GLB');
    let off = 12, json = null, bin = Buffer.alloc(0);
    while (off < b.length) {
        const len = b.readUInt32LE(off), type = b.readUInt32LE(off + 4);
        const chunk = b.subarray(off + 8, off + 8 + len);
        if (type === 0x4E4F534A) json = JSON.parse(chunk.toString('utf8'));
        else if (type === 0x004E4942) bin = Buffer.from(chunk);
        off += 8 + len;
    }
    return { json, bin };
}

function writeGlb(path, json, bin) {
    const pad = (buf, byte) => {
        const rem = buf.length % 4;
        return rem ? Buffer.concat([buf, Buffer.alloc(4 - rem, byte)]) : buf;
    };
    json.buffers = [{ byteLength: bin.length }];
    const jsonBuf = pad(Buffer.from(JSON.stringify(json), 'utf8'), 0x20);
    const binBuf = pad(bin, 0);
    const header = Buffer.alloc(12);
    header.writeUInt32LE(0x46546C67, 0);
    header.writeUInt32LE(2, 4);
    header.writeUInt32LE(12 + 8 + jsonBuf.length + 8 + binBuf.length, 8);
    const jh = Buffer.alloc(8); jh.writeUInt32LE(jsonBuf.length, 0); jh.writeUInt32LE(0x4E4F534A, 4);
    const bh = Buffer.alloc(8); bh.writeUInt32LE(binBuf.length, 0); bh.writeUInt32LE(0x004E4942, 4);
    fs.writeFileSync(path, Buffer.concat([header, jh, jsonBuf, bh, binBuf]));
}

const [charPath, outPath, rigList, animList] = process.argv.slice(2);
if (!charPath || !outPath || !rigList) {
    console.error('usage: node tools/merge_anims.js <char.glb> <out.glb> <rig1.glb,rig2.glb> [Anim1,Anim2]');
    process.exit(1);
}
const wanted = animList ? new Set(animList.split(',')) : null;

const target = readGlb(charPath);
const tj = target.json;
let tbin = target.bin;
tj.animations = tj.animations || [];
tj.accessors = tj.accessors || [];
tj.bufferViews = tj.bufferViews || [];
const nodeByName = new Map();
tj.nodes.forEach((n, i) => { if (n.name && !nodeByName.has(n.name)) nodeByName.set(n.name, i); });

// Copia um accessor (e os bytes da bufferView) do rig para o personagem
function copyAccessor(src, srcBin, index, cache) {
    if (cache.has(index)) return cache.get(index);
    const acc = src.accessors[index];
    const view = src.bufferViews[acc.bufferView];
    const start = (view.byteOffset || 0);
    const bytes = srcBin.subarray(start, start + view.byteLength);
    const align = tbin.length % 4 ? 4 - (tbin.length % 4) : 0;
    if (align) tbin = Buffer.concat([tbin, Buffer.alloc(align)]);
    const newView = { buffer: 0, byteOffset: tbin.length, byteLength: view.byteLength };
    if (view.byteStride) newView.byteStride = view.byteStride;
    tbin = Buffer.concat([tbin, bytes]);
    tj.bufferViews.push(newView);
    const newAcc = Object.assign({}, acc, { bufferView: tj.bufferViews.length - 1 });
    tj.accessors.push(newAcc);
    const newIndex = tj.accessors.length - 1;
    cache.set(index, newIndex);
    return newIndex;
}

const existing = new Set(tj.animations.map(a => a.name));
for (const rigPath of rigList.split(',')) {
    const rig = readGlb(rigPath);
    for (const anim of rig.json.animations || []) {
        if (anim.name === 'T-Pose' || existing.has(anim.name)) continue;
        if (wanted && !wanted.has(anim.name)) continue;
        const cache = new Map();
        const samplers = [], channels = [], samplerMap = new Map();
        let skipped = 0;
        anim.channels.forEach(ch => {
            const name = rig.json.nodes[ch.target.node].name;
            const node = nodeByName.get(name);
            if (node === undefined) { skipped++; return; }
            if (!samplerMap.has(ch.sampler)) {
                const s = anim.samplers[ch.sampler];
                samplers.push({
                    input: copyAccessor(rig.json, rig.bin, s.input, cache),
                    output: copyAccessor(rig.json, rig.bin, s.output, cache),
                    interpolation: s.interpolation || 'LINEAR',
                });
                samplerMap.set(ch.sampler, samplers.length - 1);
            }
            channels.push({ sampler: samplerMap.get(ch.sampler), target: { node, path: ch.target.path } });
        });
        tj.animations.push({ name: anim.name, samplers, channels });
        existing.add(anim.name);
        console.log(`+ ${anim.name} (${channels.length} channels${skipped ? ', ' + skipped + ' skipped' : ''})`);
    }
}
if (wanted) {
    for (const w of wanted) if (!existing.has(w)) console.warn('! animation not found: ' + w);
}
writeGlb(outPath, tj, tbin);
console.log(`wrote ${outPath}: ${tj.animations.length} animations, ${tbin.length} bytes`);

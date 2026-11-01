"""Turn the hand-drawn SVG characters into Dart data for the rig engine.
Usage: python3 -I svg2rig.py out.dart name=file.svg ..."""
import sys, re, xml.etree.ElementTree as ET
NS = '{http://www.w3.org/2000/svg}'

def color(v):
    v = v.strip().lstrip('#')
    if len(v) == 3: v = ''.join(c*2 for c in v)
    return int('FF' + v.upper(), 16)

def num(e, k, d=0.0):
    v = e.get(k); return float(v) if v is not None else d

def rig(name, path):
    root = ET.parse(path).getroot()
    vb = [float(x) for x in root.get('viewBox').split()]
    pivots, shapes = {}, []
    def walk(el, groups):
        for ch in el:
            tag = ch.tag.replace(NS, '')
            if tag == 'g':
                gid = ch.get('id'); g = groups
                if gid:
                    px, py = (float(x) for x in ch.get('data-pivot', '0,0').split(','))
                    pivots[gid] = (px, py); g = groups + [gid]
                walk(ch, g); continue
            if tag not in ('path', 'circle', 'ellipse', 'rect'): continue
            fill = ch.get('fill', '#000'); stroke = ch.get('stroke')
            sw = num(ch, 'stroke-width', 0) if fill == 'none' else 0.0
            c = color(stroke if fill == 'none' else fill)
            op = num(ch, 'fill-opacity', 1.0) * num(ch, 'opacity', 1.0)
            rot = (0.0, 0.0, 0.0)
            t = ch.get('transform')
            if t:
                m = re.match(r'rotate\(([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\)', t)
                if not m: raise SystemExit(f'{path}: unsupported transform {t}')
                rot = tuple(float(x) for x in m.groups())
            if tag == 'path': k, d, n = 0, ch.get('d'), []
            elif tag == 'circle': k, d, n = 1, '', [num(ch,'cx'), num(ch,'cy'), num(ch,'r')]
            elif tag == 'ellipse': k, d, n = 2, '', [num(ch,'cx'), num(ch,'cy'), num(ch,'rx'), num(ch,'ry')]
            else: k, d, n = 3, '', [num(ch,'x'), num(ch,'y'), num(ch,'width'), num(ch,'height'), num(ch,'rx')]
            shapes.append((groups, k, d, n, c, op, sw, rot))
    walk(root, [])
    f = lambda x: repr(float(x))
    out = [f'const RigData {name}Rig = RigData(', f'  width: {f(vb[2])},', f'  height: {f(vb[3])},', '  pivots: {']
    out += [f"    '{k}': Offset({f(x)}, {f(y)})," for k, (x, y) in pivots.items()]
    out += ['  },', '  shapes: [']
    for g, k, d, n, c, op, sw, rot in shapes:
        parts = [f"g: [{', '.join(repr(x) for x in g)}]", f'k: {k}', f'c: 0x{c:08X}']
        if d: parts.append(f"d: '{d}'")
        if n: parts.append(f"n: [{', '.join(f(x) for x in n)}]")
        if op != 1.0: parts.append(f'o: {f(op)}')
        if sw: parts.append(f'sw: {f(sw)}')
        if rot[0]: parts.append(f'rot: [{f(rot[0])}, {f(rot[1])}, {f(rot[2])}]')
        out.append(f"    RigShape({', '.join(parts)}),")
    out += ['  ],', ');', '']
    return '\n'.join(out)

outp = sys.argv[1]
body = ['// GENERATED from the SVG drawings by tools/svg2rig.py — do not edit by hand.',
        '// ignore_for_file: prefer_single_quotes, lines_longer_than_80_chars', '',
        "import 'package:flutter/painting.dart';", "import 'rig.dart';", '']
for a in sys.argv[2:]:
    n, p = a.split('=', 1); body.append(rig(n, p))
open(outp, 'w').write('\n'.join(body))
print('wrote', outp)

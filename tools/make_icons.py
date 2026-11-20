"""Draw the app icons (no dependencies). Usage: python3 tools/make_icons.py"""
import struct, zlib

def inside(x, y):
    """Return an RGB color for a point in unit coordinates, or None for background."""
    # play triangle
    ax, ay, bx, by, cx, cy = 0.36, 0.22, 0.36, 0.58, 0.68, 0.40
    def side(px, py, qx, qy, rx, ry): return (px - rx) * (qy - ry) - (qx - rx) * (py - ry)
    d1, d2, d3 = side(x, y, ax, ay, bx, by), side(x, y, bx, by, cx, cy), side(x, y, cx, cy, ax, ay)
    if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
        return (242, 180, 64)
    # two subtitle bars with rounded ends
    def bar(x0, x1, yc, h):
        r = h / 2
        if x0 + r <= x <= x1 - r and abs(y - yc) <= r: return True
        for ex in (x0 + r, x1 - r):
            if (x - ex) ** 2 + (y - yc) ** 2 <= r * r: return True
        return False
    if bar(0.22, 0.78, 0.71, 0.065): return (238, 240, 245)
    if bar(0.32, 0.68, 0.81, 0.05): return (255, 226, 166)
    return None

def render(size, ss=3):
    rows = []
    for j in range(size):
        row = bytearray([0])
        for i in range(size):
            t = (i + j) / (2 * size)
            bg = (int(24 - 13 * t), int(29 - 16 * t), int(42 - 24 * t))
            acc = [0, 0, 0]
            for sj in range(ss):
                for si in range(ss):
                    c = inside((i + (si + .5) / ss) / size, (j + (sj + .5) / ss) / size) or bg
                    for k in range(3): acc[k] += c[k]
            row += bytes(v // (ss * ss) for v in acc)
        rows.append(bytes(row))
    raw = b''.join(rows)
    def chunk(tag, data): return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')

for n in (180, 512):
    with open(f'icon-{n}.png', 'wb') as f: f.write(render(n))
    print('wrote', f'icon-{n}.png')

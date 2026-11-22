#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Write the placeholder images and documents of the Vellmark fixture.

Vellmark Fastening Supply is a fictional fastener wholesaler; its customers, people, addresses and
numbers are made up, and every domain is under .example. The fixture proves
rewrite-sample-data.py, so its pictures only need to be real files of the formats the storefront
serves: a small PNG per product image (a flat plate in the group's colour with a stripe pattern
whose count is the image's position), three PNG scenes, an SVG wordmark, and a one-page PDF per
document. Standard library only (zlib and struct write the PNG), and byte-identical on every run:

    python tools/sample-data/testdata/vellmark/make-fixture-assets.py
"""
import json
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
GROUP_COLOUR = {'bolts': (0x3A, 0x5A, 0x78), 'screws': (0x4F, 0x7A, 0x5C), 'anchors': (0x8A, 0x5A, 0x2E), 'tools': (0x6B, 0x4A, 0x7A)}


def png(width, height, pixel):
    raw = b''.join(b'\x00' + b''.join(bytes(pixel(x, y)) for x in range(width)) for y in range(height))

    def chunk(tag, payload):
        return struct.pack('>I', len(payload)) + tag + payload + struct.pack('>I', zlib.crc32(tag + payload) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def plate(colour, stripes, size=96):
    light = tuple(min(255, c + 120) for c in colour)

    def pixel(x, y):
        band = size // (2 * stripes + 1)
        if band and (x // band) % 2 == 1 and (x // band) < 2 * stripes + 1 and size // 3 < y < 2 * size // 3:
            return light
        return colour
    return png(size, size, pixel)


def scene(a, b, size=160):
    def pixel(x, y):
        t = (x + y) / (2.0 * size)
        return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))
    return png(size, size // 2, pixel)


def pdf(title, lines):
    text = ['BT /F1 18 Tf 72 720 Td (%s) Tj ET' % title]
    for i, line in enumerate(lines):
        text.append('BT /F1 11 Tf 72 %d Td (%s) Tj ET' % (690 - 16 * i, line))
    stream = '\n'.join(text).encode('latin-1')
    objs = [b'<< /Type /Catalog /Pages 2 0 R >>',
            b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
            b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
            b'<< /Length %d >>\nstream\n' % len(stream) + stream + b'\nendstream',
            b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>']
    out = b'%PDF-1.4\n'
    offsets = []
    for i, o in enumerate(objs):
        offsets.append(len(out))
        out += b'%d 0 obj\n' % (i + 1) + o + b'\nendobj\n'
    xref = len(out)
    out += b'xref\n0 %d\n0000000000 65535 f \n' % (len(objs) + 1)
    for off in offsets:
        out += b'%010d 00000 n \n' % off
    out += b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n' % (len(objs) + 1, xref)
    return out


def write(rel, data):
    path = os.path.join(HERE, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)


def main():
    with open(os.path.join(HERE, 'customer-data.json'), encoding='utf-8') as f:
        data = json.load(f)
    groups = {g['key']: g for g in data['catalogue']['groups']}
    for p in data['catalogue']['products']:
        g = groups[p['group']]
        colour = GROUP_COLOUR.get(g['key']) or GROUP_COLOUR.get(g.get('parent'), (0x55, 0x55, 0x55))
        for i, rel in enumerate(p['images']):
            write(rel, plate(colour, i + 1))
        for d in p.get('documents') or []:
            write(d['path'], pdf(d['name'], [p['name'], 'Vellmark Fastening Supply (fictional test data)']))
    b = data['brandCopy']
    write(b['logo'], ('<svg xmlns="http://www.w3.org/2000/svg" width="220" height="40" viewBox="0 0 220 40">'
                      '<rect width="40" height="40" fill="#3A5A78"/><text x="52" y="28" font-family="Arial" '
                      'font-size="22" fill="#1F2A33">Vellmark</text></svg>\n').encode('ascii'))
    write(b['images']['hero'], scene((0x3A, 0x5A, 0x78), (0xC8, 0xD2, 0xDC)))
    write(b['images']['catalogueBand'], scene((0x8A, 0x5A, 0x2E), (0xE6, 0xD8, 0xC8)))
    write(b['images']['people'], scene((0x4F, 0x7A, 0x5C), (0xDC, 0xE6, 0xDC)))


if __name__ == '__main__':
    main()

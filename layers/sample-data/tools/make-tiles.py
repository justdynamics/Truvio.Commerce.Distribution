#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate the layer's product imagery: one tile and one detail per product.

WHY THIS EXISTS. The layer used to ship twelve concept tiles, one per subgroup,
and hand the same file to all five products in the band. Measured on the
composed host that is seventeen pictures over ninety-six products, five or six
products per picture, and a PLP row of five cards that are visually one card
repeated. No product nominated a second image either, so the hover swap the card
component is configured for had nothing to swap to.

WHAT IT MAKES. Two SVGs per master and, beside each of them, the PNG the
storefront is actually served - 240 per-product files plus the twelve band tiles
in raster, 252 in all:

    tc-tile-<concept>-<nnnn>.svg      the DEFAULT image, authoring source
    tc-tile-<concept>-<nnnn>.png      the DEFAULT image, what the card shows
    tc-detail-<concept>-<nnnn>.svg    the SECOND image, authoring source
    tc-detail-<concept>-<nnnn>.png    the SECOND image, what the hover swaps to
    tc-tile-<concept>.png             the band tile, third slide in the PDP strip

WHY THE PNG EXISTS (Foundry #1171). Dynamicweb's GetImage.ashx decodes with
SixLabors.ImageSharp, and ImageSharp ships NO SVG decoder. The 500 body names the
set it does have:

    SixLabors.ImageSharp.UnknownImageFormatException: Image cannot be loaded.
    Available decoders: Webp, TIFF, GIF, TGA, JPEG, PNG, PBM, BMP

thrown from Dynamicweb.Imaging.Providers.ImageSharpProviders.
ImageSharpImageConverterProvider.ProcessImage - nothing in that list parses XML
vector markup. Measured read-only on the composed host inside one minute: the raw
/Files/... path 200, image/svg+xml, 1209 bytes; the same file through
GetImage.ashx 500 with width=180&format=webp, 500 with width alone, and 500 with
no parameters at all, so it is neither the webp conversion nor a sizing argument;
a PNG through the identical handler 200. One PDP load produced 17 tc-* image
requests and 17 of 17 answered 500, across all three call sites - hero gallery at
width=180, relations strip at width=30, recommendation rail with no width - and
the three hero slides read complete=true, naturalWidth=0, naturalHeight=0, box
126x95. Swift's card and gallery components always route product imagery through
that handler because they need its width and crop arguments, so every tc-* product
image was a broken image behind a correctly-counted img node until the
layer switched to PNG. The SVGs stay as the authoring sources and stay on disk; the
product rows point at the PNGs.

The PNG is not a rasterisation of the SVG - no rasteriser is available here and
adding one would be a dependency this repo does not carry. It is a second drawing
of the SAME per-product differentiators: the two-digit numeral, the pip row whose
COUNT is the position in the band, the corner mark turned per position, the
concept word, the band hue, and the light-on-dark inversion for the detail. A PNG
tile is therefore still traceable to its product, which is the property the
picture has to have.

<nnnn> is the master's own TCPROD index, so a file name traces to a product
without a lookup, and no two products in a band can share a path by accident.

HOW THEY DIFFER, AND WHY THAT WAY. A PLP card paints the tile at 120 px. A
concept word set at 34 px in a 480-unit box arrives there at about eight pixels,
which is why twelve tiles that differ only in their wording read as one tile. The
per-product differentiator therefore has to be geometric and large: a two-digit
numeral that fills a third of the panel, a pip row whose COUNT is the product's
position in its band (one through five), and a turn of the corner mark per
position. The concept word stays, small, for the PDP where there is room to read
it.

The detail image is the same product in the other register - the panel light on a
dark ground, the marks enlarged and re-laid - so a hover reads as a second look
at one product and never as a second product.

SELF-CONTAINED. No <image>, no external font file, no CSS, no script, and on the
raster side no third-party import: zlib and struct write the PNG and a 5x7 bitmap
alphabet draws the glyphs, so a browser paints and the handler decodes with
nothing else fetched, and the tool itself needs nothing installed. Colours are literals rather than tokens, because these are DATA -
what a product row points at - and a theme that recoloured them would be
recolouring the catalogue.

Regenerate with

    python layers/sample-data/tools/make-tiles.py

from the repository root. Output is byte-identical on every run - the PNG carries
no tIME chunk, a fixed filter byte and a pinned deflate configuration - so a
regeneration that changes nothing shows as no diff at all.
"""
import math
import os
import struct
import sys
import zlib

# The twelve subgroups in TCPROD order, five masters each, and the hue each band
# carries. The hues walk the wheel from the brand green so a band tells apart
# from its neighbours at card size, while the ground, the rule and the wordmark
# keep every tile in one family.
BANDS = [
    ('variants',         'VARIANTS',    '#2E7D5B', '#1C4C38', '#E8F1EC'),
    ('stock-delivery',   'STOCK',       '#2C6E7D', '#1A4450', '#E6F0F3'),
    ('units',            'UNITS',       '#35608A', '#1F3A55', '#E7EEF5'),
    ('price-structures', 'PRICING',     '#45558F', '#28325A', '#EAEBF5'),
    ('assortments',      'ASSORTMENTS', '#5B4B8A', '#352B55', '#EDEAF5'),
    ('discounts',        'DISCOUNTS',   '#74458A', '#452855', '#F2E9F5'),
    ('media',            'MEDIA',       '#8A4275', '#552646', '#F5E9F1'),
    ('currencies',       'CURRENCIES',  '#8A4551', '#552930', '#F5EAEC'),
    ('bundles',          'BUNDLES',     '#8A5A38', '#553622', '#F5EEE8'),
    ('contract-pricing', 'CONTRACT',    '#7D6B2C', '#4C401A', '#F3F1E6'),
    ('documents',        'DOCUMENTS',   '#5E7D2C', '#39501A', '#EEF3E6'),
    ('relations',        'RELATIONS',   '#3C7D46', '#24502A', '#E8F3EA'),
]

FONT = 'Inter, Segoe UI, Helvetica, Arial, sans-serif'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   '..', 'files', 'Images', 'TruvioCommerce', 'products')


def pips(count, x, y, step, size, fill, opacity):
    """The band-position counter: `count` marks, left to right."""
    out = []
    for i in range(count):
        out.append('<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" opacity="%s"/>'
                   % (x + i * step, y, size, size, size // 4, fill, opacity))
    return out


def corner(position, cx, cy, r, fill, opacity):
    """The corner mark, turned per band position, so two cards of the same band
    differ in silhouette and not only in their numeral."""
    rot = (position - 1) * 72
    return ('<g transform="translate(%d %d) rotate(%d)">'
            '<path d="M0 -%d L%d 0 L0 %d Z" fill="%s" opacity="%s"/></g>'
            % (cx, cy, rot, r, r, r, fill, opacity))


def svg(aria, title, body):
    head = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 480" width="480" '
            'height="480" role="img" aria-label="%s">\n  <title>%s</title>\n' % (aria, title))
    return head + '\n'.join('  ' + line for line in body) + '\n</svg>\n'


def tile(word, panel, rule, ground, index, position):
    """The default image. Dark panel on a light ground - the catalogue register."""
    n = '%02d' % index
    body = [
        '<rect width="480" height="480" fill="%s"/>' % ground,
        '<rect x="40" y="40" width="400" height="400" rx="16" fill="%s"/>' % panel,
        '<rect x="40" y="40" width="400" height="8" fill="%s"/>' % rule,
        corner(position, 400, 96, 30, ground, '0.30'),
        '<text x="72" y="118" font-family="%s" font-size="22" font-weight="600" '
        'letter-spacing="2.5" fill="%s" opacity="0.85">%s</text>' % (FONT, ground, word),
        '<text x="240" y="300" text-anchor="middle" font-family="%s" font-size="184" '
        'font-weight="700" letter-spacing="-4" fill="#FFFFFF">%s</text>' % (FONT, n),
    ]
    body += pips(position, 72, 340, 34, 22, ground, '0.85')
    body.append('<text x="240" y="412" text-anchor="middle" font-family="%s" font-size="20" '
                'font-weight="700" letter-spacing="6" fill="%s">TRUVIO</text>' % (FONT, ground))
    return svg('Truvio %s %s tile' % (word, n), 'Truvio %s %s' % (word, n), body)


def detail(word, panel, rule, ground, index, position):
    """The second image - what the card swaps to on hover. Light panel on a dark
    ground, marks enlarged: the same product seen closer, never another one."""
    n = '%02d' % index
    body = [
        '<rect width="480" height="480" fill="%s"/>' % rule,
        '<rect x="40" y="40" width="400" height="400" rx="16" fill="%s"/>' % ground,
        '<rect x="40" y="432" width="400" height="8" fill="%s"/>' % panel,
        corner(position, 132, 240, 76, panel, '0.16'),
        corner(position, 348, 240, 76, panel, '0.16'),
        '<text x="240" y="196" text-anchor="middle" font-family="%s" font-size="34" '
        'font-weight="600" letter-spacing="2" fill="%s">%s</text>' % (FONT, panel, word),
        '<text x="240" y="326" text-anchor="middle" font-family="%s" font-size="128" '
        'font-weight="700" letter-spacing="-3" fill="%s" opacity="0.92">%s</text>'
        % (FONT, panel, n),
    ]
    body += pips(position, 168, 362, 34, 22, panel, '0.55')
    body.append('<text x="240" y="418" text-anchor="middle" font-family="%s" font-size="17" '
                'font-weight="700" letter-spacing="5" fill="%s" opacity="0.7">DETAIL</text>'
                % (FONT, panel))
    return svg('Truvio %s %s detail' % (word, n), 'Truvio %s %s detail' % (word, n), body)


# ===========================================================================
# THE RASTER HALF (Foundry #1171)
# ===========================================================================
# Everything below writes PNG. It exists because Dynamicweb's GetImage.ashx
# decodes with SixLabors.ImageSharp, and ImageSharp ships no SVG decoder - it
# carries png/jpeg/gif/bmp/tiff/webp and nothing that parses XML vector markup,
# so Image.Load throws UnknownImageFormatException and the handler answers 500.
# Measured read-only on the composed host: the raw /Files/... path 200, the same
# file through the handler 500, a PNG through the handler 200. Swift's card and
# gallery components always route product imagery through the handler because
# they need the width and crop arguments, so an all-SVG catalogue has no working
# product image anywhere those components render, while every row count is right.
#
# The writer is pure Python - zlib and struct, nothing imported that a wheel
# supplies - because a repo tool that needs an install is a tool that stops
# regenerating. The glyphs come from the 5x7 bitmap alphabet below rather than a
# font file, for the reason the SVGs embed no font: nothing is fetched, and the
# output cannot move when one machine's fonts differ from another's.

FONT5X7 = {
    ' ': ('00000', '00000', '00000', '00000', '00000', '00000', '00000'),
    '-': ('00000', '00000', '00000', '11111', '00000', '00000', '00000'),
    '&': ('01100', '10010', '10010', '01100', '10011', '10010', '01101'),
    '0': ('01110', '10001', '10011', '10101', '11001', '10001', '01110'),
    '1': ('00100', '01100', '00100', '00100', '00100', '00100', '01110'),
    '2': ('01110', '10001', '00001', '00010', '00100', '01000', '11111'),
    '3': ('11111', '00010', '00100', '00010', '00001', '10001', '01110'),
    '4': ('00010', '00110', '01010', '10010', '11111', '00010', '00010'),
    '5': ('11111', '10000', '11110', '00001', '00001', '10001', '01110'),
    '6': ('00110', '01000', '10000', '11110', '10001', '10001', '01110'),
    '7': ('11111', '00001', '00010', '00100', '01000', '01000', '01000'),
    '8': ('01110', '10001', '10001', '01110', '10001', '10001', '01110'),
    '9': ('01110', '10001', '10001', '01111', '00001', '00010', '01100'),
    'A': ('01110', '10001', '10001', '11111', '10001', '10001', '10001'),
    'B': ('11110', '10001', '10001', '11110', '10001', '10001', '11110'),
    'C': ('01111', '10000', '10000', '10000', '10000', '10000', '01111'),
    'D': ('11110', '10001', '10001', '10001', '10001', '10001', '11110'),
    'E': ('11111', '10000', '10000', '11110', '10000', '10000', '11111'),
    'F': ('11111', '10000', '10000', '11110', '10000', '10000', '10000'),
    'G': ('01111', '10000', '10000', '10111', '10001', '10001', '01111'),
    'H': ('10001', '10001', '10001', '11111', '10001', '10001', '10001'),
    'I': ('11111', '00100', '00100', '00100', '00100', '00100', '11111'),
    'J': ('00111', '00010', '00010', '00010', '00010', '10010', '01100'),
    'K': ('10001', '10010', '10100', '11000', '10100', '10010', '10001'),
    'L': ('10000', '10000', '10000', '10000', '10000', '10000', '11111'),
    'M': ('10001', '11011', '10101', '10101', '10001', '10001', '10001'),
    'N': ('10001', '11001', '10101', '10011', '10001', '10001', '10001'),
    'O': ('01110', '10001', '10001', '10001', '10001', '10001', '01110'),
    'P': ('11110', '10001', '10001', '11110', '10000', '10000', '10000'),
    'Q': ('01110', '10001', '10001', '10001', '10101', '10010', '01101'),
    'R': ('11110', '10001', '10001', '11110', '10100', '10010', '10001'),
    'S': ('01111', '10000', '10000', '01110', '00001', '00001', '11110'),
    'T': ('11111', '00100', '00100', '00100', '00100', '00100', '00100'),
    'U': ('10001', '10001', '10001', '10001', '10001', '10001', '01110'),
    'V': ('10001', '10001', '10001', '10001', '10001', '01010', '00100'),
    'W': ('10001', '10001', '10001', '10101', '10101', '11011', '10001'),
    'X': ('10001', '10001', '01010', '00100', '01010', '10001', '10001'),
    'Y': ('10001', '10001', '01010', '00100', '00100', '00100', '00100'),
    'Z': ('11111', '00001', '00010', '00100', '01000', '10000', '11111'),
}

# The twelve band tiles, keyed by concept. They were authored by hand at 1.2.0
# and stay on disk as SVG; only the raster twin is generated, because
# truvio-pdp.sql derives a master's band tile by stripping the index off that
# master's own default image path, and that path is now .png.
CONCEPT_LABELS = {
    'variants': 'VARIANTS',
    'stock-delivery': 'STOCK & DELIVERY',
    'units': 'UNITS & MEASURES',
    'price-structures': 'PRICE STRUCTURES',
    'assortments': 'ASSORTMENTS',
    'discounts': 'DISCOUNTS',
    'media': 'MEDIA & GALLERIES',
    'currencies': 'CURRENCIES & VAT',
    'bundles': 'BUNDLES & BOM',
    'contract-pricing': 'CONTRACT PRICING',
    'documents': 'DOCUMENTS',
    'relations': 'RELATIONS',
}

SIZE = 480


def rgb(hex_colour):
    h = hex_colour.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def mix(fg, bg, alpha):
    """Flatten an opacity against the colour it sits on. The PNG carries no alpha
    channel: a mark the SVG draws at 30 percent over the panel is written here as
    the colour that composite would produce, so the file stays three channels and
    what a card paints behind it can never change the tile."""
    f, b = rgb(fg), rgb(bg)
    return tuple(int(round(f[i] * alpha + b[i] * (1.0 - alpha))) for i in range(3))


class Canvas(object):
    """A 480x480 truecolour buffer. Flat fills only, no antialiasing: an
    antialiased edge is a gradient, and a gradient is what makes flat art
    expensive to deflate. Every picture here is rectangles, triangles and glyph
    cells, which is why each file lands in single-figure kilobytes."""

    def __init__(self, fill):
        self.w = self.h = SIZE
        self.px = bytearray(SIZE * SIZE * 3)
        self.rect(0, 0, SIZE, SIZE, rgb(fill))

    def point(self, x, y, colour):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 3
            self.px[i] = colour[0]
            self.px[i + 1] = colour[1]
            self.px[i + 2] = colour[2]

    def rect(self, x, y, w, h, colour):
        if w <= 0 or h <= 0:
            return
        x0 = max(x, 0)
        x1 = min(x + w, self.w)
        if x1 <= x0:
            return
        row = bytes(colour) * (x1 - x0)
        for yy in range(max(y, 0), min(y + h, self.h)):
            i = (yy * self.w + x0) * 3
            self.px[i:i + len(row)] = row

    def rounded(self, x, y, w, h, r, colour):
        """The panel. The corner inset is measured per row so the shape answers
        the SVG's rx rather than approximating it with a plain rectangle."""
        for yy in range(y, y + h):
            dy = 0
            if yy < y + r:
                dy = r - 1 - (yy - y)
            elif yy >= y + h - r:
                dy = r - 1 - (y + h - 1 - yy)
            inset = 0
            if dy:
                inset = r - int((r * r - dy * dy) ** 0.5)
            self.rect(x + inset, yy, w - 2 * inset, 1, colour)

    def triangle(self, cx, cy, r, turns, colour):
        """The corner mark, turned per band position. The SVG rotates one triangle
        by 72 degrees a step; the same three vertices are rotated here and the
        span filled by an edge test, so the silhouette carries over."""
        ang = math.radians(turns * 72.0)
        pts = []
        for px, py in ((0.0, -float(r)), (float(r), 0.0), (0.0, float(r))):
            pts.append((cx + px * math.cos(ang) - py * math.sin(ang),
                        cy + px * math.sin(ang) + py * math.cos(ang)))
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]

        def side(a, b, p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])

        for yy in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
            for xx in range(int(math.floor(min(xs))), int(math.ceil(max(xs))) + 1):
                p = (xx + 0.5, yy + 0.5)
                d1 = side(pts[0], pts[1], p)
                d2 = side(pts[1], pts[2], p)
                d3 = side(pts[2], pts[0], p)
                neg = d1 < 0 or d2 < 0 or d3 < 0
                pos = d1 > 0 or d2 > 0 or d3 > 0
                if not (neg and pos):
                    self.point(xx, yy, colour)

    def glyph(self, ch, x, y, scale, colour):
        rows = FONT5X7.get(ch, FONT5X7[' '])
        for ry, bits in enumerate(rows):
            for rx, bit in enumerate(bits):
                if bit == '1':
                    self.rect(x + rx * scale, y + ry * scale, scale, scale, colour)

    def measure(self, s, scale, tracking):
        step = (5 + tracking) * scale
        return len(s) * step - tracking * scale

    def text(self, s, x, y, scale, colour, tracking=1):
        step = (5 + tracking) * scale
        for i, ch in enumerate(s):
            self.glyph(ch, x + i * step, y, scale, colour)

    def text_centred(self, s, cx, y, scale, colour, tracking=1):
        self.text(s, int(cx - self.measure(s, scale, tracking) // 2), y, scale, colour, tracking)

    def fit(self, s, width, scale, tracking):
        """Step the glyph scale down until the word fits the space it is given.
        A band label is as long as its band is named, and a word that runs off the
        panel is a word nobody reads."""
        while scale > 1 and self.measure(s, scale, tracking) > width:
            scale -= 1
        return scale

    def png(self):
        """The PNG bytes. No tIME chunk, no text chunk, a fixed filter byte and a
        pinned deflate configuration, so two runs of this script produce the same
        bytes and a regeneration that changed nothing shows as no diff at all."""
        raw = bytearray()
        stride = self.w * 3
        for y in range(self.h):
            raw.append(0)
            raw.extend(self.px[y * stride:(y + 1) * stride])
        comp = zlib.compressobj(9, zlib.DEFLATED, 15, 9, zlib.Z_DEFAULT_STRATEGY)
        data = comp.compress(bytes(raw)) + comp.flush()

        def chunk(tag, payload):
            return (struct.pack('>I', len(payload)) + tag + payload
                    + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF))

        ihdr = struct.pack('>IIBBBBB', self.w, self.h, 8, 2, 0, 0, 0)
        return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
                + chunk(b'IDAT', data) + chunk(b'IEND', b''))


def tile_png(word, panel, rule, ground, index, position):
    """The raster twin of tile(). Same ground, same panel, same rule bar, the same
    two-digit numeral filling a third of the panel, the same pip COUNT and the
    same corner turn - so a PNG on a 120px card still traces to one product."""
    c = Canvas(ground)
    c.rounded(40, 40, 400, 400, 16, rgb(panel))
    c.rect(40, 40, 400, 8, rgb(rule))
    c.triangle(400, 96, 30, position - 1, mix(ground, panel, 0.30))
    c.text(word, 72, 92, c.fit(word, 330, 3, 2), mix(ground, panel, 0.85), tracking=2)
    c.text_centred('%02d' % index, 240, 150, 26, (255, 255, 255), tracking=1)
    pip = mix(ground, panel, 0.85)
    for i in range(position):
        c.rect(72 + i * 34, 340, 22, 22, pip)
    c.text_centred('TRUVIO', 240, 392, 3, rgb(ground), tracking=3)
    return c.png()


def detail_png(word, panel, rule, ground, index, position):
    """The raster twin of detail(). The same product in the other register - light
    panel on the dark ground, the marks enlarged and re-laid - so a hover reads as
    a second look at one product and never as a second product."""
    c = Canvas(rule)
    c.rounded(40, 40, 400, 400, 16, rgb(ground))
    c.rect(40, 432, 400, 8, rgb(panel))
    c.triangle(132, 240, 76, position - 1, mix(panel, ground, 0.16))
    c.triangle(348, 240, 76, position - 1, mix(panel, ground, 0.16))
    scale = c.fit(word, 340, 5, 2)
    c.text_centred(word, 240, 150, scale, rgb(panel), tracking=2)
    c.text_centred('%02d' % index, 240, 226, 18, mix(panel, ground, 0.92), tracking=1)
    pip = mix(panel, ground, 0.55)
    for i in range(position):
        c.rect(168 + i * 34, 362, 22, 22, pip)
    c.text_centred('DETAIL', 240, 400, 3, mix(panel, ground, 0.70), tracking=3)
    return c.png()


def concept_png(label):
    """The band tile - the third picture in every PDP strip. It carries the band
    and nothing per-product, which is what a strip's third slide is for."""
    ground, panel, rule = '#E8F1EC', '#2E7D5B', '#1C4C38'
    c = Canvas(ground)
    c.rounded(40, 40, 400, 400, 16, rgb(panel))
    c.rect(40, 40, 400, 8, rgb(rule))
    scale = c.fit(label, 340, 7, 1)
    c.text_centred(label, 240, 220, scale, (255, 255, 255), tracking=1)
    c.text_centred('TRUVIO', 240, 372, 3, rgb(ground), tracking=3)
    return c.png()


def main():
    out = os.path.normpath(OUT)
    if not os.path.isdir(out):
        sys.stderr.write('make-tiles.py: %s does not exist\n' % out)
        return 1
    written = 0
    largest = 0
    for band, (concept, word, panel, rule, ground) in enumerate(BANDS):
        for position in range(1, 6):
            index = band * 5 + position
            for prefix, maker, raster in (('tc-tile', tile, tile_png),
                                          ('tc-detail', detail, detail_png)):
                name = '%s-%s-%04d.svg' % (prefix, concept, index)
                with open(os.path.join(out, name), 'w', encoding='utf-8', newline='\n') as fh:
                    fh.write(maker(word, panel, rule, ground, index, position))
                written += 1
                blob = raster(word, panel, rule, ground, index, position)
                largest = max(largest, len(blob))
                with open(os.path.join(out, name[:-4] + '.png'), 'wb') as fh:
                    fh.write(blob)
                written += 1
        blob = concept_png(CONCEPT_LABELS[concept])
        largest = max(largest, len(blob))
        with open(os.path.join(out, 'tc-tile-%s.png' % concept), 'wb') as fh:
            fh.write(blob)
        written += 1
    sys.stdout.write('make-tiles.py: %d file(s) written to %s, largest %d bytes\n'
                     % (written, out, largest))
    return 0


if __name__ == '__main__':
    sys.exit(main())

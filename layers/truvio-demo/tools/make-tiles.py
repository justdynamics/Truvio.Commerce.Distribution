#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate the layer's product imagery: one tile and one detail per product.

WHY THIS EXISTS. The layer used to ship twelve concept tiles, one per subgroup,
and hand the same file to all five products in the band. Measured on the
composed host that is seventeen pictures over ninety-six products, five or six
products per picture, and a PLP row of five cards that are visually one card
repeated. No product nominated a second image either, so the hover swap the card
component is configured for had nothing to swap to.

WHAT IT MAKES. Two SVGs per master, 120 files:

    tc-tile-<concept>-<nnnn>.svg      the DEFAULT image - what the card shows
    tc-detail-<concept>-<nnnn>.svg    the SECOND image - what the hover swaps to

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

SELF-CONTAINED. No <image>, no external font file, no CSS, no script: an SVG
Dynamicweb's GetImage.ashx can rasterise and a browser can paint with nothing
else fetched. Colours are literals rather than tokens, because these are DATA -
what a product row points at - and a theme that recoloured them would be
recolouring the catalogue.

Regenerate with

    python layers/truvio-demo/tools/make-tiles.py

from the repository root. Output is byte-identical on every run, so a
regeneration that changes nothing shows as no diff at all.
"""
import os
import sys

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


def main():
    out = os.path.normpath(OUT)
    if not os.path.isdir(out):
        sys.stderr.write('make-tiles.py: %s does not exist\n' % out)
        return 1
    written = 0
    for band, (concept, word, panel, rule, ground) in enumerate(BANDS):
        for position in range(1, 6):
            index = band * 5 + position
            for prefix, maker in (('tc-tile', tile), ('tc-detail', detail)):
                name = '%s-%s-%04d.svg' % (prefix, concept, index)
                with open(os.path.join(out, name), 'w', encoding='utf-8', newline='\n') as fh:
                    fh.write(maker(word, panel, rule, ground, index, position))
                written += 1
    sys.stdout.write('make-tiles.py: %d file(s) written to %s\n' % (written, out))
    return 0


if __name__ == '__main__':
    sys.exit(main())

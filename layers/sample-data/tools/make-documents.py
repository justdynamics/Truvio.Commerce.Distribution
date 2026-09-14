#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate the layer's product documents.

The PDP documents table needs files on disk, not links in prose. These are the
smallest honest thing that can sit in it: a valid one-page PDF per top group,
two per group - a datasheet and an install guide - drawn with the base-14
Helvetica face so nothing is embedded and every file stays around a kilobyte.

They are DATA, like the concept tiles beside them: what a product row points at,
never a style. Regenerate with

    python layers/sample-data/tools/make-documents.py

from the repository root. Output is byte-identical on every run - no dates, no
ids, no producer string - so a regeneration that changes nothing shows as no
diff at all, and the committed files can be trusted to be what this script
makes.
"""
import io
import os
import sys

GROUPS = [
    ('data-models', 'Data Models'),
    ('commerce', 'Commerce'),
    ('content', 'Content'),
    ('users', 'Users'),
]
KINDS = [
    ('datasheet', 'Datasheet',
     ['This datasheet states what the row carries and how it is measured.',
      'Dimensions, net weight, material class and compatibility are listed on',
      'the product page itself, in the specification table; this sheet is the',
      'printable copy of the same values.',
      '',
      'Truvio Commerce demo data. The concept named above is platform',
      'vocabulary, not a real product, and the figures are illustrative.']),
    ('install-guide', 'Install Guide',
     ['This guide covers receiving, checking and fitting the row.',
      '',
      '1  Check the delivery against the order line and the packing quantity.',
      '2  Compare the number on the label with the number on the product page.',
      '3  Keep the datasheet with the record; it carries the revision.',
      '4  Report a shortage inside the return window stated on the page.',
      '',
      'Truvio Commerce demo data. Illustrative, and deliberately generic.']),
]

OUT_DIR = os.path.join('layers', 'sample-data', 'files', 'Documents', 'TruvioCommerce')


def esc(s):
    return s.replace('\\', r'\\').replace('(', r'\(').replace(')', r'\)')


def build_pdf(title, body):
    """A one-page A4 PDF: catalog, pages, page, content stream, one font."""
    lines = ['BT', '/F1 18 Tf', '72 760 Td', '(%s) Tj' % esc(title), 'ET',
             '0.18 0.49 0.36 rg', '72 742 451 3 re f', '0 0 0 rg',
             'BT', '/F1 10 Tf', '72 714 Td', '14 TL']
    for ln in body:
        lines.append('(%s) Tj T*' % esc(ln))
    lines += ['ET', 'BT', '/F1 8 Tf', '72 60 Td', '(Truvio Commerce) Tj', 'ET']
    stream = ('\n'.join(lines) + '\n').encode('latin-1')

    objs = [
        b'<< /Type /Catalog /Pages 2 0 R >>',
        b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        b'/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
        b'<< /Length ' + str(len(stream)).encode('ascii') + b' >>\nstream\n' + stream + b'endstream',
        b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    ]
    out = bytearray(b'%PDF-1.4\n%\xe2\xe3\xcf\xd3\n')
    offsets = []
    for i, body_bytes in enumerate(objs, start=1):
        offsets.append(len(out))
        out += b'%d 0 obj\n' % i + body_bytes + b'\nendobj\n'
    xref_at = len(out)
    out += b'xref\n0 %d\n' % (len(objs) + 1)
    out += b'0000000000 65535 f \n'
    for off in offsets:
        out += b'%010d 00000 n \n' % off
    out += (b'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n'
            % (len(objs) + 1, xref_at))
    return bytes(out)


def main():
    if not os.path.isdir(os.path.join('layers', 'sample-data')):
        sys.exit('run this from the repository root')
    os.makedirs(OUT_DIR, exist_ok=True)
    written = []
    for slug, label in GROUPS:
        for kind_slug, kind_label, body in KINDS:
            title = 'Truvio %s %s' % (label, kind_label)
            data = build_pdf(title, body)
            assert len(data) < 30 * 1024, (title, len(data))
            path = os.path.join(OUT_DIR, 'tc-%s-%s.pdf' % (kind_slug, slug))
            with io.open(path, 'wb') as fh:
                fh.write(data)
            written.append((path, len(data)))
    for path, size in written:
        print('%6d  %s' % (size, path.replace(os.sep, '/')))


if __name__ == '__main__':
    main()

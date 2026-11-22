#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rewrite a copy of the sample-data layer from a customer data file.

WHAT IT DOES. The owner ruling of 2026-09-24 fixes the strategy for a customer demo: copy the
layer, rewrite the YAML, deliver the copy. A demo never delivers the Truvio rows and removes them
afterwards. This script performs that rewrite. It reads the Distribution's own
layers/sample-data (never writes it), reads one customer data file, and writes a complete layer
of kind sample-data into --out:

    python tools/sample-data/rewrite-sample-data.py \
        --input <customer data file> --out <demo>/layers/<customer>-data [--name <layer name>]
        [--dry-run] [--report <file.json>] [--logins stable|input] [--source <sample-data dir>]

The customer data file is one object (`schema: 1`, one key per section); its shape is
customer-data.schema.json beside this script. This script reads catalogue, prices, users.accounts,
history, brandCopy and build.pimShop. The other sections and members belong to build recipes: scripts
outside this repository that write other parts of a demo from the same file. They are accepted,
ignored and listed in the report as owned by a recipe, so one file can feed both. Two members are read
by the generator alone: the buyer's actsFor and a product without images. REWRITE.md beside the layer is the by-hand reference for every table it writes.

    prices.listPrices    the product's own price, restated for the recipes. catalogue.products[]
                         listPrice is what the copy writes; a product named in both carries one
                         amount, or the input is refused.
    prices.customerGroup scopes groupPrices to that account's user group (its users are direct
                         members); absent, groupPrices reach every signed-in customer (1325).
    prices.buyer, history.buyer
                         must name the users.accounts buyer (and its account); with no role buyer
                         they name it.
    history.orderStates  the base order state each history state is written with, by name in the
                         base's default order flow; completed must stay the delivered-order state.
    history.numbering    reported, not written: the layer carries no EcomNumbers table (the base
                         owns it) and a merge row could not change the prefix a blank site holds.
    catalogue.pimFolder  the name of the PIM data-model folder (default: the company name).
    catalogue.shop, history.shop, build.pimShop
                         must be the shops the copy carries (SHOP1, TCSHOP-PIM).

HOW. Every catalogue, price, order and favourite row is rebuilt from the data file, cloned from a
sample row of the same table so each column the platform needs keeps the shape the serializer
captured. The rows that carry a key in REWRITE.md "What must stay stable" keep that key and are
rewritten in place: the personas 100100-100103, 100105 and 100106, TCO-0001 with its first line,
PACK-RMA-0001 and its link 100301, the asset categories, tc_specs, the TCFIELD-* settings, the PIM
shop TCSHOP-PIM and its workspace, the data models TCDM-* and the four product categories. Every
sample row the customer does not use is ABSENT from the copy, not inactive: unused products,
every variant row and axis, the bundle slots, both assortments, the sample price matrix, the
sample orders, quotes, carts and favourites, and the Truvio imagery and documents. Then the four
inventories are rewritten from the tree: merge-manifest.json files[], the predicates in config/
(a table that ends empty loses its predicate, a numeric fence widens to the ids in use),
layer.json fragmentTables, files[], configRows and costHints.expectedRows, and the edition counts
are printed for the demo's edition.

KEYS AND IDS FOR ROWS BEYOND THE SAMPLE'S COUNT.
  products       TCPROD0002..TCPROD0061 in input order, skipping the ids a layer probe names in
                 requiresFixtures (TCPROD0001 by its number TC-VAR-0001, 0003, 0020, 0042, 0046,
                 0052, 0061), then TCPROD1001 upward. Inside the TCPROD% fence.
  groups         TCGRP-<KEY>, the upper-cased input key. Inside the TCGRP-% fence. The first four top
                 groups take the layer's four product categories and data models; a fifth and
                 later top group gets a new category tc_<key>, data model TCDM-<KEY> and completion
                 rule 100164 upward, cloned from the first. A spec field beyond its category's seven
                 field slots gets a new field tc<TopKey><FieldKey> (with its reference_category
                 mirror). New categories and fields carry no storefront facet.
  accounts       the buyer's account 100100; the account the buyer acts for (actsFor or --acts-for),
                 else the next account, 100106; then 100110 upward.
  users          buyer 100101, CSR 100102, account admin 100103, the buyer's second profile 100105
                 (same user name, on the actsFor account; written only when the input names one),
                 every other user 100110 upward after the accounts. The AccessUser and
                 AccessUserGroupRelation fences widen to the highest id.
  prices         TC-PRICE-LIST-<n>, TC-PRICE-Q<qty>-<n>, TC-PRICE-GRP-<n>[-Q<qty>],
                 TC-PRICE-CTR-<n>-A<account>[-Q<qty>]: one key per (account,) product and quantity.
  orders         TCO-0001 is the buyer's first completed order, then TCO-0002 upward; quotes
                 TCO-Q001 upward, carts TCO-C001 upward, lines <order>-<n>.
  favourite list 100401 upward (fence widened); stock unit 100200 + the product number part.
  identities     a row whose key the sample carries keeps the sample's identity value; a new key
                 takes the identity of a dropped sample row of the same table (sorted), then
                 900001 upward. A new uniqueidentifier is uuid5 of table and key, so two runs on
                 the same input write identical trees.

WHAT IT REFUSES, with what to fix: an input that would break a guaranteed row (no buyer, no CSR,
no account admin on the buyer's account, no account named for the buyer's second profile while
the base contract guarantees one, two accounts sharing a customer number, no completed order of
the buyer for TCO-0001 and the return request), an order or favourite list owned by a user the
customer-centre page cannot show it to, a referenced image or document that does not exist, an
SVG product image (GetImage.ashx cannot decode SVG), a currency, country or order state the base
does not ship, two price rows for one rung, a listPrices amount that contradicts the product's
listPrice, a recipe member that contradicts the copy (another buyer, another shop), any input that
would write two rows with one key (the refusal names both input rows), an empty group, and an
--out inside the Distribution's layers/ folder.

Standard library only, like the tools in layers/sample-data/tools/. It lives outside layers/ because every
file under a layer directory is part of the layer tree hash the gate proved.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
BOM = b'\xef\xbb\xbf'
UUID_NS = uuid.UUID('6f1c2a4e-5b0d-4c39-9a7e-2026092400a1')  # fixed: new GUIDs are uuid5(UUID_NS, table/key)
NEW_IDENTITY_BASE = 900000
EXTRA_ACCESSUSER_BASE = 100110
EXTRA_PRODUCT_BASE = 1001
FAVOURITE_LIST_BASE = 100401
STOCK_UNIT_BASE = 100200
HARVEST_DAY_DEFAULT = '2026-09-13'
LANG = 'ENU'
STOREFRONT_SHOP = 'SHOP1'
PERMISSION = {'buyer': 1325, 'user': 1325, 'csr': 1292, 'accountAdmin': 1270}
ORDER_STATE = {'completed': 'OS2', 'open': 'OS1', 'rejected': 'OS3'}
CART_STATE = 'OS5'
IMAGE_EXT = {'.png', '.jpg', '.jpeg', '.webp', '.gif'}
BRAND_IMAGE_EXT = IMAGE_EXT | {'.svg'}
TEXT_TYPES = {'nvarchar', 'varchar', 'nchar', 'char', 'ntext', 'text', 'xml', 'sysname'}
INT_TYPES = {'int', 'bigint', 'smallint', 'tinyint'}
NUM_TYPES = {'float', 'real', 'decimal', 'numeric', 'money', 'smallmoney'}
CONFIG_ROW_VALUE = re.compile(r"^[a-zA-Z0-9 ._-]*$")


class Refused(Exception):
    """The input (or the command line) cannot produce a valid copy. Carries every reason."""

    def __init__(self, reasons):
        super().__init__('\n'.join(reasons))
        self.reasons = list(reasons)


# --------------------------------------------------------------------------- row files

class Meta:
    def __init__(self, text):
        self.keys = _yaml_list(text, 'keyColumns')
        self.identity = _yaml_list(text, 'identityColumns')
        self.columns = _yaml_list(text, 'allColumns')
        self.types = dict(re.findall(r'- "name": "([^"]+)"\r?\n  "dataType": "([^"]+)"', text))


def _yaml_list(text, name):
    m = re.search(r'^"%s":\r?\n((?:- "[^"]*"\r?\n)*)' % re.escape(name), text, re.M)
    return re.findall(r'- "([^"]*)"', m.group(1)) if m else []


def parse_raw(raw):
    if raw == '':
        return None
    if raw.startswith('"'):
        return json.loads(raw)
    if raw in ('true', 'false'):
        return raw == 'true'
    if re.fullmatch(r'-?\d+', raw):
        return int(raw)
    if re.fullmatch(r'-?\d+\.\d+(?:[eE][-+]?\d+)?', raw):
        return float(raw)
    return raw  # dates and GUIDs are written bare


def fmt_number(v):
    f = float(v)
    if f.is_integer():
        return str(int(f))
    return repr(round(f, 6))


class Row:
    __slots__ = ('header', 'cols')

    def __init__(self, header, cols):
        self.header = header          # the two ownership lines, verbatim
        self.cols = cols              # [[name, raw], ...] in file order

    def clone(self):
        return Row(list(self.header), [list(c) for c in self.cols])

    def raw(self, col):
        for c in self.cols:
            if c[0] == col:
                return c[1]
        raise KeyError(col)

    def has(self, col):
        return any(c[0] == col for c in self.cols)

    def get(self, col):
        return parse_raw(self.raw(col))

    def set_raw(self, col, raw):
        for c in self.cols:
            if c[0] == col:
                c[1] = raw
                return
        raise KeyError('column %s not in row' % col)


class Table:
    def __init__(self, name, directory):
        self.name = name
        self.meta = None
        self.meta_bytes = None
        self.rows = {}               # file name -> Row
        self.bom = True
        self.newline = '\r\n'
        self.trailing = True
        meta_path = directory / '_meta.yml'
        if meta_path.is_file():
            self.meta_bytes = meta_path.read_bytes()
            self.meta = Meta(self.meta_bytes.decode('utf-8-sig'))
        for p in sorted(directory.iterdir(), key=lambda q: q.name):
            if p.name == '_meta.yml' or p.suffix != '.yml':
                continue
            data = p.read_bytes()
            self.bom = data.startswith(BOM)
            self.newline = '\r\n' if b'\r\n' in data else '\n'
            text = data.decode('utf-8-sig')
            self.trailing = text.endswith(self.newline)
            lines = text.split(self.newline)
            if self.trailing:
                lines = lines[:-1]
            header, body = lines[:2], lines[2:]
            cols = []
            for line in body:
                m = re.match(r'^"([^"]+)": ?(.*)$', line)
                if not m:
                    raise ValueError('%s: unexpected line %r' % (p, line[:80]))
                cols.append([m.group(1), m.group(2)])
            self.rows[p.name] = Row(header, cols)

    # -- typed values
    def col_type(self, col, row=None):
        if self.meta and col in self.meta.types:
            return self.meta.types[col]
        raw = row.raw(col) if row is not None and row.has(col) else ''
        if raw.startswith('"'):
            return 'nvarchar'
        if raw in ('true', 'false'):
            return 'bit'
        return 'float' if raw else 'nvarchar'

    def fmt(self, col, value, row=None):
        if value is None:
            return ''
        t = self.col_type(col, row)
        if t in TEXT_TYPES:
            return json.dumps(str(value), ensure_ascii=False)
        if t == 'bit':
            return 'true' if value else 'false'
        if t in INT_TYPES:
            return str(int(value))
        if t in NUM_TYPES:
            return fmt_number(value)
        return str(value)

    def set(self, row, col, value):
        row.set_raw(col, self.fmt(col, value, row))

    def key_of(self, row):
        parts = []
        for k in self.meta.keys:
            v = row.get(k)
            if v is None:
                v = ''
            elif isinstance(v, bool):
                v = 'True' if v else 'False'
            elif isinstance(v, float) and v.is_integer():
                v = int(v)
            parts.append(str(v))
        return '$$'.join(parts)

    @staticmethod
    def file_name(key):
        return re.sub(r'[|<>:"/\\?*]', '_', key) + '.yml'

    def file_of(self, row):
        return self.file_name(self.key_of(row))

    def find(self, **where):
        out = []
        for name, row in sorted(self.rows.items()):
            if all(row.get(c) == v for c, v in where.items()):
                out.append(row)
        return out

    def by_file(self, key):
        return self.rows[self.file_name(key)]

    def render(self, row):
        lines = list(row.header) + ['"%s": %s' % (c, r) for c, r in row.cols]
        text = self.newline.join(lines) + (self.newline if self.trailing else '')
        return (BOM if self.bom else b'') + text.encode('utf-8')


def load_tables(layer):
    sql = layer / 'merge' / '_sql'
    tables = {}
    for d in sorted(p for p in sql.iterdir() if p.is_dir()):
        t = Table(d.name, d)
        if t.meta:
            for fname, row in t.rows.items():
                if t.file_of(row) != fname:
                    raise ValueError('%s/%s: the file name does not follow the key rule (computed %s)'
                                     % (d.name, fname, t.file_of(row)))
        tables[d.name] = t
    return tables


# --------------------------------------------------------------------------- input validation

def load_json(path):
    with open(path, encoding='utf-8-sig') as f:
        return json.load(f)


def schema_errors(value, schema, root, path='$'):
    """The JSON Schema subset customer-data.schema.json uses (draft-07 keywords, no network)."""
    if '$ref' in schema:
        ref = schema['$ref']
        node = root
        for part in ref.lstrip('#/').split('/'):
            node = node[part]
        return schema_errors(value, node, root, path)
    errs = []
    types = schema.get('type')
    if types is not None:
        types = types if isinstance(types, list) else [types]
        ok = False
        for t in types:
            if t == 'object' and isinstance(value, dict):
                ok = True
            elif t == 'array' and isinstance(value, list):
                ok = True
            elif t == 'string' and isinstance(value, str):
                ok = True
            elif t == 'integer' and isinstance(value, int) and not isinstance(value, bool):
                ok = True
            elif t == 'number' and isinstance(value, (int, float)) and not isinstance(value, bool):
                ok = True
            elif t == 'boolean' and isinstance(value, bool):
                ok = True
            elif t == 'null' and value is None:
                ok = True
        if not ok:
            return ['%s: expected %s' % (path, '/'.join(types))]
    if 'const' in schema and value != schema['const']:
        errs.append('%s: must be %r' % (path, schema['const']))
    if 'enum' in schema and value not in schema['enum']:
        errs.append('%s: must be one of %s' % (path, ', '.join(map(str, schema['enum']))))
    if isinstance(value, str):
        if len(value) < schema.get('minLength', 0):
            errs.append('%s: must not be empty' % path)
        if 'maxLength' in schema and len(value) > schema['maxLength']:
            errs.append('%s: longer than %d characters' % (path, schema['maxLength']))
        if 'pattern' in schema and not re.search(schema['pattern'], value):
            errs.append('%s: %r does not match %s' % (path, value, schema['pattern']))
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if 'minimum' in schema and value < schema['minimum']:
            errs.append('%s: below the minimum %s' % (path, schema['minimum']))
        if 'exclusiveMinimum' in schema and value <= schema['exclusiveMinimum']:
            errs.append('%s: must be above %s' % (path, schema['exclusiveMinimum']))
    if isinstance(value, list):
        if len(value) < schema.get('minItems', 0):
            errs.append('%s: needs at least %d item(s)' % (path, schema['minItems']))
        if 'maxItems' in schema and len(value) > schema['maxItems']:
            errs.append('%s: at most %d item(s)' % (path, schema['maxItems']))
        if 'items' in schema:
            for i, v in enumerate(value):
                errs += schema_errors(v, schema['items'], root, '%s[%d]' % (path, i))
    if isinstance(value, dict):
        for r in schema.get('required', []):
            if r not in value:
                errs.append('%s: missing %s' % (path, r))
        props = schema.get('properties', {})
        extra = schema.get('additionalProperties', True)
        for k, v in value.items():
            if k in props:
                errs += schema_errors(v, props[k], root, '%s.%s' % (path, k))
            elif extra is False:
                errs.append('%s: unknown property %s' % (path, k))
            elif isinstance(extra, dict):
                errs += schema_errors(v, extra, root, '%s.%s' % (path, k))
    if 'if' in schema and not schema_errors(value, schema['if'], root, path):
        errs += schema_errors(value, schema.get('then', {}), root, path)
    return errs


# --------------------------------------------------------------------------- helpers

def slug_key(s):
    k = re.sub(r'[^A-Za-z0-9]+', '-', s).strip('-').upper()
    return k


def pascal(s):
    return ''.join(w[:1].upper() + w[1:] for w in re.findall(r'[A-Za-z0-9]+', s))


def html_escape(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def replace_inner_html(old, text):
    """Keep the element wrapper of a copy field, swap its text. '<h2 class=x>Old</h2>' -> same tags."""
    m = re.match(r'^((?:<[^/>][^>]*>)+)([^<]*)((?:</[^>]+>)+)$', old)
    if m:
        return m.group(1) + html_escape(text) + m.group(3)
    m = re.match(r'^(<([a-zA-Z0-9]+)[^>]*>)', old)
    if m:
        return m.group(1) + html_escape(text) + '</%s>' % m.group(2)
    return html_escape(text)


def sql_where(where):
    """A row predicate from the WHERE subset the layer's serializer predicates use."""
    def like(v, pat):
        rx = ''
        for tok in re.findall(r'\[_\]|%|_|[^%_\[]+|\[', pat):
            rx += '_' if tok == '[_]' else '.*' if tok == '%' else '.' if tok == '_' else re.escape(tok)
        return v is not None and re.fullmatch(rx, str(v), re.I | re.S) is not None

    def num(v):
        return int(v) if isinstance(v, (int, float)) and not isinstance(v, bool) else None
    expr = where
    expr = re.sub(r"(\w+) LIKE '([^']*)'", lambda m: "like(r.get(%r), %r)" % (m.group(1), m.group(2)), expr)
    expr = re.sub(r"(\w+) IN \(([^)]*)\)", lambda m: "(num(r.get(%r)) in (%s,))" % (m.group(1), m.group(2)), expr)
    expr = re.sub(r"(\w+) (>=|<=) (\d+)", lambda m: "((num(r.get(%r)) or 0) %s %s)" % (m.group(1), m.group(2), m.group(3)), expr)
    expr = re.sub(r"(\w+) = '([^']*)'", lambda m: "(str(r.get(%r)) == %r)" % (m.group(1), m.group(2)), expr)
    expr = re.sub(r"(\w+) = (\d+)\b", lambda m: "(num(r.get(%r)) == %s)" % (m.group(1), m.group(2)), expr)
    expr = re.sub(r'\bAND\b', 'and', re.sub(r'\bOR\b', 'or', expr))
    code = compile(expr, '<where>', 'eval')
    return lambda r: eval(code, {'like': like, 'num': num, 'r': r})


def dt(day, hour):
    return '%sT%02d:%02d:00.0000000' % (day.isoformat(), hour, 0)


def rel_posix(p):
    return str(p).replace('\\', '/')


# --------------------------------------------------------------------------- the generator

class Generator:
    def __init__(self, source, inp, input_dir, name, logins, acts_for=None):
        self.src = source
        self.inp = inp
        self.input_dir = input_dir
        self.name = name
        self.logins = logins
        self.acts_for_cli = acts_for
        self.dist = source.parent.parent if (source.parent / 'layer.schema.json').is_file() else None
        self.reasons = []
        self.warnings = []
        self.ignored = []        # [{'member': path, 'owner': who reads it}]
        self.report = {'layer': name, 'source': {}, 'tables': {}, 'ids': {}, 'removed': [], 'warnings': self.warnings,
                       'ignored': self.ignored}
        self.tables = load_tables(source)
        self.origins = {}        # (table, file name) -> the input row that produced it
        self.out = {}            # table -> {file name: Row}
        self.files = {}          # relative output path -> bytes (everything except row files)
        self.content = {}        # relative path -> text (content documents)

    # ----------------------------------------------------------------- context from the Distribution
    def load_context(self):
        lj = load_json(self.src / 'layer.json')
        self.layer_json = lj
        self.report['source'] = {'layer': lj['name'], 'version': lj['version']}
        self.harvest = date.fromisoformat(HARVEST_DAY_DEFAULT)
        self.currencies = None
        self.countries = None
        self.facets = {}
        self.probe_fixtures = {}     # fixture token -> [layer names]
        self.other_layer_products = {}
        self.guaranteed = {}         # base.contract.json sampleData.guaranteedRows
        self.order_states = None     # order state name -> id, in the base's default order flow
        if not self.dist:
            self.warnings.append('The source layer is not inside a Distribution clone: currency, country, facet, order state and probe checks are skipped.')
            return
        contract_path = self.dist / 'layers' / 'base' / 'base.contract.json'
        if contract_path.is_file():
            c = load_json(contract_path)
            self.guaranteed = (c.get('sampleData') or {}).get('guaranteedRows') or {}
            hd = (self.guaranteed.get('customerCenter') or {}).get('harvestDay')
            if hd:
                self.harvest = date.fromisoformat(hd)
        base_sql = self.dist / 'layers' / 'base' / 'replace' / '_sql'
        if (base_sql / 'EcomOrderStates').is_dir() and (base_sql / 'EcomOrderFlow').is_dir():
            def rows(d):
                # the base's replace rows carry no ownership header: every line is a column
                for p in sorted(d.glob('*.yml')):
                    if p.name != '_meta.yml':
                        yield {m.group(1): parse_raw(m.group(2)) for m in re.finditer(r'^"([^"]+)": ?(.*?)\r?$', p.read_text(encoding='utf-8-sig'), re.M)}
            order_flows = {r.get('OrderFlowId') for r in rows(base_sql / 'EcomOrderFlow') if r.get('OrderFlowOrderType') == 0 and r.get('OrderFlowIsDefault')}
            self.order_states = {}
            for r in sorted(rows(base_sql / 'EcomOrderStates'), key=lambda r: str(r.get('OrderStateId'))):
                if r.get('OrderFlowId') in order_flows and not r.get('OrderStateIsDeleted'):
                    self.order_states.setdefault(r.get('OrderStateName'), r.get('OrderStateId'))
        if (base_sql / 'EcomCurrencies').is_dir():
            self.currencies = sorted({p.name.split('$$')[0] for p in (base_sql / 'EcomCurrencies').glob('*.yml') if p.name != '_meta.yml'})
        if (base_sql / 'EcomCountries').is_dir():
            self.countries = sorted({p.name.split('$$')[0] for p in (base_sql / 'EcomCountries').glob('*.yml') if p.name != '_meta.yml'})
        for idx in sorted((self.dist / 'layers').glob('*/repositories/*/Products.index')):
            for cat, field in re.findall(r'Source="ProductCategory\|([^|"]+)\|([^"]+)"', idx.read_text(encoding='utf-8-sig')):
                self.facets.setdefault(cat, field)
        for lj_path in sorted((self.dist / 'layers').glob('*/layer.json')):
            layer_name = lj_path.parent.name
            if layer_name == self.src.name:
                continue
            doc = load_json(lj_path)
            for tok in self._walk_fixtures(doc):
                self.probe_fixtures.setdefault(tok, [])
                if layer_name not in self.probe_fixtures[tok]:
                    self.probe_fixtures[tok].append(layer_name)
            for p in sorted(lj_path.parent.rglob('*.yml')):
                for tok in set(re.findall(r'TCPROD\d{4}', p.read_text(encoding='utf-8-sig', errors='replace'))):
                    self.other_layer_products.setdefault(tok, set()).add(layer_name)

    def _walk_fixtures(self, node):
        if isinstance(node, dict):
            for k, v in node.items():
                if k == 'requiresFixtures' and isinstance(v, list):
                    for x in v:
                        yield str(x)
                else:
                    yield from self._walk_fixtures(v)
        elif isinstance(node, list):
            for v in node:
                yield from self._walk_fixtures(v)

    # ----------------------------------------------------------------- validation
    def refuse(self, msg):
        self.reasons.append(msg)

    def validate(self):
        schema_path = SCRIPT_DIR / 'customer-data.schema.json'
        schema = load_json(schema_path)
        errs = schema_errors(self.inp, schema, schema)
        for e in errs:
            self.refuse('input does not match customer-data.schema.json: ' + e)
        if errs:
            raise Refused(self.reasons)
        for section in ('catalogue', 'prices', 'users.accounts', 'history', 'brandCopy'):
            if section not in self.inp:
                self.refuse('input has no "%s" section; this generator needs catalogue, prices, users.accounts, history and brandCopy' % section)
        if self.reasons:
            raise Refused(self.reasons)
        self._note_ignored()
        self._validate_shops()
        self._validate_catalogue()
        self._validate_accounts()
        if self.reasons:
            raise Refused(self.reasons)
        self._validate_prices()
        self._validate_history()
        self._validate_brand()
        if self.reasons:
            raise Refused(self.reasons)

    # Members of the recipe input the generator accepts and does not use, and who owns each.
    RECIPE_OWNED = (
        ('build.areaId', 'the recipe runner ({build.*} tokens)'),
        ('build.defaultLanguage', 'the recipe runner ({build.*} tokens)'),
        ('brand', 'the content.design-styles recipe'),
        ('debrand', 'the content.page-seo recipe'),
        ('content.pages', 'the content.pages recipe'),
        ('pim.workflow', 'the pim.workflow recipe'),
        ('checkout', 'a checkout recipe (payment and shipping methods)'),
        ('catalogue.assortmentIds', 'the pim.identifiers recipe (assortments debt); the copy ships no assortment'),
        ('users.accounts.assortmentIds', 'a recipe; the copy ships no assortment'),
        ('users.accounts.groups[].users[].passwordRef', 'the users.accounts recipe (DW_RECIPE_SECRETS); the copy ships no password, the Foundry credential tool sets it'),
        ('prices.buyer.passwordRef', 'the commerce.customer-prices recipe (DW_RECIPE_SECRETS)'),
        ('history.buyer.passwordRef', 'the orders.completed-orders recipe (DW_RECIPE_SECRETS)'),
        ('history.reset', 'the orders.completed-orders recipe; a copy is delivered to a fresh host'),
        ('history.numbering', 'the orders.completed-orders recipe (numbering step); see numbering in this report'),
    )

    def _note_ignored(self):
        sections = sorted((k for k in self.inp if '.' in k), key=len, reverse=True)

        def present(path):
            section = next((s for s in sections if path == s or path.startswith(s + '.')), None)
            if section:
                nodes, rest = [self.inp[section]], path[len(section) + 1:]
            else:
                nodes, rest = [self.inp], path
            for part in filter(None, rest.split('.')):
                nxt = []
                for n in nodes:
                    if isinstance(n, dict) and part.endswith('[]'):
                        nxt += [x for x in n.get(part[:-2]) or []]
                    elif isinstance(n, dict) and part in n:
                        nxt.append(n[part])
                nodes = nxt
            return bool(nodes)
        for path, owner in self.RECIPE_OWNED:
            if present(path):
                self.ignored.append({'member': path, 'owner': owner})

    def _validate_shops(self):
        """The shop ids a recipe names must be the ones the copy carries, or a recipe run against the delivered copy
        would look in another shop."""
        for path, value in (('catalogue.shop', (self.inp['catalogue'] or {}).get('shop')),
                            ('history.shop', (self.inp['history'] or {}).get('shop'))):
            if value is not None and value != STOREFRONT_SHOP:
                self.refuse('%s: %s, but the copy places its groups and orders in the storefront shop %s. Name %s, or the recipes and the copy describe two shops.'
                            % (path, value, STOREFRONT_SHOP, STOREFRONT_SHOP))
        pim = (self.inp.get('build') or {}).get('pimShop')
        pim_id = self.tables['EcomShops'].by_file('TCSHOP-PIM').get('ShopId')
        if pim is not None and pim != pim_id:
            self.refuse('build.pimShop: %s, but the PIM shop the copy carries is %s (a stable key). Name %s.' % (pim, pim_id, pim_id))

    def _asset(self, rel, what, allowed):
        p = (self.input_dir / rel).resolve()
        if not p.is_file():
            self.refuse('%s: file %s does not exist (paths are relative to the input file)' % (what, rel))
            return None
        if p.suffix.lower() not in allowed:
            hint = ' GetImage.ashx decodes with ImageSharp, which has no SVG decoder: supply PNG, JPEG or WebP.' if p.suffix.lower() == '.svg' else ''
            self.refuse('%s: %s has extension %s; allowed %s.%s' % (what, rel, p.suffix, ', '.join(sorted(allowed)), hint))
            return None
        return p

    def _validate_catalogue(self):
        cat = self.inp['catalogue']
        self.groups = cat['groups']
        self.group_by_key = {}
        for g in self.groups:
            if g['key'] in self.group_by_key:
                self.refuse('catalogue.groups: key %s appears twice' % g['key'])
            self.group_by_key[g['key']] = g
        self.tops = [g for g in self.groups if not g.get('parent')]
        for g in self.groups:
            p = g.get('parent')
            if p:
                if p not in self.group_by_key:
                    self.refuse('catalogue.groups %s: parent %s is not a group key' % (g['key'], p))
                elif self.group_by_key[p].get('parent'):
                    self.refuse('catalogue.groups %s: parent %s is itself a subgroup; the storefront tree is two levels (top group, subgroup)' % (g['key'], p))
                if g.get('specFields'):
                    self.refuse('catalogue.groups %s: specFields belong on the top group (one data model and one product category per top group)' % g['key'])
        ids = [slug_key(g['key']) for g in self.groups]
        if len(set(ids)) != len(ids):
            self.refuse('catalogue.groups: two keys give the same group id after upper-casing (TCGRP-<KEY>)')
        self.categories = self._category_slots()
        self.slots = self._plan_slots()
        self.field_map = {}        # (top key, spec key) -> (category, field id, label)
        self.new_fields = {}       # (category, field id) -> (template category, template field id): a field the sample does not carry
        taken_fids = {r.get('FieldId') for r in self.tables['EcomProductCategoryField'].rows.values()}
        for g, slot in zip(self.tops, self.slots):
            fields = g.get('specFields', [])
            keys = [f['key'] for f in fields]
            if len(set(keys)) != len(keys):
                self.refuse('catalogue.groups %s: a spec field key appears twice' % g['key'])
                continue
            facets = [f for f in fields if f.get('facet')]
            if len(facets) > 1:
                self.refuse('catalogue.groups %s: %d spec fields marked facet; the storefront index has one facet field per product category (%s)'
                            % (g['key'], len(facets), slot['facet'] or 'none'))
                continue
            free = [fid for fid in slot['fields'] if fid != slot['facet']]
            facet_free = slot['facet']
            for f in fields:
                if f.get('facet') and facet_free:
                    fid, facet_free = facet_free, None
                elif free:
                    fid = free.pop(0)
                elif facet_free and not facets:
                    fid, facet_free = facet_free, None
                else:
                    # beyond the sample's field slots: a new field in the same category, cloned from its first field
                    fid = 'tc' + pascal(g['key']) + pascal(f['key'])
                    if fid in taken_fids:
                        self.refuse('catalogue.groups %s: spec field %s gives the field id %s, which the layer already uses; rename the key' % (g['key'], f['key'], fid))
                        continue
                    self.new_fields[(slot['category'], fid)] = slot['fieldTemplate']
                taken_fids.add(fid)
                self.field_map[(g['key'], f['key'])] = (slot['category'], fid, f['label'])
            if facets and not slot['facet']:
                self.warnings.append('Top group %s marks spec field %s as facet, but no storefront index names a facet on its product category %s: the field shows in the spec table and offers no facet.'
                                     % (g['key'], facets[0]['key'], slot['category']))
            if fields and not facets and slot['facet']:
                self.warnings.append('Top group %s marks no spec field as facet: the storefront facet on %s|%s stays empty.' % (g['key'], slot['category'], slot['facet']))
        extra_fields = sorted(fid for (_, fid) in self.new_fields)
        if extra_fields:
            self.warnings.append('Spec fields beyond the sample\'s field slots get new fields (%s): they show in the spec table and count for completeness; no storefront index names them.' % ', '.join(extra_fields))
        self.products = cat['products']
        self.product_by_number = {}
        for p in self.products:
            if p['number'] in self.product_by_number:
                self.refuse('catalogue.products: number %s appears twice' % p['number'])
            self.product_by_number[p['number']] = p
            if p['group'] not in self.group_by_key:
                self.refuse('catalogue.products %s: group %s is not a group key' % (p['number'], p['group']))
                continue
            top = self.top_of(p['group'])
            for k in (p.get('specs') or {}):
                if (top['key'], k) not in self.field_map:
                    self.refuse('catalogue.products %s: spec %s is not a specFields key of its top group %s' % (p['number'], k, top['key']))
            for kind, refs in (p.get('related') or {}).items():
                for r in refs:
                    if r == p['number']:
                        self.refuse('catalogue.products %s: related.%s names the product itself' % (p['number'], kind))
        for p in self.products:
            for kind, refs in (p.get('related') or {}).items():
                for r in refs:
                    if r not in self.product_by_number:
                        self.refuse('catalogue.products %s: related.%s names %s, which is not a product number' % (p['number'], kind, r))
        for g in self.groups:
            direct = [p for p in self.products if p['group'] == g['key']]
            below = [p for p in self.products if self.group_by_key.get(p['group'], {}).get('parent') == g['key']]
            if not direct and not below:
                self.refuse('catalogue.groups %s: no product sits in it. An empty group still serves a live PLP reading "0 products"; remove it or give it products.' % g['key'])
        self.assets = {}   # (kind, basename) -> source path
        bare = [p['number'] for p in self.products if not p.get('images')]
        if bare:
            self.warnings.append('Products without images (%s): no default image and no gallery; the storefront shows its placeholder. '
                                 'A recipe that reads the same file requires at least one image per product.' % ', '.join(bare))
        for p in self.products:
            for i, img in enumerate(p.get('images') or []):
                src = self._asset(img, 'catalogue.products %s images[%d]' % (p['number'], i), IMAGE_EXT)
                if src:
                    self._register_asset('products', src, img)
            for i, d in enumerate(p.get('documents') or []):
                src = self._asset(d['path'], 'catalogue.products %s documents[%d]' % (p['number'], i), {'.pdf'})
                if src:
                    self._register_asset('documents', src, d['path'])

    def _register_asset(self, kind, src, rel):
        key = (kind, src.name.lower())
        prev = self.assets.get(key)
        if prev and prev.read_bytes() != src.read_bytes():
            self.refuse('%s %s: two different files share the name %s; file names must be unique per folder in the copy' % (kind, rel, src.name))
        self.assets[key] = src

    def top_of(self, gkey):
        g = self.group_by_key[gkey]
        return self.group_by_key[g['parent']] if g.get('parent') else g

    def _category_slots(self):
        """The product categories in the order of their sample top group, each with its field slots."""
        groups = self.tables['EcomGroups']
        sgr = self.tables['EcomShopGroupRelation']
        fields = self.tables['EcomProductCategoryField']
        slots = []
        for row in groups.find(GroupType=2):
            gid = row.get('GroupId')
            suffix = gid[len('TCDM-'):]
            top = 'TCGRP-' + suffix
            rel = sgr.rows.get(Table.file_name('%s$$%s' % (top, STOREFRONT_SHOP)))
            order = rel.get('ShopGroupRelationsSorting') if rel else 99
            catid = row.get('ProductCategoryId')
            fids = [f.get('FieldId') for f in sorted(fields.find(FieldCategoryId=catid), key=lambda r: (r.get('FieldSortOrder'), r.get('FieldId')))]
            slots.append({'order': order, 'sampleTop': top, 'dataModel': gid, 'category': catid,
                          'rule': str(row.get('GroupCompletionRules') or ''), 'fields': fids,
                          'facet': self.facets.get(catid) if self.facets.get(catid) in fids else None})
        slots.sort(key=lambda s: (s['order'], s['category']))
        for s in slots:
            s['fieldTemplate'] = (s['category'], s['fields'][0])
            s['new'] = False
        return slots

    def _plan_slots(self):
        """One product category and data model per top group: the sample's, in order, then new ones cloned from the
        first. A new category carries no storefront facet (no index in the copy names it)."""
        slots = []
        G = self.tables['EcomGroups']
        taken_groups = {r.get('GroupId') for r in G.rows.values()}
        taken_cats = {r.get('CategoryId') for r in self.tables['EcomProductCategory'].rows.values()}
        rules = [int(r.get('EcomCompletionRuleId')) for r in self.tables['EcomCompletionRules'].rows.values()]
        next_rule = max(rules) + 1
        for i, g in enumerate(self.tops):
            if i < len(self.categories):
                slots.append(self.categories[i])
                continue
            tpl = self.categories[0]
            dm = 'TCDM-' + slug_key(g['key'])
            cat = 'tc_' + re.sub(r'[^a-z0-9]+', '_', g['key'].lower()).strip('_')
            while dm in taken_groups:
                dm += '-MODEL'
            while cat in taken_cats:
                cat += '_x'
            taken_groups.add(dm)
            taken_cats.add(cat)
            slots.append({'order': 99 + i, 'sampleTop': None, 'dataModel': dm, 'category': cat, 'rule': str(next_rule), 'fields': [],
                          'facet': None, 'fieldTemplate': tpl['fieldTemplate'], 'new': True, 'template': tpl})
            next_rule += 1
        if len(self.tops) > len(self.categories):
            self.warnings.append('%d top groups, the sample carries %d product categories: %s get new data models and product categories (%s), '
                                 'cloned from %s. No storefront index names a facet on them.'
                                 % (len(self.tops), len(self.categories), ', '.join(g['key'] for g in self.tops[len(self.categories):]),
                                    ', '.join(s['category'] for s in slots[len(self.categories):]), self.categories[0]['category']))
        return slots

    def _validate_accounts(self):
        ua = self.inp['users.accounts']
        self.accounts = [g for g in ua['groups'] if g['kind'] == 'account']
        self.staff = [g for g in ua['groups'] if g['kind'] == 'staff']
        self.users = []
        seen = set()
        for g in ua['groups']:
            for u in g['users']:
                role = u.get('role') or ('csr' if g['kind'] == 'staff' else 'user')
                if g['kind'] == 'staff' and role != 'csr':
                    self.refuse('users.accounts %s: user %s is in a staff group, so its role is csr (found %s)' % (g['name'], u['userName'], role))
                if g['kind'] == 'account' and role == 'csr':
                    self.refuse('users.accounts %s: user %s has role csr; put the representative in a group of kind staff' % (g['name'], u['userName']))
                if u['userName'] in seen:
                    self.refuse('users.accounts: user name %s appears twice' % u['userName'])
                seen.add(u['userName'])
                self.users.append({'group': g, 'user': u, 'role': role})
        names = [g['name'] for g in ua['groups']]
        for n in sorted({n for n in names if names.count(n) > 1}):
            self.refuse('users.accounts: two groups are named %s; a group is found by its name, so names must be unique' % n)
        for g in self.accounts:
            if not g.get('customerNumber'):
                self.refuse('users.accounts %s: an account needs a customerNumber (contract prices, account favourites and the CSR account list compare it)' % g['name'])
        if self.reasons:
            raise Refused(self.reasons)
        numbers = [g['customerNumber'] for g in self.accounts]
        if len(set(numbers)) != len(numbers):
            self.refuse('users.accounts: two accounts share a customer number. DW tells a login\'s profiles apart by customer number, and contract prices compare it exactly.')
        by_name = {x['user']['userName']: x for x in self.users}
        named = {}   # the buyer as prices.buyer / history.buyer name it
        for path in ('prices', 'history'):
            nb = (self.inp.get(path) or {}).get('buyer')
            if nb:
                named[path + '.buyer'] = nb['userName']
        buyers = [u for u in self.users if u['role'] == 'buyer']
        if not buyers and named:
            first = sorted(named.items())[0]
            x = by_name.get(first[1])
            if x and x['group']['kind'] == 'account' and x['role'] == 'user':
                x['role'] = 'buyer'
                buyers = [x]
        if len(buyers) != 1:
            self.refuse('users.accounts: exactly one user needs role buyer (found %d), or prices.buyer / history.buyer must name a customer user. The buyer becomes AccessUser 100101, the persona every authenticated gate leg signs in as (base.contract.json sampleData.guaranteedRows.buyer).' % len(buyers))
            return
        self.buyer = buyers[0]
        self.account1 = self.buyer['group']
        for path, name in sorted(named.items()):
            if name != self.buyer['user']['userName']:
                self.refuse('%s.userName: %s, but the users.accounts buyer is %s. One file, one buyer: name the same user.' % (path, name, self.buyer['user']['userName']))
        pb = (self.inp.get('prices') or {}).get('buyer')
        if pb and pb['account'] != self.account1['customerNumber']:
            self.refuse('prices.buyer.account: %s, but the buyer %s is a user of %s (%s).' % (pb['account'], self.buyer['user']['userName'], self.account1['name'], self.account1['customerNumber']))
        self._plan_second_profile(by_name)
        admins = [u for u in self.users if u['role'] == 'accountAdmin']
        if not admins:
            self.refuse('users.accounts: no user has role accountAdmin. AccessUser 100103 (guaranteedRows.accountAdmin) is an admin on the buyer\'s account; give one user of %s that role.' % self.account1['name'])
        elif admins[0]['group'] is not self.account1:
            self.refuse('users.accounts: the first accountAdmin (%s) is not on the buyer\'s account %s. AccessUser 100103 carries the buyer\'s customer number; list an admin of %s first.'
                        % (admins[0]['user']['userName'], self.account1['name'], self.account1['name']))
        csrs = [u for u in self.users if u['role'] == 'csr']
        if not csrs:
            self.refuse('users.accounts: no group of kind staff with a user. AccessUser 100102 (guaranteedRows.csr) is the customer service representative; add one.')
        for imp in ua.get('impersonation') or []:
            names = {x['user']['userName']: x for x in self.users}
            a, c = names.get(imp['impersonator']), names.get(imp['customer'])
            if not a or not c:
                self.refuse('users.accounts.impersonation: %s -> %s names a user that is not in groups' % (imp['impersonator'], imp['customer']))
            elif a['role'] != 'csr':
                self.refuse('users.accounts.impersonation: %s is not a staff user; impersonation is granted to the CSR group 1292' % imp['impersonator'])
        if self.countries:
            for g in ua['groups']:
                cc = (g.get('address') or {}).get('countryCode')
                if cc and cc not in self.countries:
                    self.refuse('users.accounts %s: country code %s is not an EcomCountries row the base ships' % (g['name'], cc))

    def _plan_second_profile(self, by_name):
        """The buyer's second profile (Switch account) goes on the account the input says the buyer may act for, never
        on an account the generator picks. Written when named; when not named, refused only if the base contract
        guarantees the row (sampleData.guaranteedRows.buyerProfiles)."""
        self.profile_account = None
        named = []
        for x in self.users:
            af = x['user'].get('actsFor')
            if af and x is not self.buyer:
                self.refuse('users.accounts %s: user %s carries actsFor; only the buyer gets a second profile (the layer carries one Switch account profile, the buyer\'s)'
                            % (x['group']['name'], x['user']['userName']))
            elif af:
                named.append(('users.accounts buyer actsFor', af[0]))
        if self.acts_for_cli:
            named.append(('--acts-for', self.acts_for_cli))
        if len({v for _, v in named}) > 1:
            self.refuse('%s disagree (%s); name one account the buyer may act for' % (' and '.join(k for k, _ in named), ', '.join(v for _, v in named)))
            return
        guaranteed = self.guaranteed.get('buyerProfiles')
        if not named:
            if guaranteed:
                others = ', '.join('%s (%s)' % (g['name'], g['customerNumber']) for g in self.accounts if g is not self.account1) or 'none: add a second account'
                self.refuse('the buyer %s names no other account to act for. The base contract guarantees the buyer a second profile on a second account '
                            '(base.contract.json sampleData.guaranteedRows.buyerProfiles: Swift Switch account), and the generator no longer picks that '
                            'account itself. Add actsFor: ["<customerNumber>"] to the buyer, or pass --acts-for <customerNumber> when the file must '
                            'stay free of generator-only members. Accounts: %s.' % (self.buyer['user']['userName'], others))
            return
        cn = named[0][1]
        acct = next((g for g in self.accounts if g['customerNumber'] == cn), None)
        if acct is None:
            self.refuse('%s: %s is not the customerNumber of an account in users.accounts' % (named[0][0], cn))
        elif acct is self.account1:
            self.refuse('%s: %s is the buyer\'s own account; name another account the buyer may act for' % (named[0][0], cn))
        else:
            self.profile_account = acct

    def logins_input(self):
        return self.logins == 'input'

    def _validate_prices(self):
        pr = self.inp['prices']
        cur = pr.get('currency', 'USD')
        if self.currencies is not None and cur not in self.currencies:
            self.refuse('prices.currency: %s is not an EcomCurrencies row the base ships (%s)' % (cur, ', '.join(self.currencies)))
        if cur != 'USD':
            self.warnings.append('Currency %s: every EcomPrices and EcomOrders row is %s. The surface-swift area serves USD; set the area currency to %s in the demo edition, or the dashboard spending widgets print "-".' % (cur, cur, cur))
        self.currency = cur
        numbers = {g['customerNumber'] for g in self.accounts}
        for section in ('tiers', 'groupPrices', 'contracts'):
            seen = {}
            for i, p in enumerate(pr.get(section) or []):
                if p['product'] not in self.product_by_number:
                    self.refuse('prices.%s[%d]: product %s is not a catalogue product number' % (section, i, p['product']))
                if section == 'contracts' and p['account'] not in numbers:
                    self.refuse('prices.contracts[%d]: account %s is not the customerNumber of an account' % (i, p['account']))
                # one price row per (account,) product and quantity: a second row for the same rung is a contradiction
                key = (p.get('account'), p['product'], p.get('quantity', 1))
                if key in seen:
                    self.refuse('prices.%s[%d] and prices.%s[%d]: both price %s%s at quantity %d; one row per rung'
                                % (section, seen[key], section, i, p['product'], ' for account %s' % p['account'] if p.get('account') else '', key[2]))
                seen.setdefault(key, i)
        # listPrices restates the product's own price for the recipes. catalogue.products[].listPrice is what the copy
        # writes (ProductPrice and the list price row); a product named in both carries one amount.
        named = {}
        for i, lp in enumerate(pr.get('listPrices') or []):
            p = self.product_by_number.get(lp['product'])
            if lp['product'] in named:
                self.refuse('prices.listPrices[%d] and prices.listPrices[%d]: both name product %s' % (named[lp['product']], i, lp['product']))
                continue
            named[lp['product']] = i
            if not p:
                self.refuse('prices.listPrices[%d]: product %s is not a catalogue product number' % (i, lp['product']))
            elif abs(float(lp['amount']) - float(p['listPrice'])) > 1e-9:
                self.refuse('prices.listPrices[%d]: product %s at %s, but catalogue.products %s has listPrice %s. Both are the product\'s own price; make them equal.'
                            % (i, lp['product'], fmt_number(lp['amount']), lp['product'], fmt_number(p['listPrice'])))
        if pr.get('listPrices') is not None:
            unnamed = sorted({p['product'] for s in ('tiers', 'groupPrices', 'contracts') for p in pr.get(s) or []} - set(named))
            if unnamed:
                self.warnings.append('prices.listPrices does not name %s, which other price rows name; the commerce.customer-prices recipe expects every priced product in it.' % ', '.join(unnamed))
        # groupPrices reach one user group: customerGroup when named (an account of users.accounts), else every signed-in customer
        self.price_group = None
        cg = pr.get('customerGroup')
        if cg is not None:
            acct = next((g for g in self.accounts if g['name'] == cg), None)
            if acct is None:
                self.refuse('prices.customerGroup: %s is not an account in users.accounts. The copy scopes group prices to an account\'s user group (its users are direct members), '
                            'or, without customerGroup, to every signed-in customer.' % cg)
            else:
                self.price_group = acct
                if pr.get('buyer') and acct is not self.account1:
                    self.refuse('prices.buyer: %s is not a direct member of prices.customerGroup %s (it is a user of %s)' % (pr['buyer']['userName'], cg, self.account1['name']))

    def _validate_history(self):
        h = self.inp['history']
        by_name = {u['user']['userName']: u for u in self.users}
        buyer_name = self.buyer['user']['userName'] if hasattr(self, 'buyer') else None
        first_completed = None
        for section in ('orders', 'quotes', 'carts'):
            for i, o in enumerate(h.get(section) or []):
                owner = by_name.get(o.get('user', buyer_name))
                if not owner:
                    self.refuse('history.%s[%d]: user %s is not in users.accounts' % (section, i, o.get('user')))
                    continue
                if owner['role'] not in ('buyer', 'user'):
                    self.refuse('history.%s[%d]: owned by %s (%s). The customer-centre page grants group 1325 and the My orders scope only, so a CSR or account-admin order is invisible to every persona; give it to a customer user.'
                                % (section, i, owner['user']['userName'], owner['role']))
                for j, line in enumerate(o['lines']):
                    if line['product'] not in self.product_by_number:
                        self.refuse('history.%s[%d].lines[%d]: product %s is not a catalogue product number' % (section, i, j, line['product']))
                if section == 'orders' and o['state'] == 'completed' and owner is self.buyer and first_completed is None:
                    first_completed = i
        self.first_completed = first_completed
        if first_completed is None:
            self.refuse('history.orders: no completed order of the buyer. TCO-0001 is the buyer\'s delivered order the My returns page and the return request PACK-RMA-0001 bind to (guaranteedRows.deliveredOrder); add one.')
        for i, f in enumerate(h.get('favourites') or []):
            owner = by_name.get(f.get('user', buyer_name))
            if not owner:
                self.refuse('history.favourites[%d]: user %s is not in users.accounts' % (i, f.get('user')))
            elif owner['role'] not in ('buyer', 'user'):
                self.refuse('history.favourites[%d]: owned by %s (%s); a favourite list belongs to a customer user' % (i, owner['user']['userName'], owner['role']))
            for p in f['products']:
                if p not in self.product_by_number:
                    self.refuse('history.favourites[%d]: product %s is not a catalogue product number' % (i, p))
        if not any(q['state'] == 'QuotePending' for q in h.get('quotes') or []) and h.get('quotes'):
            self.warnings.append('No quote is QuotePending: the dashboard Pending quotes widget stays empty.')
        # history.orderStates names the order state each history state is set to; the copy writes the base's state id
        self.state_ids = dict(ORDER_STATE)
        seen = set()
        for i, s in enumerate(h.get('orderStates') or []):
            if s['state'] in seen:
                self.refuse('history.orderStates[%d]: state %s is mapped twice' % (i, s['state']))
                continue
            seen.add(s['state'])
            if self.order_states is None:
                self.warnings.append('history.orderStates[%d] (%s: %s) is not checked: no base order flow beside the source layer; the copy keeps %s.'
                                     % (i, s['state'], s['name'], ORDER_STATE[s['state']]))
                continue
            sid = self.order_states.get(s['name'])
            if sid is None:
                self.refuse('history.orderStates[%d]: %s is not an order state of the base\'s order flow (%s). The copy delivers no order state; name one the base ships.'
                            % (i, s['name'], ', '.join(sorted(self.order_states))))
                continue
            self.state_ids[s['state']] = sid
        delivered = (self.guaranteed.get('deliveredOrder') or {}).get('orderStateId')
        if delivered and self.state_ids['completed'] != delivered:
            self.refuse('history.orderStates: completed maps to %s, but the buyer\'s delivered order TCO-0001 is guaranteed in state %s (base.contract.json sampleData.guaranteedRows.deliveredOrder); map completed to that state.'
                        % (self.state_ids['completed'], delivered))
        if len(set(self.state_ids.values())) != len(self.state_ids):
            self.refuse('history.orderStates: two history states map to one order state (%s)' % ', '.join('%s: %s' % kv for kv in sorted(self.state_ids.items())))
        num = h.get('numbering')
        if num is not None:
            self.report['numbering'] = {
                'input': num, 'written': False,
                'why': ('The order number series is the EcomNumbers ORDER row. The sample-data layer carries no EcomNumbers table (the base owns that table '
                        'and raises only its own counters), and a merge row fills only unset columns, so it could not change the prefix the blank '
                        'site already holds (ORDER). The copy\'s own orders keep their stable TCO-* keys inside the layer\'s fence. Apply the series '
                        'after delivery with the orders.completed-orders recipe numbering step; orders placed after that take the prefix.')}

    def _validate_brand(self):
        b = self.inp['brandCopy']
        self.company = b['companyName']
        self.short = b.get('shortName') or self.company.split()[0]
        if not re.fullmatch(r'[A-Za-z0-9 ]+', self.short):
            self.refuse('brandCopy.shortName %r: letters, digits and spaces only. The PIM shop is named "<shortName> PIM" and the index field DATAMODEL_<name> is derived from it.' % self.short)
        self.asset_folder = b.get('assetFolder') or pascal(self.company)
        self.brand_assets = {}
        self.brand_assets['logo'] = self._asset(b['logo'], 'brandCopy.logo', BRAND_IMAGE_EXT)
        self.brand_assets['logoFooter'] = self._asset(b.get('logoFooter') or b['logo'], 'brandCopy.logoFooter', BRAND_IMAGE_EXT)
        imgs = b['images']
        for k in ('hero', 'catalogueBand', 'people'):
            self.brand_assets[k] = self._asset(imgs[k], 'brandCopy.images.' + k, IMAGE_EXT)
        self.brand_assets['portal'] = self._asset(imgs.get('portal') or imgs['hero'], 'brandCopy.images.portal', IMAGE_EXT)

    # ----------------------------------------------------------------- id plans
    def plan(self):
        self.gid = {g['key']: 'TCGRP-' + slug_key(g['key']) for g in self.groups}
        self.top_slot = {g['key']: s for g, s in zip(self.tops, self.slots)}
        # products
        probe_ids = set()
        products = self.tables['EcomProducts']
        number_to_id = {r.get('ProductNumber'): r.get('ProductId') for r in products.rows.values()}
        for tok in self.probe_fixtures:
            if re.fullmatch(r'TCPROD\d{4}', tok):
                probe_ids.add(tok)
            elif tok in number_to_id:
                probe_ids.add(number_to_id[tok])
        masters = sorted({r.get('ProductId') for r in products.rows.values()})
        slots = [m for m in masters if m not in probe_ids]
        self.pid = {}
        extra = EXTRA_PRODUCT_BASE
        for i, p in enumerate(self.products):
            if i < len(slots):
                self.pid[p['number']] = slots[i]
            else:
                self.pid[p['number']] = 'TCPROD%04d' % extra
                extra += 1
        self.report['ids']['products'] = {n: self.pid[n] for n in sorted(self.pid)}
        self.report['ids']['probeSlotsSkipped'] = sorted(probe_ids)
        # accounts and users
        self.uid = {}
        # 100100 the buyer's account; 100106 the account of the buyer's second profile, else the next account
        second = self.profile_account or next((g for g in self.accounts if g is not self.account1), None)
        self.account_id = {self.account1['name']: 100100}
        if second:
            self.account_id[second['name']] = 100106
        nxt = EXTRA_ACCESSUSER_BASE
        for g in self.accounts:
            if g['name'] not in self.account_id:
                self.account_id[g['name']] = nxt
                nxt += 1
        first_admin = next(u for u in self.users if u['role'] == 'accountAdmin')
        first_csr = next(u for u in self.users if u['role'] == 'csr')
        for u in self.users:
            if u is self.buyer:
                self.uid[u['user']['userName']] = 100101
            elif u is first_csr:
                self.uid[u['user']['userName']] = 100102
            elif u is first_admin:
                self.uid[u['user']['userName']] = 100103
        for u in self.users:
            if u['user']['userName'] not in self.uid:
                self.uid[u['user']['userName']] = nxt
                nxt += 1
        self.report['ids']['accounts'] = {k: v for k, v in sorted(self.account_id.items(), key=lambda kv: kv[1])}
        self.report['ids']['users'] = {k: v for k, v in sorted(self.uid.items(), key=lambda kv: kv[1])}
        self.report['ids']['buyerSecondProfile'] = ({'id': 100105, 'account': self.profile_account['name']} if self.profile_account
                                                    else None)
        self.report['ids']['groups'] = dict(sorted(self.gid.items()))
        self.report['ids']['categories'] = {g['key']: self.top_slot[g['key']]['category'] for g in self.tops}

    # ----------------------------------------------------------------- row building
    def new_rows(self, table):
        self.out.setdefault(table, {})
        return self.out[table]

    def add(self, table, row, origin=None):
        """Add a row. Two rows with one key are a clean refusal naming the input rows that produced them."""
        t = self.tables[table]
        name = t.file_of(row)
        rows = self.new_rows(table)
        if name in rows:
            first = self.origins.get((table, name))
            self.refuse('%s: %s and %s both produce the row %s; one of them repeats the other. Remove the repeat.'
                        % (table, first or 'a row the layer keeps', origin or 'a generated row', name[:-len('.yml')]))
            return
        rows[name] = row
        self.origins[(table, name)] = origin

    def tmpl(self, table, key):
        return self.tables[table].by_file(key).clone()

    def keep(self, table, row):
        self.add(table, row.clone())

    def build(self):
        self.build_groups()
        self.build_products()
        self.build_specs()
        self.build_prices()
        self.build_users()
        self.build_history()
        self.build_pim()
        self.build_kept()
        self.assign_identities()

    # groups --------------------------------------------------------------
    def build_groups(self):
        T = self.tables['EcomGroups']
        top_t = self.tmpl('EcomGroups', 'TCGRP-COMMERCE$$ENU')
        sub_t = self.tmpl('EcomGroups', 'TCGRP-VARIANTS$$ENU')
        sgr_t = self.tmpl('EcomShopGroupRelation', 'TCGRP-VARIANTS$$SHOP1')
        gr_t = self.tmpl('EcomGroupRelations', 'TCGRP-VARIANTS$$TCGRP-PRODUCT-STRUCTURE')
        SGR = self.tables['EcomShopGroupRelation']
        GR = self.tables['EcomGroupRelations']
        for i, g in enumerate(self.tops):
            r = top_t.clone()
            for c, v in (('GroupId', self.gid[g['key']]), ('GroupName', g['name']), ('GroupNumber', self.gid[g['key']]),
                         ('GroupDescription', g.get('description'))):
                T.set(r, c, v)
            self.add('EcomGroups', r)
            s = sgr_t.clone()
            SGR.set(s, 'ShopGroupGroupId', self.gid[g['key']])
            SGR.set(s, 'ShopGroupRelationsSorting', i + 1)
            self.add('EcomShopGroupRelation', s)
            for j, sg in enumerate([x for x in self.groups if x.get('parent') == g['key']]):
                r = sub_t.clone()
                for c, v in (('GroupId', self.gid[sg['key']]), ('GroupName', sg['name']), ('GroupNumber', self.gid[sg['key']]),
                             ('GroupDescription', sg.get('description'))):
                    T.set(r, c, v)
                self.add('EcomGroups', r)
                s = sgr_t.clone()
                SGR.set(s, 'ShopGroupGroupId', self.gid[sg['key']])
                SGR.set(s, 'ShopGroupRelationsSorting', 0)
                self.add('EcomShopGroupRelation', s)
                rel = gr_t.clone()
                GR.set(rel, 'GroupRelationsGroupId', self.gid[sg['key']])
                GR.set(rel, 'GroupRelationsParentId', self.gid[g['key']])
                GR.set(rel, 'GroupRelationsSorting', j + 1)
                self.add('EcomGroupRelations', rel)

    # products ------------------------------------------------------------
    def image_path(self, src):
        return '/Files/Images/%s/products/%s' % (self.asset_folder, src.name)

    def doc_path(self, src):
        return '/Files/Documents/%s/%s' % (self.asset_folder, src.name)

    def build_products(self):
        P = self.tables['EcomProducts']
        tp = self.tmpl('EcomProducts', 'TCPROD0007$$ENU$$')
        GPR = self.tables['EcomGroupProductRelation']
        gpr_t = self.tmpl('EcomGroupProductRelation', 'TCGRP-STOCK-DELIVERY$$TCPROD0007')
        D = self.tables['EcomDetails']
        det = {k: self.tmpl('EcomDetails', k) for k in ('TC-DETAIL-TCPROD0006', 'TC-HOVER-TCPROD0006', 'TC-GAL-TCPROD0006-2', 'TC-DOC-TCPROD0006-DS')}
        S = self.tables['EcomStockUnit']
        st_t = self.tmpl('EcomStockUnit', '100201')
        R = self.tables['EcomProductsRelated']
        rel_t = self.tmpl('EcomProductsRelated', 'TCREL-ACCESSORIES$$TCPROD0001$$TCPROD0011$$')
        rel_groups = {g.get('RelatedGroupId')[len('TCREL-'):].lower(): g.get('RelatedGroupId') for g in self.tables['EcomProductsRelatedGroups'].rows.values()}
        self.rel_used = set()
        sort_in = {}
        for p in self.products:
            pid = self.pid[p['number']]
            imgs = [(self.input_dir / i).resolve() for i in p.get('images') or []]
            first = self.image_path(imgs[0]) if imgs else None
            r = tp.clone()
            for c, v in (('ProductId', pid), ('ProductNumber', p['number']), ('ProductName', p['name']),
                         ('ProductShortDescription', p.get('short')), ('ProductLongDescription', p.get('long')),
                         ('ProductMetaTitle', p.get('metaTitle')), ('ProductMetaDescription', p.get('metaDescription')),
                         ('ProductImageSmall', first), ('ProductImageMedium', first), ('ProductImageLarge', first),
                         ('ProductPrice', p['listPrice']), ('ProductStock', p.get('stock', 0)),
                         ('ProductEAN', p.get('ean')), ('ProductWeight', p.get('weight', 0))):
                P.set(r, c, v)
            self.add('EcomProducts', r, 'catalogue.products %s' % p['number'])
            # group relations: primary to its own group, a second to its top group, one to its data model
            own = p['group']
            top = self.top_of(own)['key']
            homes = [(self.gid[own], True)]
            if own != top:
                homes.append((self.gid[top], False))
            homes.append((self.top_slot[top]['dataModel'], False))
            for gid, primary in homes:
                sort_in[gid] = sort_in.get(gid, 0) + 1
                g = gpr_t.clone()
                GPR.set(g, 'GroupProductRelationGroupId', gid)
                GPR.set(g, 'GroupProductRelationProductId', pid)
                GPR.set(g, 'GroupProductRelationSorting', sort_in[gid])
                GPR.set(g, 'GroupProductRelationIsPrimary', primary)
                self.add('EcomGroupProductRelation', g)
            # images: default, hover, then gallery; documents under Manuals
            for k, src in enumerate(imgs):
                if k == 0:
                    d, did = det['TC-DETAIL-TCPROD0006'].clone(), 'TC-DETAIL-' + pid
                elif k == 1:
                    d, did = det['TC-HOVER-TCPROD0006'].clone(), 'TC-HOVER-' + pid
                else:
                    d, did = det['TC-GAL-TCPROD0006-2'].clone(), 'TC-GAL-%s-%d' % (pid, k)
                for c, v in (('DetailId', did), ('DetailProductId', pid), ('DetailValue', self.image_path(src)),
                             ('DetailSortOrder', k), ('DetailsName', p['name'])):
                    D.set(d, c, v)
                self.add('EcomDetails', d)
            for k, doc in enumerate(p.get('documents') or []):
                src = (self.input_dir / doc['path']).resolve()
                d = det['TC-DOC-TCPROD0006-DS'].clone()
                for c, v in (('DetailId', 'TC-DOC-%s-%d' % (pid, k + 1)), ('DetailProductId', pid), ('DetailValue', self.doc_path(src)),
                             ('DetailSortOrder', k + 1), ('DetailsName', doc['name'])):
                    D.set(d, c, v)
                self.add('EcomDetails', d)
            s = st_t.clone()
            num = int(pid[len('TCPROD'):])
            for c, v in (('Id', STOCK_UNIT_BASE + num), ('StockUnitProductId', pid), ('StockUnitQuantity', p.get('stock', 0)),
                         ('StockUnitProductNumber', p['number'])):
                S.set(s, c, v)
            self.add('EcomStockUnit', s)
            for kind, refs in sorted((p.get('related') or {}).items()):
                rg = rel_groups.get(kind)
                if not rg:
                    self.refuse('catalogue.products %s: related.%s has no relation group in the layer (%s)' % (p['number'], kind, ', '.join(sorted(rel_groups))))
                    continue
                self.rel_used.add(rg)
                for k, ref in enumerate(refs):
                    x = rel_t.clone()
                    for c, v in (('ProductRelatedGroupId', rg), ('ProductRelatedProductId', pid), ('ProductRelatedProductRelId', self.pid[ref]),
                                 ('ProductRelatedSortOrder', k + 1)):
                        R.set(x, c, v)
                    self.add('EcomProductsRelated', x, 'catalogue.products %s related.%s[%d]' % (p['number'], kind, k))
        if self.reasons:
            raise Refused(self.reasons)
        for g in self.tables['EcomProductsRelatedGroups'].rows.values():
            if g.get('RelatedGroupId') in self.rel_used:
                self.keep('EcomProductsRelatedGroups', g)

    # spec fields, categories, data models ----------------------------------
    def build_specs(self):
        used_slots = [self.top_slot[g['key']] for g in self.tops]
        used_cats = {s['category'] for s in used_slots}
        used_fields = {}
        for (top, fkey), (cat, fid, label) in self.field_map.items():
            used_fields[(cat, fid)] = label
        CF = self.tables['EcomProductCategoryField']
        CFT = self.tables['EcomProductCategoryFieldTranslation']
        for fname, row in sorted(CF.rows.items()):
            cat, fid = row.get('FieldCategoryId'), row.get('FieldId')
            key = (cat, fid)
            if cat == 'reference_category':
                key = next(((c, f) for (c, f) in used_fields if f == fid), None)
            if key in used_fields:
                r = row.clone()
                CF.set(r, 'FieldType', 1)  # every customer spec value is text
                self.add('EcomProductCategoryField', r)
        for fname, row in sorted(CFT.rows.items()):
            cat, fid = row.get('FieldTranslationFieldCategoryId'), row.get('FieldTranslationFieldId')
            key = (cat, fid) if cat != 'reference_category' else next(((c, f) for (c, f) in used_fields if f == fid), None)
            if key in used_fields:
                r = row.clone()
                CFT.set(r, 'FieldTranslationFieldLabel', used_fields[key])
                self.add('EcomProductCategoryFieldTranslation', r)
        for row in self.tables['EcomProductCategory'].rows.values():
            if row.get('CategoryId') in used_cats:
                self.keep('EcomProductCategory', row)
        CT = self.tables['EcomProductCategoryTranslation']
        for row in CT.rows.values():
            cat = row.get('CategoryTranslationCategoryId')
            if cat in used_cats:
                r = row.clone()
                top = next(g for g in self.tops if self.top_slot[g['key']]['category'] == cat)
                CT.set(r, 'CategoryTranslationCategoryName', top['name'])
                self.add('EcomProductCategoryTranslation', r)
        # product categories and fields beyond the sample's slots, cloned from a sample category and field
        for g in self.tops:
            slot = self.top_slot[g['key']]
            if not slot['new']:
                continue
            tcat = slot['template']['category']
            r = self.tmpl('EcomProductCategory', tcat)
            self.tables['EcomProductCategory'].set(r, 'CategoryId', slot['category'])
            self.add('EcomProductCategory', r, 'catalogue.groups %s' % g['key'])
            r = self.tmpl('EcomProductCategoryTranslation', '%s$$%s' % (tcat, LANG))
            CT.set(r, 'CategoryTranslationCategoryId', slot['category'])
            CT.set(r, 'CategoryTranslationCategoryName', g['name'])
            self.add('EcomProductCategoryTranslation', r, 'catalogue.groups %s' % g['key'])
        for g in self.tops:
            for n, f in enumerate(g.get('specFields', [])):
                cat, fid, label = self.field_map[(g['key'], f['key'])]
                if (cat, fid) not in self.new_fields:
                    continue
                tcat, tfid = self.new_fields[(cat, fid)]
                origin = 'catalogue.groups %s specFields %s' % (g['key'], f['key'])
                for c_cat in (cat, 'reference_category'):
                    r = self.tmpl('EcomProductCategoryField', '%s$$%s' % (tcat if c_cat == cat else 'reference_category', tfid))
                    for c, v in (('FieldCategoryId', c_cat), ('FieldId', fid), ('FieldTemplateTag', fid), ('FieldType', 1), ('FieldSortOrder', n + 1)):
                        CF.set(r, c, v)
                    self.add('EcomProductCategoryField', r, origin)
                    r = self.tmpl('EcomProductCategoryFieldTranslation', '%s$$%s$$%s' % (tcat if c_cat == cat else 'reference_category', tfid, LANG))
                    for c, v in (('FieldTranslationFieldCategoryId', c_cat), ('FieldTranslationFieldId', fid), ('FieldTranslationFieldLabel', label)):
                        CFT.set(r, c, v)
                    self.add('EcomProductCategoryFieldTranslation', r, origin)
        # spec table: tc_specs display group fields in input order
        FD = self.tables['EcomFieldDisplayGroupFields']
        fd_t = next(iter(FD.rows.values())).clone()
        gid = fd_t.get('FieldDisplayGroupFieldGroupId')
        order = 0
        for g in self.tops:
            for f in g.get('specFields', []):
                cat, fid, label = self.field_map[(g['key'], f['key'])]
                order += 1
                r = fd_t.clone()
                FD.set(r, 'FieldDisplayGroupFieldSystemName', 'ProductCategory|%s|%s' % (cat, fid))
                FD.set(r, 'FieldDisplayGroupFieldGroupId', gid)
                FD.set(r, 'FieldDisplayGroupFieldSortOrder', order)
                self.add('EcomFieldDisplayGroupFields', r)
        # values
        FV = self.tables['EcomProductCategoryFieldValue']
        fv_t = next(iter(FV.rows.values())).clone()
        for p in self.products:
            top = self.top_of(p['group'])['key']
            for fkey, value in sorted((p.get('specs') or {}).items()):
                cat, fid, label = self.field_map[(top, fkey)]
                r = fv_t.clone()
                for c, v in (('FieldValueFieldId', fid), ('FieldValueFieldCategoryId', cat), ('FieldValueProductId', self.pid[p['number']]),
                             ('FieldValueProductVariantId', ''), ('FieldValueProductLanguageId', LANG), ('FieldValueValue', str(value)),
                             ('FieldValueSortOrder', 0)):
                    FV.set(r, c, v)
                self.add('EcomProductCategoryFieldValue', r)
        # completion rules and data models
        CR = self.tables['EcomCompletionRules']
        G = self.tables['EcomGroups']
        for g in self.tops:
            slot = self.top_slot[g['key']]
            fields = [self.field_map[(g['key'], f['key'])] for f in g.get('specFields', [])]
            src = slot['template'] if slot['new'] else slot
            for row in CR.rows.values():
                if str(row.get('EcomCompletionRuleId')) == src['rule']:
                    r = row.clone()
                    CR.set(r, 'EcomCompletionRuleId', int(slot['rule']))
                    CR.set(r, 'EcomCompletionRuleName', '%s data complete' % g['name'])
                    CR.set(r, 'EcomCompletionRuleDescription', 'The %s attributes a %s product carries before it is fit to sell: %s.'
                           % (len(fields), g['name'], ', '.join(l.lower() for _, _, l in fields)) if fields else 'No attribute is required yet.')
                    CR.set(r, 'EcomCompletionRuleProductFields', ','.join('ProductCategory|%s|%s' % (c, f) for c, f, _ in fields))
                    self.add('EcomCompletionRules', r, 'catalogue.groups %s' % g['key'])
            r = G.by_file('%s$$%s' % (src['dataModel'], LANG)).clone()
            for c, v in (('GroupId', slot['dataModel']), ('GroupNumber', slot['dataModel']), ('ProductCategoryId', slot['category']),
                         ('GroupCompletionRules', slot['rule']), ('GroupName', g['name'])):
                G.set(r, c, v)
            self.add('EcomGroups', r, 'catalogue.groups %s' % g['key'])

    # prices ---------------------------------------------------------------
    def build_prices(self):
        PR = self.tables['EcomPrices']
        pr = self.inp['prices']
        t_list = self.tmpl('EcomPrices', 'TC-PRICE-LIST-0002')
        t_tier = self.tmpl('EcomPrices', 'TC-PRICE-Q10-0020')
        t_grp = self.tmpl('EcomPrices', 'TC-PRICE-GRP-0020')
        t_ctr = self.tmpl('EcomPrices', 'TC-PRICE-CTR-0046')
        self.price_rows = []   # (product number, quantity, amount, customerNumber or None, user group id or None)

        def emit(tmpl, pid_num, priceid, qty, amount, origin, cust='', ugroup=''):
            r = tmpl.clone()
            for c, v in (('PriceId', priceid), ('PriceProductId', self.pid[pid_num]), ('PriceProductVariantId', ''),
                         ('PriceCurrency', self.currency), ('PriceQuantity', qty), ('PriceAmount', amount),
                         ('PriceUserCustomerNumber', cust), ('PriceUserGroupId', ugroup)):
                PR.set(r, c, v)
            self.add('EcomPrices', r, origin)
            self.price_rows.append((pid_num, qty, amount, cust or None, int(ugroup) if ugroup else None))

        def qsuffix(qty):
            # quantity 1 keeps the sample's key shape; another quantity makes the key unique per rung
            return '' if qty == 1 else '-Q%d' % qty

        n4 = lambda num: self.pid[num][len('TCPROD'):]
        for p in self.products:
            emit(t_list, p['number'], 'TC-PRICE-LIST-' + n4(p['number']), 1, p['listPrice'], 'catalogue.products %s listPrice' % p['number'])
        for i, t in enumerate(pr.get('tiers') or []):
            emit(t_tier, t['product'], 'TC-PRICE-Q%02d-%s' % (t['quantity'], n4(t['product'])), t['quantity'], t['amount'], 'prices.tiers[%d]' % i)
        group = str(self.account_id[self.price_group['name']]) if self.price_group else str(PERMISSION['user'])
        for i, t in enumerate(pr.get('groupPrices') or []):
            q = t.get('quantity', 1)
            emit(t_grp, t['product'], 'TC-PRICE-GRP-%s%s' % (n4(t['product']), qsuffix(q)), q, t['amount'], 'prices.groupPrices[%d]' % i, ugroup=group)
        acct_ord = {g['customerNumber']: i + 1 for i, g in enumerate(self.accounts)}
        for i, t in enumerate(pr.get('contracts') or []):
            q = t.get('quantity', 1)
            emit(t_ctr, t['product'], 'TC-PRICE-CTR-%s-A%d%s' % (n4(t['product']), acct_ord[t['account']], qsuffix(q)), q, t['amount'],
                 'prices.contracts[%d]' % i, cust=t['account'])

    def price_for(self, number, qty, account):
        """The lowest price the account's users get at that quantity: list, tiers, a group price of every signed-in
        customer or of their account, a contract on their customer number."""
        best = None
        aid = self.account_id.get(account['name'])
        for (num, q, amount, cust, ugroup) in self.price_rows:
            if num != number or q > qty:
                continue
            if cust and cust != account.get('customerNumber'):
                continue
            if ugroup and ugroup not in (PERMISSION['user'], aid):
                continue
            best = amount if best is None else min(best, amount)
        return best

    # users ----------------------------------------------------------------
    def address_cols(self, g):
        a = g.get('address') or {}
        return (('AccessUserAddress', a.get('street')), ('AccessUserZip', a.get('zip')), ('AccessUserCity', a.get('city')),
                ('AccessUserCountryCode', a.get('countryCode')))

    def build_users(self):
        AU = self.tables['AccessUser']
        AG = self.tables['AccessUserGroupRelation']
        AS = self.tables['AccessUserSecondaryRelation']
        t_acct = self.tmpl('AccessUser', '100106')
        t_rel = self.tmpl('AccessUserGroupRelation', '100100$$100101')
        t_sec = self.tmpl('AccessUserSecondaryRelation', '1292$$100100')
        for g in self.accounts:
            aid = self.account_id[g['name']]
            r = self.tmpl('AccessUser', str(aid)) if str(aid) + '.yml' in AU.rows else t_acct.clone()
            for c, v in (('AccessUserId', aid), ('AccessUserUserName', g['name']), ('AccessUserName', g['name']),
                         ('AccessUserCustomerNumber', g['customerNumber']), ('AccessUserCompany', g['name']),
                         ('AccessUserPhone', g.get('phone'))) + self.address_cols(g):
                AU.set(r, c, v)
            self.add('AccessUser', r)
            s = t_sec.clone()
            AS.set(s, 'AccessUserSecondaryRelationUserId', PERMISSION['csr'])
            AS.set(s, 'AccessUserSecondaryRelationSecondaryUserId', aid)
            self.add('AccessUserSecondaryRelation', s)
        buyer_login = 'TruvioBuyer'
        stable_logins = {100101: 'TruvioBuyer', 100102: 'TruvioCsr', 100103: 'TruvioAdmin'}
        for u in self.users:
            uid = self.uid[u['user']['userName']]
            g = u['group']
            acct = g if g['kind'] == 'account' else self.account1
            login = u['user']['userName']
            if uid in stable_logins and not self.logins_input():
                login = stable_logins[uid]
            if uid == 100101:
                buyer_login = login
            tkey = str(uid) if uid in (100101, 100102, 100103) else '100103'
            r = self.tmpl('AccessUser', tkey)
            for c, v in (('AccessUserId', uid), ('AccessUserUserName', login), ('AccessUserName', u['user'].get('name') or login),
                         ('AccessUserEmail', u['user'].get('email')), ('AccessUserCompany', acct['name']),
                         ('AccessUserCustomerNumber', acct['customerNumber']), ('AccessUserPhone', u['user'].get('phone') or acct.get('phone'))) + self.address_cols(acct):
                AU.set(r, c, v)
            self.add('AccessUser', r)
            groups = []
            if g['kind'] == 'account':
                groups.append(self.account_id[g['name']])
            elif uid == 100102:
                groups.append(self.account_id[self.account1['name']])
            groups.append(PERMISSION[u['role']])
            for gid in groups:
                x = t_rel.clone()
                AG.set(x, 'AccessUserGroupRelationGroupId', gid)
                AG.set(x, 'AccessUserGroupRelationUserId', uid)
                self.add('AccessUserGroupRelation', x)
        # the buyer's second profile: same login, on the account the input says the buyer may act for
        b = self.buyer['user']
        a2 = self.profile_account
        if a2:
            r = self.tmpl('AccessUser', '100105')
            for c, v in (('AccessUserUserName', buyer_login), ('AccessUserName', b.get('name') or buyer_login), ('AccessUserEmail', b.get('email')),
                         ('AccessUserCompany', a2['name']), ('AccessUserCustomerNumber', a2['customerNumber']),
                         ('AccessUserPhone', b.get('phone') or a2.get('phone'))) + self.address_cols(a2):
                AU.set(r, c, v)
            self.add('AccessUser', r, 'the buyer\'s second profile (actsFor %s)' % a2['customerNumber'])
            for gid in (self.account_id[a2['name']], PERMISSION['buyer']):
                x = t_rel.clone()
                AG.set(x, 'AccessUserGroupRelationGroupId', gid)
                AG.set(x, 'AccessUserGroupRelationUserId', 100105)
                self.add('AccessUserGroupRelation', x)
        else:
            self.warnings.append('No second profile for the buyer: the input names no account the buyer may act for, and the base contract beside the source '
                                 'guarantees none, so Switch account shows no button.')
        if not self.logins_input():
            renamed = [u['user']['userName'] for u in self.users if self.uid[u['user']['userName']] in stable_logins and u['user']['userName'] != stable_logins[self.uid[u['user']['userName']]]]
            if renamed:
                self.warnings.append('--logins stable: the personas keep the user names TruvioBuyer, TruvioCsr and TruvioAdmin the gate legs sign in as; the input user names %s are not written. Pass --logins input to write them.' % ', '.join(renamed))
        else:
            self.warnings.append('--logins input: the personas sign in as the input user names; point the Foundry credential tool and the gate persona legs at them.')

    # history --------------------------------------------------------------
    def build_history(self):
        h = self.inp['history']
        O = self.tables['EcomOrders']
        L = self.tables['EcomOrderLines']
        by_name = {u['user']['userName']: u for u in self.users}
        buyer_name = self.buyer['user']['userName']
        t_line = self.tmpl('EcomOrderLines', 'TCO-0001-1')
        templates = {'completed': 'TCO-0001', 'open': 'TCO-0009', 'rejected': 'TCO-0005',
                     'QuotePending': 'TCO-Q001', 'QuoteSent': None, 'QuoteAccepted': None, 'QuoteRejected': None, 'cart': 'TCO-C001'}
        quote_t = {r.get('OrderStateId'): r for r in O.rows.values() if r.get('OrderIsQuote')}
        orders = list(enumerate(h.get('orders') or []))
        first = orders.pop(self.first_completed)
        orders.insert(0, first)
        plan = [('TCO-%04d' % (i + 1), 'order', o) for i, (_, o) in enumerate(orders)]
        plan += [('TCO-Q%03d' % (i + 1), 'quote', q) for i, q in enumerate(h.get('quotes') or [])]
        plan += [('TCO-C%03d' % (i + 1), 'cart', c) for i, c in enumerate(h.get('carts') or [])]
        self.report['ids']['orders'] = [k for k, _, _ in plan]
        for n, (oid, kind, o) in enumerate(plan):
            owner = by_name[o.get('user', buyer_name)]
            acct = owner['group']
            uid = self.uid[owner['user']['userName']]
            day = self.harvest - timedelta(days=o['daysAgo'])
            hour = 9 + n % 8
            if kind == 'order':
                r = self.tmpl('EcomOrders', templates[o['state']])
                O.set(r, 'OrderStateId', self.state_ids[o['state']])
            elif kind == 'quote':
                r = quote_t[o['state']].clone() if o['state'] in quote_t else self.tmpl('EcomOrders', 'TCO-Q001')
                O.set(r, 'OrderStateId', o['state'])
            else:
                r = self.tmpl('EcomOrders', 'TCO-C001')
            total = 0.0
            lines = []
            for j, line in enumerate(o['lines']):
                unit = line.get('unitPrice')
                if unit is None:
                    unit = self.price_for(line['product'], line['quantity'], acct)
                amount = round(unit * line['quantity'], 2)
                total = round(total + amount, 2)
                lr = t_line.clone()
                for c, v in (('OrderLineId', '%s-%d' % (oid, j + 1)), ('OrderLineOrderId', oid), ('OrderLineDate', dt(day, hour)),
                             ('OrderLineProductNumber', line['product']), ('OrderLineProductId', self.pid[line['product']]),
                             ('OrderLineProductName', self.product_by_number[line['product']]['name']),
                             ('OrderLineUnitPrice', unit), ('OrderLineQuantity', line['quantity']),
                             ('OrderLinePriceWithVAT', amount), ('OrderLinePriceWithoutVAT', amount),
                             ('OrderLineUnitPriceWithVAT', unit), ('OrderLineUnitPriceWithoutVAT', unit)):
                    L.set(lr, c, v)
                lines.append(lr)
            a = acct.get('address') or {}
            vals = [('OrderId', oid), ('OrderDate', dt(day, hour)), ('OrderCurrencyCode', self.currency),
                    ('OrderCustomerNumber', acct['customerNumber']), ('OrderCustomerCompany', acct['name']),
                    ('OrderCustomerName', owner['user'].get('name') or owner['user']['userName']),
                    ('OrderCustomerEmail', owner['user'].get('email')), ('OrderCustomerCountryCode', a.get('countryCode') or 'US'),
                    ('OrderCustomerAddress', a.get('street')), ('OrderCustomerZip', a.get('zip')), ('OrderCustomerCity', a.get('city')),
                    ('OrderCustomerAccessUserId', uid), ('OrderReference', o.get('reference'))]
            for c in ('OrderTotalPrice', 'OrderPriceWithVAT', 'OrderPriceWithoutVAT', 'OrderPriceBeforeFeesWithVAT', 'OrderPriceBeforeFeesWithoutVAT'):
                vals.append((c, total))
            if kind == 'order' and o['state'] == 'completed':
                done = min(day + timedelta(days=2), self.harvest)
                vals.append(('OrderCompletedDate', dt(done, 17 if done != day else 18)))
            if kind == 'quote':
                vals.append(('OrderCustomerComment', o.get('comment')))
            if kind == 'cart':
                vals.append(('OrderDisplayName', o['name']))
            for c, v in vals:
                O.set(r, c, v)
            self.add('EcomOrders', r)
            for lr in lines:
                self.add('EcomOrderLines', lr)
        # the return request against TCO-0001 line 1
        RM = self.tables['EcomRmas']
        r = RM.rows['PACK-RMA-0001.yml'].clone()
        bu = self.buyer['user']
        a1 = self.account1.get('address') or {}
        for c, v in (('RmaCustomerNumber', self.account1['customerNumber']), ('RmaCustomerCompany', self.account1['name']),
                     ('RmaCustomerName', bu.get('name') or bu['userName']), ('RmaCustomerEmail', bu.get('email')),
                     ('RmaCustomerCountryCode', a1.get('countryCode') or 'US'), ('RmaDeliveryName', bu.get('name') or bu['userName']),
                     ('RmaDeliveryCompany', self.account1['name']), ('RmaDeliveryCountryCode', a1.get('countryCode') or 'US')):
            if r.has(c):
                RM.set(r, c, v)
        self.out.setdefault('EcomRmas', {})['PACK-RMA-0001.yml'] = r
        self.keep('EcomRmaOrderLines', self.tables['EcomRmaOrderLines'].by_file('100301'))
        # favourites
        FL = self.tables['EcomCustomerFavoriteLists']
        FP = self.tables['EcomCustomerFavoriteProducts']
        t_fl = self.tmpl('EcomCustomerFavoriteLists', '100401')
        t_fp = self.tmpl('EcomCustomerFavoriteProducts', '100401$$TCPROD0006$$')
        default_given = set()
        for i, f in enumerate(h.get('favourites') or []):
            owner = by_name[f.get('user', buyer_name)]
            uid = self.uid[owner['user']['userName']]
            lid = FAVOURITE_LIST_BASE + i
            is_default = f.get('default', uid not in default_given)
            default_given.add(uid)
            r = t_fl.clone()
            for c, v in (('Id', lid), ('AccessUserId', uid), ('Name', f['name']), ('Description', f.get('description')), ('IsDefault', bool(is_default))):
                FL.set(r, c, v)
            self.add('EcomCustomerFavoriteLists', r)
            for k, num in enumerate(f['products']):
                x = t_fp.clone()
                for c, v in (('FavoriteListId', lid), ('ProductId', self.pid[num]), ('SortOrder', k + 1)):
                    FP.set(x, c, v)
                self.add('EcomCustomerFavoriteProducts', x, 'history.favourites[%d].products[%d]' % (i, k))

    # PIM shop, workspace, folder ---------------------------------------------
    def build_pim(self):
        name = '%s PIM' % self.short
        S = self.tables['EcomShops']
        r = S.by_file('TCSHOP-PIM').clone()
        S.set(r, 'ShopName', name)
        self.add('EcomShops', r)
        DS = self.tables['DynamicStructures']
        for row in DS.rows.values():
            r = row.clone()
            DS.set(r, 'DynamicStructureTitle', '%s - by data model' % name)
            self.add('DynamicStructures', r)
        DL = self.tables['DynamicStructureLevels']
        for row in DL.rows.values():
            r = row.clone()
            if str(r.get('DynamicStructureLevelField')).startswith('DATAMODEL_'):
                DL.set(r, 'DynamicStructureLevelField', 'DATAMODEL_' + name.replace(' ', '_'))
            self.add('DynamicStructureLevels', r)
        G = self.tables['EcomGroups']
        folder = next(r for r in G.rows.values() if r.get('GroupType') == 1)
        f = folder.clone()
        G.set(f, 'GroupName', self.inp['catalogue'].get('pimFolder') or self.company)
        G.set(f, 'GroupNumber', 'TCDM-' + slug_key(self.short))
        self.add('EcomGroups', f)
        fid = folder.get('GroupId')
        used_models = {self.top_slot[g['key']]['dataModel'] for g in self.tops}
        SGR, GR = self.tables['EcomShopGroupRelation'], self.tables['EcomGroupRelations']
        for row in SGR.rows.values():
            gid = row.get('ShopGroupGroupId')
            if gid == fid or gid in used_models:
                self.keep('EcomShopGroupRelation', row)
        for row in GR.rows.values():
            if row.get('GroupRelationsParentId') == fid and row.get('GroupRelationsGroupId') in used_models:
                self.keep('EcomGroupRelations', row)
        # data models beyond the sample's: the shop and folder relations of the template data model, re-pointed
        for n, g in enumerate(self.tops):
            slot = self.top_slot[g['key']]
            if not slot['new']:
                continue
            tdm = slot['template']['dataModel']
            s = next(r for r in SGR.rows.values() if r.get('ShopGroupGroupId') == tdm).clone()
            SGR.set(s, 'ShopGroupGroupId', slot['dataModel'])
            SGR.set(s, 'ShopGroupRelationsSorting', n + 2)
            self.add('EcomShopGroupRelation', s, 'catalogue.groups %s' % g['key'])
            rel = next(r for r in GR.rows.values() if r.get('GroupRelationsGroupId') == tdm and r.get('GroupRelationsParentId') == fid).clone()
            GR.set(rel, 'GroupRelationsGroupId', slot['dataModel'])
            GR.set(rel, 'GroupRelationsSorting', n + 1)
            self.add('EcomGroupRelations', rel, 'catalogue.groups %s' % g['key'])
        self.report['pimShop'] = {'name': name, 'indexField': 'DATAMODEL_' + name.replace(' ', '_')}

    # rows kept as the sample ships them ------------------------------------
    def build_kept(self):
        for table in ('EcomShopLanguageRelation', 'EcomProductField', 'EcomDetailsGroup', 'EcomDetailsGroupTranslation',
                      'EcomFieldDisplayGroups', 'EcomFieldDisplayGroupTranslation'):
            for row in self.tables[table].rows.values():
                self.keep(table, row)

    # identities and GUIDs -----------------------------------------------------
    def assign_identities(self):
        for table, rows in self.out.items():
            t = self.tables[table]
            if not t.meta:
                continue
            ids = [c for c in t.meta.identity if c not in t.meta.keys]
            guids = [c for c, ty in t.meta.types.items() if ty == 'uniqueidentifier' and c not in t.meta.keys]
            sample_keys = set(t.rows)
            for col in ids:
                taken = {rows[n].get(col) for n in rows if n in sample_keys}
                pool = sorted(t.rows[n].get(col) for n in t.rows if n not in rows and t.rows[n].get(col) not in taken)
                nxt = NEW_IDENTITY_BASE
                fixed = {n: t.rows[n].get(col) for n in rows if n in sample_keys}
                for n in sorted(rows):
                    if n in fixed:
                        t.set(rows[n], col, fixed[n])
                    elif pool:
                        t.set(rows[n], col, pool.pop(0))
                    else:
                        nxt += 1
                        t.set(rows[n], col, nxt)
            for col in guids:
                for n in sorted(rows):
                    if n in sample_keys:
                        rows[n].set_raw(col, t.rows[n].raw(col))
                    else:
                        rows[n].set_raw(col, str(uuid.uuid5(UUID_NS, '%s/%s/%s' % (table, n, col))))

    # ----------------------------------------------------------------- storefront copy
    def build_content(self):
        b = self.inp['brandCopy']
        contact = b.get('contact') or {}
        email = contact.get('email') or 'support@' + b['emailDomain']
        assets = {}
        for k, src in self.brand_assets.items():
            if src:
                sub = 'brand' if k in ('logo', 'logoFooter') else 'scenic'
                assets[k] = '/Files/Images/%s/%s/%s' % (self.asset_folder, sub, src.name)
        self.brand_paths = assets
        subs = [
            ('/Files/Images/TruvioCommerce/brand/truvio-logo-footer.svg', assets['logoFooter']),
            ('/Files/Images/TruvioCommerce/brand/truvio-logo.svg', assets['logo']),
            ('/Files/Images/TruvioCommerce/scenic/product-shot-1.webp', assets['hero']),
            ('/Files/Images/TruvioCommerce/scenic/abstract-patterns.jpeg', assets['catalogueBand']),
            ('/Files/Images/TruvioCommerce/people/office-collaboration.webp', assets['people']),
            ('/Files/Images/TruvioCommerce/scenic/product-visual.png', assets['portal']),
            ('support@truvio-demo.example', email),
            ('truvio-demo.example', b['emailDomain']),
            ('+1 555 0100', contact.get('phone') or '+1 555 0100'),
            ('Truvio Commerce', self.company),
            ('TRUVIO', self.short.upper()),
            ('Truvio', self.short),
        ]
        top_map = {}
        sample_tops = [s['sampleTop'] for s in self.categories]
        for i, st in enumerate(sample_tops):
            g = self.tops[i] if i < len(self.tops) else self.tops[0]
            old_name = self.tables['EcomGroups'].by_file('%s$$%s' % (st, LANG)).get('GroupName')
            top_map[st] = (self.gid[g['key']], old_name, g['name'])
        year = b.get('copyrightYear', self.harvest.year)
        copyright_text = b.get('copyright') or '© %d %s. All rights reserved.' % (year, self.company)
        n_products = len(self.products)
        top_names = [g['name'] for g in self.tops]
        hero_text = '%d products across %s.' % (n_products, ', '.join(top_names[:-1]) + ' and ' + top_names[-1] if len(top_names) > 1 else top_names[0])
        home = b.get('home') or {}
        about = b.get('about') or {}
        slots = [
            ('merge/_content/Swift 2/Home/page.yml', 'metaTitle', 'text', home.get('metaTitle') or self.company),
            ('merge/_content/Swift 2/Home/page.yml', 'description', 'text', home.get('metaDescription')),
            ('merge/_content/Swift 2/Home/grid-row-1/paragraph-c1-18.yml', 'Eyebrow', 'html', home.get('heroEyebrow')),
            ('merge/_content/Swift 2/Home/grid-row-1/paragraph-c1-18.yml', 'Title', 'html', home.get('heroTitle')),
            ('merge/_content/Swift 2/Home/grid-row-1/paragraph-c1-18.yml', 'Text', 'html', home.get('heroText') or hero_text),
            ('merge/_content/Swift 2/Home/grid-row-1/paragraph-c1-18.yml', 'AltText', 'text', home.get('heroAltText')),
            ('merge/_content/Swift 2/About/page.yml', 'description', 'text', about.get('metaDescription')),
            ('merge/_content/Swift 2/About/grid-row-1/paragraph-c1-59.yml', 'Title', 'html', about.get('title')),
            ('merge/_content/Swift 2/About/grid-row-1/paragraph-c1-59.yml', 'Text', 'html', about.get('text')),
            ('merge/_content/Swift 2/Header _ Footer/Desktop Footer/grid-row-2/paragraph-c1-24.yml', 'Text', 'html', copyright_text),
            ('merge/_content/Swift 2/Header _ Footer/Mobile Footer/grid-row-4/paragraph-c1-13.yml', 'Text', 'html', copyright_text),
            ('replace/_content/Digital Assets Portal/Header _ Footer/Desktop Footer/grid-row-3/paragraph-c1-5.yml', 'Text', 'html', copyright_text),
        ]
        by_path = {}
        for path, field, kind, value in slots:
            if value is not None:
                by_path.setdefault(path, []).append((field, kind, value))
        self.report['content'] = {'documents': 0, 'slotsWritten': 0, 'groupLinksRetargeted': 0}
        for mode in ('merge', 'replace'):
            root = self.src / mode / '_content'
            if not root.is_dir():
                continue
            for p in sorted(root.rglob('*.yml')):
                rel = rel_posix(p.relative_to(self.src))
                data = p.read_bytes()
                bom = data.startswith(BOM)
                text = data.decode('utf-8-sig')
                orig = text
                nl = '\r\n' if '\r\n' in text else '\n'
                lines = text.split(nl)
                for field, kind, value in by_path.get(rel, []):
                    for i, line in enumerate(lines):
                        m = re.match(r'^(\s+"%s": )(".*")$' % re.escape(field), line)
                        if m:
                            old = json.loads(m.group(2))
                            new = replace_inner_html(old, value) if kind == 'html' else value
                            lines[i] = m.group(1) + json.dumps(new, ensure_ascii=False)
                            self.report['content']['slotsWritten'] += 1
                            break
                    else:
                        self.warnings.append('brandCopy slot %s in %s: field not found; the document changed upstream' % (field, rel))
                text = nl.join(lines)
                for st, (new_gid, old_name, new_name) in top_map.items():
                    if 'GroupID=' + st in text:
                        def fix(m, st=st, new_gid=new_gid, old_name=old_name, new_name=new_name):
                            v = json.loads(m.group(2))
                            if 'GroupID=' + st not in v:
                                return m.group(0)
                            v = v.replace('GroupID=' + st, 'GroupID=' + new_gid).replace('Browse ' + old_name, 'Browse ' + new_name)
                            self.report['content']['groupLinksRetargeted'] += 1
                            return m.group(1) + json.dumps(v, ensure_ascii=False) + m.group(3)
                        text = re.sub(r'^(\s+"[^"]+": )(".*")(\r?)$', fix, text, flags=re.M)
                for old, new in subs:
                    text = text.replace(old, json.dumps(new, ensure_ascii=False)[1:-1])
                if text != orig:
                    self.report['content']['documents'] += 1
                self.files[rel] = (BOM if bom else b'') + text.encode('utf-8')

    # ----------------------------------------------------------------- inventories
    def build_files(self):
        # everything of the source layer that is not regenerated below
        for p in sorted(self.src.rglob('*')):
            if not p.is_file():
                continue
            rel = rel_posix(p.relative_to(self.src))
            top = rel.split('/')[0]
            if top in ('tools', 'files') or ('/' not in rel and rel.lower().endswith('.md')):
                continue
            if rel.startswith('merge/_sql/') and rel.count('/') == 3:
                continue  # row files and _meta: written from the model
            if rel.startswith(('merge/_content/', 'replace/_content/')):
                continue
            if rel in ('layer.json', 'merge/merge-manifest.json') or rel.startswith('config/'):
                continue
            self.files[rel] = p.read_bytes()
        for table, rows in sorted(self.out.items()):
            t = self.tables[table]
            if not rows:
                continue
            if t.meta_bytes is not None:
                self.files['merge/_sql/%s/_meta.yml' % table] = t.meta_bytes
            for n, row in sorted(rows.items()):
                self.files['merge/_sql/%s/%s' % (table, n)] = t.render(row)
        for (kind, _), src in sorted(self.assets.items()):
            if kind == 'products':
                self.files['files/Images/%s/products/%s' % (self.asset_folder, src.name)] = src.read_bytes()
            else:
                self.files['files/Documents/%s/%s' % (self.asset_folder, src.name)] = src.read_bytes()
        for k, src in sorted(self.brand_assets.items()):
            if src:
                sub = 'brand' if k in ('logo', 'logoFooter') else 'scenic'
                self.files['files/Images/%s/%s/%s' % (self.asset_folder, sub, src.name)] = src.read_bytes()

    def build_inventories(self):
        live = {t for t, rows in self.out.items() if rows}
        dropped_tables = sorted(t for t in self.tables if t not in live)
        self.report['removed'].append({'tables': dropped_tables})
        # merge-manifest.json
        man = load_json(self.src / 'merge' / 'merge-manifest.json')
        entries = []
        for e in man['entries']:
            if e.get('providerType') != 'SqlTable':
                entries.append(e)
                continue
            if e['table'] not in live:
                continue
            names = sorted(self.out[e['table']])
            files = ['_sql/%s/%s' % (e['table'], n) for n in names]
            if self.tables[e['table']].meta_bytes is not None:
                files.append('_sql/%s/_meta.yml' % e['table'])
            e = dict(e)
            e['files'] = files
            entries.append(e)
        man['entries'] = entries
        self.files['merge/merge-manifest.json'] = (json.dumps(man, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        # config predicates: drop emptied tables, widen numeric fences
        for p in sorted((self.src / 'config').glob('*.json')):
            cfg = load_json(p)
            preds = []
            for pr in cfg.get('predicates', []):
                if pr.get('providerType') == 'SqlTable' and pr.get('table') not in live:
                    continue
                pr = dict(pr)
                if pr.get('table') in live:
                    pr['where'] = self.widen(pr['table'], pr.get('where', ''))
                preds.append(pr)
            cfg['predicates'] = preds
            self.files['config/' + p.name] = (json.dumps(cfg, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        # layer.json
        lj = json.loads(json.dumps(self.layer_json))
        lj['name'] = self.name
        lj['fragmentTables'] = [t for t in lj.get('fragmentTables', []) if t in live]
        lj['files'] = sorted(k[len('files/'):] for k in self.files if k.startswith('files/'))
        lj['configRows'] = self.config_rows(lj.get('configRows', []))
        if 'ledger' in lj:
            lj['ledger'] = dict(lj['ledger'])
            lj['ledger']['provides'] = self.provides(lj['ledger'].get('provides', []))
        ch = dict(lj.get('costHints') or {})
        ch['expectedRows'] = {t: len(self.out[t]) for t in sorted(live)}
        ch['expectedRowsNote'] = ('Generated by tools/sample-data/rewrite-sample-data.py from %s %s: %d rows in %d tables, every count equal to the '
                                  'row files of merge/_sql/<Table>/ and to merge/merge-manifest.json.' % (
                                      self.layer_json['name'], self.layer_json['version'], sum(len(self.out[t]) for t in live), len(live)))
        ch['rewrittenFrom'] = {'layer': self.layer_json['name'], 'version': self.layer_json['version'],
                               'generator': 'tools/sample-data/rewrite-sample-data.py', 'inputSha256': self.input_sha}
        lj['costHints'] = ch
        self.files['layer.json'] = (json.dumps(lj, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        self.report['expectedCounts'] = {'EcomProducts': len(self.out['EcomProducts']), 'EcomGroups': len(self.out['EcomGroups'])}
        self.report['ledgerProvidesRemoved'] = sorted(set(self.layer_json.get('ledger', {}).get('provides', [])) - set(lj.get('ledger', {}).get('provides', [])))
        readme = ['# %s (kind: sample-data)' % self.name, '',
                  'A copy of `%s` %s rewritten for %s by `tools/sample-data/rewrite-sample-data.py` in the Truvio Commerce Distribution.'
                  % (self.layer_json['name'], self.layer_json['version'], self.company),
                  'Do not edit the rows by hand: change the customer data file and run the generator again.', '',
                  'Compose it in the demo edition in place of `sample-data`. The edition counts are EcomProducts %d and EcomGroups %d.'
                  % (self.report['expectedCounts']['EcomProducts'], self.report['expectedCounts']['EcomGroups']), '']
        self.files['README.md'] = ('\n'.join(readme)).encode('utf-8')

    def widen(self, table, where):
        rows = self.out[table]
        t = self.tables[table]

        def ids(col):
            vals = []
            for r in rows.values():
                v = r.get(col)
                if isinstance(v, (int, float)) and not isinstance(v, bool):
                    vals.append(int(v))
            return vals

        def rng(m):
            col, lo, hi = m.group(1), int(m.group(2)), int(m.group(4))
            vals = [v for v in ids(col) if v >= 100000]
            if vals:
                lo, hi = min(lo, min(vals)), max(hi, max(vals))
            return '%s >= %d AND %s <= %d' % (col, lo, col, hi)
        where = re.sub(r'(\w+) >= (\d+) AND (\w+) <= (\d+)', rng, where)

        def inlist(m):
            col = m.group(1)
            vals = sorted(set(ids(col)) | {int(x) for x in re.findall(r'\d+', m.group(2))})
            return '%s IN (%s)' % (col, ', '.join(str(v) for v in vals))
        where = re.sub(r'(\w+) IN \(([\d, ]+)\)', inlist, where)
        return where

    def config_rows(self, rows):
        kept, rewritten, dropped = [], [], []
        out = []
        for cr in rows:
            table = cr['table']
            conds = re.findall(r"([A-Za-z0-9_]+) *= *'([^']*)'", cr['where'])
            if table not in self.tables:
                out.append(cr)
                kept.append(cr['where'])
                continue
            t = self.tables[table]
            rows_out = list(self.out.get(table, {}).values())

            def match(r, cs):
                for c, v in cs:
                    if not r.has(c):
                        return False
                    x = r.get(c)
                    if isinstance(x, bool):
                        x = '1' if x else '0'
                    elif isinstance(x, float) and x.is_integer():
                        x = str(int(x))
                    if str(x if x is not None else '') != v:
                        return False
                return True
            if any(match(r, conds) for r in rows_out):
                out.append(cr)
                kept.append(cr['where'])
                continue
            keycols = t.meta.keys if t.meta else []
            keyconds = [(c, v) for c, v in conds if c in keycols]
            cand = [r for r in rows_out if keyconds and match(r, keyconds)]
            if cand:
                r = cand[0]
                new = []
                for c, v in conds:
                    x = r.get(c)
                    if isinstance(x, bool):
                        x = '1' if x else '0'
                    elif isinstance(x, float) and x.is_integer():
                        x = str(int(x))
                    new.append((c, str(x if x is not None else '')))
                if all(CONFIG_ROW_VALUE.match(v) for _, v in new):
                    cr = dict(cr)
                    cr['where'] = ' AND '.join("%s = '%s'" % (c, v) for c, v in new)
                    cr['description'] = cr['description'] + ' (Values rewritten for this copy by rewrite-sample-data.py.)'
                    out.append(cr)
                    rewritten.append(cr['where'])
                    continue
            dropped.append('%s: %s' % (table, cr['where']))
        first = self.products[0]
        pid = self.pid[first['number']]
        if CONFIG_ROW_VALUE.match(first['number']):
            out.insert(0, {'table': 'EcomProducts', 'where': "ProductId = '%s' AND ProductLanguageId = '%s' AND ProductNumber = '%s'" % (pid, LANG, first['number']),
                           'description': 'The first product of the customer catalogue (%s). Proves the merge deserialize landed the rewritten catalogue rows.' % first['name'].replace("'", '')})
        self.report['configRows'] = {'kept': len(kept), 'rewritten': rewritten, 'dropped': dropped}
        return out

    def provides(self, provides):
        h = self.inp['history']
        pr = self.inp['prices']
        has = {
            'pim.variants': False,
            'pim.bom': False,
            'pim.assortments': False,
            'pim.documents': any(p.get('documents') for p in self.products),
            'pim.product-relations': bool(self.out.get('EcomProductsRelated')),
            'commerce.customer-prices': bool(pr.get('contracts') or pr.get('groupPrices')),
            'commerce.quantity-prices': bool(pr.get('tiers')),
            'orders.quotes': bool(h.get('quotes')),
            'orders.named-carts': bool(h.get('carts')),
            'orders.favorite-lists': bool(h.get('favourites')),
        }
        return [f for f in provides if has.get(f, True)]

    # ----------------------------------------------------------------- checks on the result
    def residual_scan(self):
        """Sample tokens left in a non-key column of any row or in a content document."""
        sample_values = set()
        for t in ('EcomProducts',):
            for r in self.tables[t].rows.values():
                for c in ('ProductName', 'ProductNumber'):
                    v = r.get(c)
                    if v:
                        sample_values.add(v)
        for r in self.tables['AccessUser'].rows.values():
            for c in ('AccessUserName', 'AccessUserCompany', 'AccessUserEmail', 'AccessUserCustomerNumber'):
                v = r.get(c)
                if v:
                    sample_values.add(v)
        allowed = set()
        if not self.logins_input():
            allowed |= {'TruvioBuyer', 'TruvioCsr', 'TruvioAdmin'}
        brand = re.compile(r'(?i)truvio')
        hits = []
        for table, rows in sorted(self.out.items()):
            t = self.tables[table]
            keys = set(t.meta.keys) if t.meta else set()
            for n, row in sorted(rows.items()):
                for c, raw in row.cols:
                    if c in keys or raw == '':
                        continue
                    v = parse_raw(raw)
                    if not isinstance(v, str) or v in allowed:
                        continue
                    if brand.search(v) or v in sample_values:
                        hits.append('%s/%s %s: %s' % (table, n, c, v[:80]))
        for rel, data in sorted(self.files.items()):
            if '/_content/' in rel and brand.search(data.decode('utf-8-sig', errors='replace')):
                hits.append('%s: brand token' % rel)
        return hits

    def fence_check(self):
        """Every row inside the where of its table's predicate: a key outside the fence is never deserialized."""
        outside = []
        for rel, data in sorted(self.files.items()):
            if not rel.startswith('config/'):
                continue
            for pr in json.loads(data.decode('utf-8')).get('predicates', []):
                table, where = pr.get('table'), pr.get('where')
                if pr.get('providerType') != 'SqlTable' or not where or table not in self.out:
                    continue
                test = sql_where(where)
                for n, row in sorted(self.out[table].items()):
                    if not test(row):
                        outside.append('%s/%s outside "%s"' % (table, n, where))
        return outside

    def probe_report(self):
        carried_ids = {r.get('ProductId') for r in self.out['EcomProducts'].values()}
        carried_numbers = {r.get('ProductNumber') for r in self.out['EcomProducts'].values()}
        sample_numbers = {r.get('ProductId'): r.get('ProductNumber') for r in self.tables['EcomProducts'].rows.values()}
        missing = []
        for tok, layers in sorted(self.probe_fixtures.items()):
            if tok in carried_ids or tok in carried_numbers:
                missing.append('%s is now a customer product (%s): the probe resolves but expects the sample behaviour' % (tok, ', '.join(layers)))
            elif re.fullmatch(r'TCPROD\d{4}|TC-[A-Z]{3}-\d{4}', tok) or tok in sample_numbers.values():
                missing.append('%s not carried; requiresFixtures of %s' % (tok, ', '.join(layers)))
        self.report['probeFixturesNotCarried'] = missing
        refs = sorted(t for t in self.other_layer_products if t not in carried_ids)
        self.report['otherLayersNameAbsentProducts'] = {t: sorted(self.other_layer_products[t]) for t in refs}

    # ----------------------------------------------------------------- run
    def run(self, input_sha):
        self.input_sha = input_sha
        self.load_context()
        self.validate()
        self.plan()
        self.build()
        if self.reasons:
            raise Refused(self.reasons)
        self.build_content()
        self.build_files()
        self.build_inventories()
        for t in sorted(self.tables):
            self.report['tables'][t] = {'sample': len(self.tables[t].rows), 'copy': len(self.out.get(t, {}))}
        self.report['removed'].append({'sampleRowsNotCarried': sum(len(t.rows) for t in self.tables.values()) - sum(len(r) for r in self.out.values())})
        self.report['residualSampleTokens'] = self.residual_scan()
        self.report['outsidePredicateFence'] = self.fence_check()
        if self.report['outsidePredicateFence']:
            raise ValueError('generated rows outside their predicate fence: %s' % '; '.join(self.report['outsidePredicateFence'][:5]))
        self.probe_report()
        self.report['files'] = len(self.files)
        return self.files


# --------------------------------------------------------------------------- CLI

def find_source(explicit):
    if explicit:
        p = Path(explicit).resolve()
    else:
        p = None
        cand = SCRIPT_DIR.parent
        if (cand / 'layer.json').is_file() and load_json(cand / 'layer.json').get('kind') == 'sample-data':
            p = cand
        else:
            for d in [SCRIPT_DIR] + list(SCRIPT_DIR.parents):
                if (d / 'layers' / 'sample-data' / 'layer.json').is_file():
                    p = d / 'layers' / 'sample-data'
                    break
    if not p or not (p / 'layer.json').is_file():
        raise Refused(['no sample-data layer found; pass --source <Distribution>/layers/sample-data'])
    if load_json(p / 'layer.json').get('kind') != 'sample-data':
        raise Refused(['--source %s is not a layer of kind sample-data' % p])
    return p


def is_within(child, parent):
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def generate(input_path, out, name=None, source=None, dry_run=False, logins='stable', acts_for=None):
    """Returns (report, files). Writes nothing when dry_run. Raises Refused."""
    input_path = Path(input_path).resolve()
    out = Path(out).resolve()
    src = find_source(source)
    reasons = []
    name = name or out.name
    if name != out.name:
        reasons.append('--name %s differs from the --out folder name %s; the Distribution validator requires the folder name to equal layer.json name' % (name, out.name))
    if not re.fullmatch(r'[a-z0-9-]+', name):
        reasons.append('layer name %r: lowercase letters, digits and hyphen only (layer.schema.json name)' % name)
    dist_layers = src.parent
    if is_within(out, dist_layers) or is_within(out, src):
        reasons.append('--out %s is inside %s. The generator never writes the Distribution\'s layers: write the copy into the demo\'s own folder, e.g. <demo>/layers/%s' % (out, dist_layers, name))
    if not dry_run and out.exists() and any(out.iterdir()):
        reasons.append('--out %s exists and is not empty; remove it or choose another folder' % out)
    if logins not in ('stable', 'input'):
        reasons.append('--logins must be stable or input')
    if not input_path.is_file():
        reasons.append('--input %s does not exist' % input_path)
    if reasons:
        raise Refused(reasons)
    raw = input_path.read_bytes()
    inp = json.loads(raw.decode('utf-8-sig'))
    gen = Generator(src, inp, input_path.parent, name, logins, acts_for)
    files = gen.run(hashlib.sha256(raw).hexdigest())
    if not dry_run:
        out.mkdir(parents=True, exist_ok=True)
        for rel, data in sorted(files.items()):
            target = out / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
    return gen.report, files


def print_report(report, out=sys.stdout):
    w = out.write
    w('Layer %s from %s %s\n' % (report['layer'], report['source']['layer'], report['source']['version']))
    w('\nTables (sample -> copy):\n')
    for t, c in report['tables'].items():
        mark = '' if c['copy'] else '   removed'
        w('  %-38s %5d -> %5d%s\n' % (t, c['sample'], c['copy'], mark))
    w('\nEdition expectedCounts for the demo edition: %s\n' % json.dumps(report['expectedCounts']))
    w('PIM shop: %s, index field %s\n' % (report['pimShop']['name'], report['pimShop']['indexField']))
    w('Storefront documents rewritten: %d, slots written: %d, group links retargeted: %d\n'
      % (report['content']['documents'], report['content']['slotsWritten'], report['content']['groupLinksRetargeted']))
    cr = report['configRows']
    w('configRows: %d kept, %d rewritten, %d dropped\n' % (cr['kept'], len(cr['rewritten']), len(cr['dropped'])))
    for d in cr['dropped']:
        w('  dropped  %s\n' % d)
    if report['ledgerProvidesRemoved']:
        w('ledger.provides removed (the copy no longer carries them): %s\n' % ', '.join(report['ledgerProvidesRemoved']))
    if report['probeFixturesNotCarried']:
        w('\nLayer probes whose fixtures this copy does not carry (compose the demo edition without them, or expect a FAIL):\n')
        for m in report['probeFixturesNotCarried']:
            w('  %s\n' % m)
    if report['otherLayersNameAbsentProducts']:
        w('\nOther layers name sample products this copy does not carry:\n')
        for t, layers in report['otherLayersNameAbsentProducts'].items():
            w('  %s (%s)\n' % (t, ', '.join(layers)))
    if report['residualSampleTokens']:
        w('\nSAMPLE TOKENS LEFT IN THE COPY:\n')
        for h in report['residualSampleTokens']:
            w('  %s\n' % h)
    prof = report['ids'].get('buyerSecondProfile')
    w('\nBuyer second profile (Switch account): %s\n' % ('AccessUser 100105 on %s' % prof['account'] if prof else 'none written'))
    if report.get('numbering'):
        w('\nhistory.numbering NOT written: %s\n' % report['numbering']['why'])
    if report['ignored']:
        w('\nIgnored, owned by a recipe:\n')
        for m in report['ignored']:
            w('  %-45s %s\n' % (m['member'], m['owner']))
    if report['warnings']:
        w('\nWarnings:\n')
        for m in report['warnings']:
            w('  %s\n' % m)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Rewrite a copy of the sample-data layer from a customer data file.')
    ap.add_argument('--input', required=True, help='the customer data file (customer-data.schema.json)')
    ap.add_argument('--out', required=True, help='the new layer folder, outside the Distribution\'s layers/')
    ap.add_argument('--name', help='layer name; must equal the --out folder name (default: that name)')
    ap.add_argument('--source', help='the sample-data layer to copy (default: the layer this script ships in)')
    ap.add_argument('--logins', default='stable', choices=('stable', 'input'),
                    help='stable keeps the persona user names the gate signs in as; input writes the input user names')
    ap.add_argument('--acts-for', metavar='CUSTOMER_NUMBER',
                    help='the account the buyer may act for (its second profile, Switch account): the same as actsFor on the buyer, '
                         'for a file that must stay free of generator-only members')
    ap.add_argument('--dry-run', action='store_true', help='report what would change and write nothing')
    ap.add_argument('--report', help='also write the report as JSON to this file')
    a = ap.parse_args(argv)
    try:
        report, _ = generate(a.input, a.out, a.name, a.source, a.dry_run, a.logins, a.acts_for)
    except Refused as e:
        sys.stderr.write('REFUSED. Nothing was written. Fix the input and run again:\n')
        for r in e.reasons:
            sys.stderr.write('  - %s\n' % r)
        return 2
    print_report(report)
    if a.report:
        Path(a.report).write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    sys.stdout.write('\n%s %s\n' % ('Dry run: nothing written to' if a.dry_run else 'Written:', Path(a.out).resolve()))
    return 0


if __name__ == '__main__':
    sys.exit(main())

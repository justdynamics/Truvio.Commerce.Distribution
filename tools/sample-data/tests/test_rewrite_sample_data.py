# -*- coding: utf-8 -*-
"""Tests for rewrite-sample-data.py on the fictional Vellmark fixture.

    python -B -m unittest discover -s tools/sample-data/tests -v

The generator lives outside layers/ on purpose: every file under a layer directory is part of the
layer tree hash the gate proved (tools/ci/Get-LayerTreeHash.ps1), so a tool there would un-prove the
layer. The tests write only into temporary folders, and this module stops Python writing bytecode for
the generator it imports.

The validator test runs tools/ci/Validate-Distribution.ps1, the script CI runs on every layer, on two
synthetic Distribution trees: one where the generated copy stands in place of sample-data, and a
control where an unmodified sample-data stands there under the same name. The copy passes when
every FAIL it gets the control gets too (the edition-level checks that expect a layer named
sample-data) and none names the copy. It needs pwsh; set SAMPLE_DATA_REWRITE_SKIP_VALIDATOR=1 to
skip it. TRUVIO_SKILLS_PATH, when set, lets the ledger checks run in both trees, and, when that checkout
carries skills/dw-demo-ledger/assets/recipe-input.schema.json, runs RecipeSchemaParity: the fixture passes
the recipe input schema, and the generator schema accepts every member it defines with the same
constraints. The fixture carries the members the recipes require and no actsFor, so the tests name the
buyer's second account with acts_for, as a recipe-valid file does with --acts-for.
"""
import contextlib
import copy
import importlib.util
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
TOOLS = Path(__file__).resolve().parent.parent
FIXTURE = TOOLS / 'testdata' / 'vellmark' / 'customer-data.json'
spec = importlib.util.spec_from_file_location('rewrite_sample_data', TOOLS / 'rewrite-sample-data.py')
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)
SOURCE = gen.find_source(None)
DIST = SOURCE.parent.parent
NAME = 'vellmark-data'
ACTS_FOR = 'C-10520'   # the fixture buyer may act for the second account (its Switch account profile)


def read_rows(layer, table):
    d = layer / 'merge' / '_sql' / table
    if not d.is_dir():
        return {}
    return gen.Table(table, d).rows


def keys_of(layer, table):
    p = layer / 'merge' / '_sql' / table / '_meta.yml'
    return set(gen.Meta(p.read_text(encoding='utf-8-sig')).keys) if p.is_file() else set()


def fixture():
    with open(FIXTURE, encoding='utf-8') as f:
        data = json.load(f)
    return data


def absolutise(data):
    """The input with every asset path absolute, so a modified copy can live in a temp folder."""
    base = FIXTURE.parent
    for p in data['catalogue']['products']:
        p['images'] = [str(base / i) for i in p['images']]
        for d in p.get('documents') or []:
            d['path'] = str(base / d['path'])
    b = data['brandCopy']
    b['logo'] = str(base / b['logo'])
    b['images'] = {k: str(base / v) for k, v in b['images'].items()}
    return data


# The sample's storefront facts the first real build on this route served for a catalogue of 87 products without
# variants (Foundry #1753): stat tiles, navigation promos, a Home band and the product page Features and FAQ.
SAMPLE_CLAIMS = ['Product masters', 'Variant combinations', 'Variants on every master', 'Pick a tier and a mode',
                 'Four groups, twelve capabilities', 'Commerce building blocks, named for what they do',
                 'Every product in the', 'Every master carries', 'variant axes', 'variant selector', 'Options resolved on the page',
                 'Do the options change the part number', 'install guide', 'revision', 'never out of stock', 'expected-delivery',
                 'assortment', 'quantity breaks start at a single unit', 'Quantity prices from one unit']


def field_values(layer):
    """(file, field, value) of every storefront copy field; the paragraph header (an admin label) is not a field."""
    for mode in ('merge', 'replace'):
        for p in sorted((layer / mode / '_content').rglob('*.yml')):
            for m in re.finditer(r'^\s+"([^"]+)": (".*")\r?$', p.read_text(encoding='utf-8-sig'), re.M):
                yield p.relative_to(layer).as_posix(), m.group(1), json.loads(m.group(2))


def content_hits(layer, phrases):
    return ['%s %s: %s' % (f, k, ph) for f, k, v in field_values(layer) for ph in phrases if ph.lower() in v.lower()]


def stat_tiles(layer):
    """The Home and About figures as served: [(number, label)] per page."""
    def runs(rel, field):
        text = (layer / 'merge/_content/Swift 2' / rel).read_text(encoding='utf-8-sig')
        return re.findall(r'>([^<]+)<', json.loads(re.search(r'^\s+"%s": (".*")\r?$' % field, text, re.M).group(1)))
    home = [(int(runs('Home/grid-row-9/%s.yml' % p, 'Subtitle')[0]), runs('Home/grid-row-9/%s.yml' % p, 'Title')[0])
            for p in ('paragraph-c1-11', 'paragraph-c2-12', 'paragraph-c3-13')]
    about = [(int(runs('About/grid-row-4/%s.yml' % p, 'Text')[0]), runs('About/grid-row-4/%s.yml' % p, 'Text')[1])
             for p in ('paragraph-c1-64', 'paragraph-c2-65', 'paragraph-c3-66')]
    return {'home': home, 'about': about}


def expected_counts(d):
    """The figures, counted from the data file by hand (not by the generator's code)."""
    cat, pr = d['catalogue'], d['prices']
    products, groups = len(cat['products']), len(cat['groups'])
    tops = sum(1 for g in cat['groups'] if not g.get('parent'))
    grp, ctr = len(pr.get('groupPrices') or []), len(pr.get('contracts') or [])
    rel = sum(len(v) for p in cat['products'] for v in (p.get('related') or {}).values())
    docs = sum(len(p.get('documents') or []) for p in cat['products'])
    third = (grp + ctr, 'Customer prices') if grp + ctr else (tops, 'Top-level groups')
    second = (grp, 'Customer-group prices') if grp else (ctr, 'Contract prices') if ctr else (products, 'List prices')
    last = (rel, 'Product relations') if rel else (docs, 'Product documents') if docs else (products, 'Products')
    fix = lambda n, l: (n, l[:-1] if n == 1 and l.endswith('s') else l)
    return {'home': [fix(products, 'Products'), fix(groups, 'Product groups'), fix(*third)],
            'about': [fix(tops, 'Top-level groups'), fix(*second), fix(*last)]}


class TreeChecks:
    """Checks every generated copy must pass: set out, data and report in setUpClass."""

    def rows(self, table):
        return read_rows(self.out, table)

    # --------------------------------------------------------------- referential consistency
    def test_every_reference_resolves(self):
        products = {r.get('ProductId'): r for r in self.rows('EcomProducts').values()}
        groups = {r.get('GroupId') for r in self.rows('EcomGroups').values()}
        for table, col in (('EcomPrices', 'PriceProductId'), ('EcomDetails', 'DetailProductId'), ('EcomOrderLines', 'OrderLineProductId'),
                           ('EcomCustomerFavoriteProducts', 'ProductId'), ('EcomStockUnit', 'StockUnitProductId'),
                           ('EcomProductCategoryFieldValue', 'FieldValueProductId'), ('EcomGroupProductRelation', 'GroupProductRelationProductId'),
                           ('EcomProductsRelated', 'ProductRelatedProductId'), ('EcomProductsRelated', 'ProductRelatedProductRelId')):
            for n, r in self.rows(table).items():
                self.assertIn(r.get(col), products, '%s/%s %s' % (table, n, col))
        for r in self.rows('EcomOrderLines').values():
            self.assertEqual(r.get('OrderLineProductNumber'), products[r.get('OrderLineProductId')].get('ProductNumber'))
        for r in self.rows('EcomStockUnit').values():
            self.assertEqual(r.get('StockUnitProductNumber'), products[r.get('StockUnitProductId')].get('ProductNumber'))
        for table, col in (('EcomGroupProductRelation', 'GroupProductRelationGroupId'), ('EcomGroupRelations', 'GroupRelationsGroupId'),
                           ('EcomGroupRelations', 'GroupRelationsParentId'), ('EcomShopGroupRelation', 'ShopGroupGroupId')):
            for n, r in self.rows(table).items():
                self.assertIn(r.get(col), groups, '%s/%s %s' % (table, n, col))
        tops = {'TCGRP-' + g['key'].upper() for g in self.data['catalogue']['groups'] if not g.get('parent')}
        self.assertEqual([n for n, r in self.rows('EcomGroupRelations').items() if r.get('GroupRelationsGroupId') in tops], [],
                         'a top group carries a group-relation row')
        orders = {r.get('OrderId'): r for r in self.rows('EcomOrders').values()}
        users = {r.get('AccessUserId') for r in self.rows('AccessUser').values()}
        lines_by_order = {}
        for r in self.rows('EcomOrderLines').values():
            self.assertIn(r.get('OrderLineOrderId'), orders)
            lines_by_order.setdefault(r.get('OrderLineOrderId'), []).append(r)
        for oid, o in orders.items():
            self.assertIn(o.get('OrderCustomerAccessUserId'), users)
            total = round(sum(l.get('OrderLinePriceWithVAT') for l in lines_by_order[oid]), 2)
            self.assertAlmostEqual(o.get('OrderPriceWithVAT'), total, places=2)
            self.assertEqual(o.get('OrderCurrencyCode'), 'USD')
        for r in self.rows('EcomCustomerFavoriteLists').values():
            self.assertIn(r.get('AccessUserId'), users)
        lists = {r.get('Id') for r in self.rows('EcomCustomerFavoriteLists').values()}
        for r in self.rows('EcomCustomerFavoriteProducts').values():
            self.assertIn(r.get('FavoriteListId'), lists)
        for table in ('AccessUserGroupRelation',):
            for r in self.rows(table).values():
                gid = r.get('AccessUserGroupRelationGroupId')
                self.assertTrue(gid in users or gid in (1325, 1292, 1270), gid)
                self.assertIn(r.get('AccessUserGroupRelationUserId'), users)
        cats = {r.get('CategoryId') for r in self.rows('EcomProductCategory').values()}
        fields = {(r.get('FieldCategoryId'), r.get('FieldId')) for r in self.rows('EcomProductCategoryField').values()}
        for r in self.rows('EcomProductCategoryFieldValue').values():
            self.assertIn((r.get('FieldValueFieldCategoryId'), r.get('FieldValueFieldId')), fields)
        for r in self.rows('EcomFieldDisplayGroupFields').values():
            _, cat, fid = r.get('FieldDisplayGroupFieldSystemName').split('|')
            self.assertIn((cat, fid), fields)
        for r in self.rows('EcomCompletionRules').values():
            for f in filter(None, (r.get('EcomCompletionRuleProductFields') or '').split(',')):
                _, cat, fid = f.split('|')
                self.assertIn((cat, fid), fields)
        for (cat, fid) in fields:
            if cat == 'reference_category':
                self.assertTrue(any(f == fid and c != cat for c, f in fields), 'mirror without its field: ' + fid)
        for r in self.rows('EcomGroups').values():
            if r.get('ProductCategoryId'):
                self.assertIn(r.get('ProductCategoryId'), cats)
        # every /Files/ path a row or a copy field points at is shipped by the copy (the logo and the icons come from Swift and the theme)
        shipped = {'/Files/' + p.relative_to(self.out / 'files').as_posix() for p in (self.out / 'files').rglob('*') if p.is_file()}
        for r in self.rows('EcomDetails').values():
            self.assertIn(r.get('DetailValue'), shipped)
        for r in products.values():
            for c in ('ProductImageSmall', 'ProductImageMedium', 'ProductImageLarge'):
                if r.get(c) is not None:
                    self.assertIn(r.get(c), shipped)
        for mode in ('merge', 'replace'):
            for p in (self.out / mode / '_content').rglob('*.yml'):
                for path in re.findall(r'/Files/Images/VellmarkFasteningSupply/[^"\\]+', p.read_text(encoding='utf-8-sig')):
                    self.assertIn(path, shipped, str(p))

    def test_inventories_agree_with_the_tree(self):
        man = json.loads((self.out / 'merge' / 'merge-manifest.json').read_text(encoding='utf-8'))
        lj = json.loads((self.out / 'layer.json').read_text(encoding='utf-8'))
        self.assertEqual(lj['name'], NAME)
        self.assertEqual(lj['kind'], 'sample-data')
        on_disk = {d.name for d in (self.out / 'merge' / '_sql').iterdir() if d.is_dir()}
        self.assertEqual({e['table'] for e in man['entries'] if e['providerType'] == 'SqlTable'}, on_disk)
        self.assertEqual(set(lj['fragmentTables']), on_disk)
        for e in man['entries']:
            listed = {f.split('/')[-1] for f in e['files']}
            disk = {p.name for p in (self.out / 'merge' / '_sql' / e['table']).iterdir()}
            self.assertEqual(listed, disk, e['table'])
            self.assertEqual(lj['costHints']['expectedRows'][e['table']], len(disk - {'_meta.yml'}))
        self.assertEqual(sorted(lj['files']), sorted(p.relative_to(self.out / 'files').as_posix() for p in (self.out / 'files').rglob('*') if p.is_file()))
        cfg = json.loads((self.out / 'config' / 'sample-data-2.4.json').read_text(encoding='utf-8'))
        self.assertEqual({p['table'] for p in cfg['predicates']}, on_disk)
        for cr in lj['configRows']:
            self.assertRegex(cr['where'], r"^ *[A-Za-z0-9_]+ *= *'[a-zA-Z0-9 ._-]*'( +AND +[A-Za-z0-9_]+ *= *'[a-zA-Z0-9 ._-]*')* *$")
        self.assertNotIn('pim.variants', lj['ledger']['provides'])
        self.assertIn('orders.quotes', lj['ledger']['provides'])



class GeneratedCopy(TreeChecks, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-'))
        cls.out = cls.tmp / 'a' / NAME
        cls.report, _ = gen.generate(FIXTURE, cls.out, acts_for=ACTS_FOR)
        cls.data = fixture()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    # --------------------------------------------------------------- determinism
    def test_two_runs_write_identical_trees(self):
        other = self.tmp / 'b' / NAME
        gen.generate(FIXTURE, other, acts_for=ACTS_FOR)

        def tree(root):
            return {p.relative_to(root).as_posix(): p.read_bytes() for p in sorted(root.rglob('*')) if p.is_file()}
        a, b = tree(self.out), tree(other)
        self.assertEqual(sorted(a), sorted(b))
        self.assertEqual([k for k in a if a[k] != b[k]], [])

    def test_dry_run_writes_nothing(self):
        target = self.tmp / 'dry' / NAME
        report, files = gen.generate(FIXTURE, target, dry_run=True, acts_for=ACTS_FOR)
        self.assertFalse(target.exists())
        self.assertEqual(sorted(files), sorted(p.relative_to(self.out).as_posix() for p in self.out.rglob('*') if p.is_file()))

    # --------------------------------------------------------------- no sample rows left
    def test_no_sample_names_numbers_or_accounts_outside_stable_keys(self):
        forbidden = set()
        for r in read_rows(SOURCE, 'EcomProducts').values():
            forbidden |= {r.get('ProductName'), r.get('ProductNumber')}
        for r in read_rows(SOURCE, 'AccessUser').values():
            forbidden |= {r.get('AccessUserName'), r.get('AccessUserCompany'), r.get('AccessUserEmail'), r.get('AccessUserCustomerNumber')}
        forbidden.discard(None)
        stable_logins = {'TruvioBuyer', 'TruvioCsr', 'TruvioAdmin'}
        hits = []
        for d in sorted((self.out / 'merge' / '_sql').iterdir()):
            if not d.is_dir():
                continue
            keys = keys_of(self.out, d.name)
            for n, row in read_rows(self.out, d.name).items():
                for c, raw in row.cols:
                    if c in keys:
                        continue
                    v = gen.parse_raw(raw)
                    if not isinstance(v, str):
                        continue
                    if c == 'AccessUserUserName' and v in stable_logins:
                        continue
                    if v in forbidden or re.search(r'(?i)truvio', v) or re.search(r'TC-1003?00|truvio-demo', v):
                        hits.append('%s/%s %s=%s' % (d.name, n, c, v))
        self.assertEqual(hits, [])
        self.assertEqual(self.report['residualSampleTokens'], [])

    def test_storefront_copy_and_files_carry_no_sample_brand(self):
        hits = []
        for mode in ('merge', 'replace'):
            for p in (self.out / mode / '_content').rglob('*.yml'):
                text = p.read_text(encoding='utf-8-sig')
                if re.search(r'(?i)truvio', text):
                    hits.append(str(p.relative_to(self.out)))
        self.assertEqual(hits, [])
        self.assertEqual([p for p in (self.out / 'files').rglob('*') if 'TruvioCommerce' in str(p)], [])
        self.assertFalse((self.out / 'tools').exists(), 'the copy ships no generator, fixture or Truvio tile tools')
        home = (self.out / 'merge/_content/Swift 2/Home/page.yml').read_text(encoding='utf-8-sig')
        self.assertIn('"metaTitle": "Vellmark Fastening Supply"', home)
        for footer in ('Desktop Footer/grid-row-2/paragraph-c1-24.yml', 'Mobile Footer/grid-row-4/paragraph-c1-13.yml'):
            text = (self.out / 'merge/_content/Swift 2/Header _ Footer' / footer).read_text(encoding='utf-8-sig')
            self.assertIn('Vellmark Fastening Supply. All rights reserved.', text)
        hero = (self.out / 'merge/_content/Swift 2/Home/grid-row-1/paragraph-c1-18.yml').read_text(encoding='utf-8-sig')
        self.assertIn('GroupID=TCGRP-FASTENERS', hero)
        self.assertIn('Browse Fasteners', hero)
        self.assertNotIn('TCGRP-PRODUCT-STRUCTURE', hero)

    def test_storefront_copy_states_no_sample_claim(self):
        """Foundry #1753: the sample's figures and capability claims never reach a customer's copy."""
        self.assertEqual(content_hits(self.out, SAMPLE_CLAIMS), [])
        self.assertEqual(self.report['residualSampleClaims'], [])
        self.assertEqual([w for w in self.report['warnings'] if 'copy slot' in w], [])

    def test_figures_are_counted_from_the_input(self):
        d = self.data
        counts = expected_counts(d)
        self.assertEqual(stat_tiles(self.out), counts)
        self.assertEqual({k: [(t['figure'], t['label']) for t in v] for k, v in self.report['copyFigures'].items()}, counts)

    def test_facet_names_follow_the_spec_field_labels(self):
        """Foundry #1754: the copy carries the storefront facet file with the customer's facet labels, Field and
        QueryParameter (and every other byte) as surface-swift ships them."""
        rel = 'repositories/TruvioCommerce/Products.facets'
        ours = (self.out / rel).read_text(encoding='utf-8-sig')
        theirs = (DIST / 'layers' / 'surface-swift' / rel).read_text(encoding='utf-8-sig')
        strip = lambda t: re.sub(r'<Facet Name="[^"]*"', '<Facet', t)
        self.assertEqual(strip(ours), strip(theirs))
        names = dict((f, n) for n, f in re.findall(r'<Facet Name="([^"]*)" Type="Field" Field="([^"]+)"', ours.split('-->')[-1]))
        labels = [f['label'] for g in self.data['catalogue']['groups'] for f in g.get('specFields', []) if f.get('facet')]
        self.assertEqual([names['MaterialClass_Facet'], names['LeadTime_Facet'], names['LanguageCoverage_Facet']], labels)
        self.assertEqual(names['AccountTerms_Facet'], 'Account terms', 'a facet the copy does not fill keeps its name')
        lj = json.loads((self.out / 'layer.json').read_text(encoding='utf-8'))
        self.assertIn('System/Repositories/TruvioCommerce/Products.facets', lj['repositories'])
        self.assertEqual({r['to'] for r in self.report['facetNames']}, set(labels))

    def test_unused_sample_rows_are_absent_not_inactive(self):
        for table in ('EcomVariantGroups', 'EcomVariantsOptions', 'EcomVariantGroupProductRelation', 'EcomVariantOptionsProductRelation',
                      'EcomProductItems', 'EcomAssortments', 'EcomAssortmentItems', 'EcomAssortmentGroupRelations', 'EcomAssortmentPermissions'):
            self.assertFalse((self.out / 'merge/_sql' / table).exists(), table)
        products = self.rows('EcomProducts')
        self.assertEqual(len(products), len(self.data['catalogue']['products']))
        self.assertTrue(all(r.get('ProductActive') is True for r in products.values()))
        self.assertTrue(all(r.get('ProductVariantId') == '' for r in products.values()))
        price_ids = {r.get('PriceId') for r in self.rows('EcomPrices').values()}
        sample_only = {r.get('PriceId') for r in read_rows(SOURCE, 'EcomPrices').values()} - price_ids
        self.assertTrue(all(not p.startswith(('TC-PRICE-VAR', 'TC-PRICE-GRPV', 'TC-PRICE-T', 'TC-PRICE-CONTRACT')) for p in price_ids))
        self.assertGreater(len(sample_only), 200)
        lj = json.loads((self.out / 'layer.json').read_text(encoding='utf-8'))
        for t in ('EcomVariantGroups', 'EcomProductItems', 'EcomAssortments'):
            self.assertNotIn(t, lj['fragmentTables'])
            self.assertNotIn(t, lj['costHints']['expectedRows'])
        cfg = json.loads((self.out / 'config' / 'sample-data-2.4.json').read_text(encoding='utf-8'))
        self.assertNotIn('EcomAssortments', {p['table'] for p in cfg['predicates']})

    # --------------------------------------------------------------- stable keys
    def test_stable_keys_are_intact(self):
        users = self.rows('AccessUser')
        for uid in ('100100', '100101', '100102', '100103', '100105', '100106'):
            self.assertIn(uid + '.yml', users)
        b, p2 = users['100101.yml'], users['100105.yml']
        self.assertEqual(b.get('AccessUserUserName'), 'TruvioBuyer')
        self.assertEqual(users['100102.yml'].get('AccessUserUserName'), 'TruvioCsr')
        self.assertEqual(users['100103.yml'].get('AccessUserUserName'), 'TruvioAdmin')
        self.assertTrue(b.get('AccessUserIsLogin'))
        self.assertFalse(p2.get('AccessUserIsLogin'))
        self.assertEqual(b.get('AccessUserUserName'), p2.get('AccessUserUserName'))
        self.assertNotEqual(b.get('AccessUserCustomerNumber'), p2.get('AccessUserCustomerNumber'))
        self.assertEqual(users['100100.yml'].get('AccessUserUserAndGroupType'), 'SystemAccount')
        self.assertEqual(b.get('AccessUserCustomerNumber'), users['100100.yml'].get('AccessUserCustomerNumber'))
        self.assertEqual(users['100103.yml'].get('AccessUserCustomerNumber'), b.get('AccessUserCustomerNumber'))
        rel = self.rows('AccessUserGroupRelation')
        for k in ('1325$$100101', '1292$$100102', '1270$$100103', '100100$$100101', '100100$$100103', '100106$$100105', '1325$$100105'):
            self.assertIn(k + '.yml', rel)
        self.assertIn('1292$$100100.yml', self.rows('AccessUserSecondaryRelation'))
        orders = self.rows('EcomOrders')
        o1 = orders['TCO-0001.yml']
        self.assertEqual((o1.get('OrderStateId'), o1.get('OrderCustomerAccessUserId')), ('OS2', 100101))
        self.assertIsNotNone(o1.get('OrderCompletedDate'))
        self.assertIn('TCO-0001-1.yml', self.rows('EcomOrderLines'))
        self.assertIn('PACK-RMA-0001.yml', self.rows('EcomRmas'))
        self.assertEqual(self.rows('EcomRmaOrderLines')['100301.yml'].get('RmaOrderLineOrderLineId'), 'TCO-0001-1')
        quotes = [r for r in orders.values() if r.get('OrderIsQuote')]
        self.assertTrue(quotes and all(q.get('OrderStateId') in ('QuotePending', 'QuoteSent', 'QuoteAccepted', 'QuoteRejected') for q in quotes))
        self.assertEqual(self.rows('EcomDetailsGroup')['100111.yml'].get('EcomDetailsGroupSystemName'), 'Manuals')
        self.assertEqual(self.rows('EcomFieldDisplayGroups')['100120.yml'].get('FieldDisplayGroupSystemName'), 'tc_specs')
        self.assertEqual(sorted(self.rows('EcomProductField')), sorted(read_rows(SOURCE, 'EcomProductField')))
        shop = self.rows('EcomShops')['TCSHOP-PIM.yml']
        self.assertEqual(shop.get('ShopName'), 'Vellmark PIM')
        level = self.rows('DynamicStructureLevels')['100171.yml']
        self.assertEqual(level.get('DynamicStructureLevelField'), 'DATAMODEL_Vellmark_PIM')
        self.assertIn('100170.yml', self.rows('DynamicStructures'))
        for table in ('EcomProducts', 'EcomGroups', 'EcomPrices', 'EcomDetails', 'EcomOrders', 'EcomProductsRelated'):
            for n in self.rows(table):
                self.assertTrue(n.startswith(('TC', 'tc')), '%s/%s is outside the TC* key family' % (table, n))
        self.assertEqual(self.report['outsidePredicateFence'], [])

    def test_kept_sample_rows_keep_their_identities(self):
        src = read_rows(SOURCE, 'EcomProducts')
        for n, r in self.rows('EcomProducts').items():
            if n in src:
                self.assertEqual(r.get('ProductAutoId'), src[n].get('ProductAutoId'))
                self.assertEqual(r.raw('ProductUniqueId'), src[n].raw('ProductUniqueId'))
        for table in os.listdir(self.out / 'merge' / '_sql'):
            meta = self.out / 'merge' / '_sql' / table / '_meta.yml'
            if not meta.is_file():
                continue
            m = gen.Meta(meta.read_text(encoding='utf-8-sig'))
            for col in m.identity:
                vals = [r.get(col) for r in self.rows(table).values()]
                self.assertEqual(len(vals), len(set(vals)), '%s.%s repeats an identity' % (table, col))

    def test_sample_rows_pass_the_fence_evaluator(self):
        cfg = json.loads((SOURCE / 'config' / 'sample-data-2.4.json').read_text(encoding='utf-8'))
        for pr in cfg['predicates']:
            test = gen.sql_where(pr['where'])
            rows = read_rows(SOURCE, pr['table'])
            self.assertTrue(rows)
            self.assertEqual([n for n, r in rows.items() if not test(r)], [], pr['where'])

    # --------------------------------------------------------------- the recipe members the generator uses
    def test_recipe_members_are_used_or_reported(self):
        prices = self.rows('EcomPrices')
        grp = [r for r in prices.values() if r.get('PriceId').startswith('TC-PRICE-GRP-')]
        self.assertTrue(grp)
        # prices.customerGroup names the buyer's account: the group price reaches its users only
        self.assertTrue(all(str(r.get('PriceUserGroupId')) == '100100' for r in grp), [r.get('PriceUserGroupId') for r in grp])
        states = {r.get('OrderReference'): r.get('OrderStateId') for r in self.rows('EcomOrders').values() if not r.get('OrderIsQuote')}
        self.assertEqual((states['PO-BS-2207'], states['PO-BS-2266'], states['PO-BS-2240']), ('OS2', 'OS1', 'OS3'))
        folder = [r for r in self.rows('EcomGroups').values() if r.get('GroupType') == 1]
        self.assertEqual([r.get('GroupName') for r in folder], ['Vellmark catalogue'])
        self.assertFalse(self.report['numbering']['written'])
        self.assertIn('EcomNumbers', self.report['numbering']['why'])
        self.assertFalse((self.out / 'merge' / '_sql' / 'EcomNumbers').exists())
        ignored = {m['member'] for m in self.report['ignored']}
        self.assertIn('history.numbering', ignored)
        self.assertIn('prices.buyer.passwordRef', ignored)
        self.assertEqual(self.report['ids']['buyerSecondProfile'], {'id': 100105, 'account': 'Tamsin and Orr Fit-Out'})

    # --------------------------------------------------------------- the CI validator
    @unittest.skipIf(os.environ.get('SAMPLE_DATA_REWRITE_SKIP_VALIDATOR') == '1', 'SAMPLE_DATA_REWRITE_SKIP_VALIDATOR=1')
    def test_ci_validator_passes_the_copy_where_it_passes_sample_data(self):
        pwsh = shutil.which('pwsh')
        if not pwsh:
            self.skipTest('pwsh not on PATH')
        if not (DIST / 'tools' / 'ci' / 'Validate-Distribution.ps1').is_file():
            self.skipTest('no Distribution validator beside the source layer')

        def synth(kind):
            root = self.tmp / ('synth-' + kind)
            for d in ('layers', 'editions', 'versions', 'contracts'):
                if (DIST / d).is_dir():
                    shutil.copytree(DIST / d, root / d)
            shutil.rmtree(root / 'layers' / 'sample-data')
            if kind == 'control':
                shutil.copytree(SOURCE, root / 'layers' / NAME)
                p = root / 'layers' / NAME / 'layer.json'
                lj = json.loads(p.read_text(encoding='utf-8'))
                lj['name'] = NAME
                p.write_text(json.dumps(lj, indent=2) + '\n', encoding='utf-8')
            else:
                shutil.copytree(self.out, root / 'layers' / NAME)
            args = "-RepoRoot '%s' -SpineBaseRef ''" % root
            skills = os.environ.get('TRUVIO_SKILLS_PATH')
            if skills:
                args += " -SkillsRoot '%s'" % skills
            cmd = "& '%s' %s; exit $LASTEXITCODE" % (DIST / 'tools' / 'ci' / 'Validate-Distribution.ps1', args)
            res = subprocess.run([pwsh, '-NoProfile', '-Command', cmd], capture_output=True, text=True, encoding='utf-8', errors='replace')
            lines = (res.stdout + res.stderr).replace(str(root), '<root>').replace(str(root).replace('\\', '/'), '<root>').splitlines()
            return [l.strip() for l in lines if '[FAIL]' in l], [l.strip() for l in lines if '[PASS]' in l]
        control_fail, control_pass = synth('control')
        fail, passed = synth('generated')
        self.assertEqual([f for f in fail if f not in control_fail], [], 'FAILs the copy gets and an unmodified sample-data does not')
        self.assertEqual([f for f in fail if "'%s'" % NAME in f], [])
        own = [p for p in passed if "layer '%s'" % NAME in p]
        self.assertGreaterEqual(len(own), 8, own)
        print('\nvalidator on the copy: %d PASS, %d FAIL (control: %d PASS, %d FAIL); %d checks name the copy'
              % (len(passed), len(fail), len(control_pass), len(control_fail), len(own)), file=sys.stderr)


class Refusals(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-r-'))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def run_with(self, mutate, **kw):
        data = absolutise(fixture())
        mutate(data)
        case = self.tmp / ('case%d' % len(list(self.tmp.iterdir())))
        case.mkdir()
        inp = case / 'customer-data.json'
        inp.write_text(json.dumps(data), encoding='utf-8')
        kw.setdefault('acts_for', ACTS_FOR)
        return gen.generate(inp, case / 'out' / NAME, **kw)

    def assertRefused(self, mutate, text, **kw):
        with self.assertRaises(gen.Refused) as cm:
            self.run_with(mutate, **kw)
        self.assertTrue(any(text in r for r in cm.exception.reasons), cm.exception.reasons)

    def test_out_inside_the_distribution_layers_is_refused(self):
        with self.assertRaises(gen.Refused) as cm:
            gen.generate(FIXTURE, SOURCE.parent / NAME, dry_run=True)
        self.assertIn('never writes the Distribution', cm.exception.reasons[0])

    def test_name_must_equal_folder(self):
        with self.assertRaises(gen.Refused):
            gen.generate(FIXTURE, self.tmp / 'x' / NAME, name='other-name', dry_run=True)

    def test_no_buyer(self):
        def m(d):
            d['users.accounts']['groups'][0]['users'][0].update(role='user')
            del d['prices']['buyer'], d['history']['buyer']
        self.assertRefused(m, 'exactly one user needs role buyer')

    def test_recipe_buyer_names_the_buyer_when_no_role_does(self):
        def m(d):
            d['users.accounts']['groups'][0]['users'][0].update(role='user')
        report, files = self.run_with(m, dry_run=True)
        self.assertEqual(report['ids']['users']['edda.marlowe@brannoch.example'], 100101)

    def test_one_account_breaks_the_second_profile(self):
        def m(d):
            g = d['users.accounts']['groups']
            del g[1]
            d['history']['orders'] = [o for o in d['history']['orders'] if 'user' not in o]
            d['prices']['contracts'] = [c for c in d['prices']['contracts'] if c['account'] != 'C-10520']
        self.assertRefused(m, 'guarantees the buyer a second profile', acts_for=None)

    def test_shared_customer_number(self):
        self.assertRefused(lambda d: d['users.accounts']['groups'][1].update(customerNumber='C-10410'), 'share a customer number')

    def test_no_csr(self):
        self.assertRefused(lambda d: d['users.accounts']['groups'].pop(2), 'customer service representative')

    def test_admin_on_the_wrong_account(self):
        def m(d):
            g = d['users.accounts']['groups']
            admin = g[0]['users'].pop(1)
            g[1]['users'].insert(0, admin)
        self.assertRefused(m, 'not on the buyer')

    def test_missing_image(self):
        self.assertRefused(lambda d: d['catalogue']['products'][0]['images'].append(str(self.tmp / 'nope.png')), 'does not exist')

    def test_svg_product_image(self):
        def m(d):
            d['catalogue']['products'][0]['images'][0] = d['brandCopy']['logo']
        self.assertRefused(m, 'no SVG decoder')


    def test_order_owned_by_the_csr(self):
        self.assertRefused(lambda d: d['history']['orders'][1].update(user='ines.okafor@vellmark.example'), 'invisible to every persona')

    def test_no_completed_buyer_order(self):
        def m(d):
            for o in d['history']['orders']:
                o['state'] = 'open'
        self.assertRefused(m, 'TCO-0001')

    def test_empty_group(self):
        self.assertRefused(lambda d: d['catalogue']['groups'].append({'key': 'empty', 'name': 'Empty', 'parent': 'tools'}), 'no product sits in it')

    def test_unknown_currency(self):
        self.assertRefused(lambda d: d['prices'].update(currency='XYZ'), 'EcomCurrencies')

    def test_schema_violation(self):
        self.assertRefused(lambda d: d['catalogue']['products'][0].pop('listPrice'), 'missing listPrice')

    def test_account_without_customer_number_fails_the_schema(self):
        self.assertRefused(lambda d: d['users.accounts']['groups'][1].pop('customerNumber'), 'missing customerNumber')

    # --------------------------------------------------------------- one key per row
    def test_contract_and_group_prices_with_a_quantity(self):
        def m(d):
            d['prices']['contracts'].append({'account': 'C-10410', 'product': 'VF-HB-M10-60', 'quantity': 10, 'amount': 31.0})
            d['prices']['groupPrices'].append({'product': 'VF-IT-18V', 'quantity': 3, 'amount': 115.0})
        report, files = self.run_with(m, dry_run=True)
        n = report['ids']['products']['VF-HB-M10-60'][len('TCPROD'):]
        g = report['ids']['products']['VF-IT-18V'][len('TCPROD'):]
        names = {k.split('/')[-1] for k in files if k.startswith('merge/_sql/EcomPrices/')}
        for key in ('TC-PRICE-CTR-%s-A1' % n, 'TC-PRICE-CTR-%s-A1-Q10' % n, 'TC-PRICE-GRP-%s' % g, 'TC-PRICE-GRP-%s-Q3' % g):
            self.assertIn(key + '.yml', names)

    def test_two_contract_rows_for_one_rung(self):
        def m(d):
            d['prices']['contracts'].append({'account': 'C-10410', 'product': 'VF-HB-M10-60', 'quantity': 1, 'amount': 30.0})
        self.assertRefused(m, 'prices.contracts[0] and prices.contracts[3]')

    def test_a_repeated_relation_names_both_rows(self):
        def m(d):
            d['catalogue']['products'][0]['related']['accessories'].append('VF-HN-M10')
        self.assertRefused(m, 'related.accessories[0] and catalogue.products VF-HB-M10-60 related.accessories[1]')

    def test_a_repeated_favourite_names_both_rows(self):
        self.assertRefused(lambda d: d['history']['favourites'][0]['products'].append('VF-HN-M10'),
                           'history.favourites[0].products[1] and history.favourites[0].products[4]')

    def test_two_groups_with_one_name(self):
        self.assertRefused(lambda d: d['users.accounts']['groups'][1].update(name='Brannoch Shipwrights'), 'two groups are named')

    # --------------------------------------------------------------- recipe members that contradict the copy
    def test_list_price_contradiction(self):
        self.assertRefused(lambda d: d['prices']['listPrices'][0].update(amount=40), 'make them equal')

    def test_list_price_of_an_unknown_product(self):
        self.assertRefused(lambda d: d['prices']['listPrices'].append({'product': 'VF-NOPE', 'amount': 1}), 'not a catalogue product number')

    def test_customer_group_that_is_not_an_account(self):
        self.assertRefused(lambda d: d['prices'].update(customerGroup='Trade customers'), 'is not an account in users.accounts')

    def test_customer_group_without_the_buyer(self):
        self.assertRefused(lambda d: d['prices'].update(customerGroup='Tamsin and Orr Fit-Out'), 'not a direct member of prices.customerGroup')

    def test_recipe_buyer_is_another_user(self):
        self.assertRefused(lambda d: d['history']['buyer'].update(userName='rufus.pell@tamsinorr.example'), 'One file, one buyer')

    def test_price_buyer_on_another_account(self):
        self.assertRefused(lambda d: d['prices']['buyer'].update(account='C-10520'), 'prices.buyer.account')

    def test_another_storefront_shop(self):
        self.assertRefused(lambda d: d['history'].update(shop='SHOP7'), 'history.shop: SHOP7')

    def test_another_pim_shop(self):
        self.assertRefused(lambda d: d.update(build={'pimShop': 'SHOP19'}), 'build.pimShop: SHOP19')

    def test_unknown_order_state(self):
        self.assertRefused(lambda d: d['history']['orderStates'][0].update(name='Shipped'), 'is not an order state')

    def test_completed_must_stay_the_delivered_state(self):
        def m(d):
            d['history']['orderStates'] = [{'state': 'completed', 'name': 'New'}, {'state': 'open', 'name': 'Completed'}]
        self.assertRefused(m, 'deliveredOrder')

    # --------------------------------------------------------------- the buyer's second profile
    def test_acts_for_in_the_file_equals_the_flag(self):
        def m(d):
            d['users.accounts']['groups'][0]['users'][0]['actsFor'] = ['C-10520']
        _, files = self.run_with(m, dry_run=True, acts_for=None)
        _, flagged = self.run_with(lambda d: None, dry_run=True)
        self.assertEqual(sorted(files), sorted(flagged))
        # layer.json differs only in the input digest it records
        self.assertEqual([k for k in files if k != 'layer.json' and files[k] != flagged[k]], [])

    def test_acts_for_on_a_user_who_is_not_the_buyer(self):
        self.assertRefused(lambda d: d['users.accounts']['groups'][1]['users'][0].update(actsFor=['C-10410']), 'only the buyer gets a second profile')

    def test_acts_for_the_buyers_own_account(self):
        self.assertRefused(lambda d: None, 'own account', acts_for='C-10410')

    def test_acts_for_an_unknown_account(self):
        self.assertRefused(lambda d: None, 'is not the customerNumber of an account', acts_for='C-99999')

    def test_acts_for_flag_and_file_disagree(self):
        def m(d):
            d['users.accounts']['groups'].insert(2, {'name': 'Halden Marine Works', 'kind': 'account', 'customerNumber': 'C-10630', 'users': []})
            d['users.accounts']['groups'][0]['users'][0]['actsFor'] = ['C-10630']
        self.assertRefused(m, 'disagree')

    def test_no_account_named_for_the_second_profile(self):
        self.assertRefused(lambda d: None, 'names no other account to act for', acts_for=None)

    def test_every_recipe_section_is_accepted_and_reported_ignored(self):
        def m(d):
            d['build'] = {'areaId': 1, 'defaultLanguage': 'en-US', 'pimShop': 'TCSHOP-PIM'}
            d['brand'] = {'id': 'vellmark'}
            d['debrand'] = {'forbidden': [{'text': 'Old name', 'replacement': 'Vellmark'}]}
            d['content.pages'] = {'pages': [{'menuText': 'About us', 'urlName': 'about-us', 'itemType': 'Swift-v2_Page'}]}
            d['pim.workflow'] = {'name': 'Review', 'states': [{'name': 'Draft'}]}
            d['checkout'] = {'country': 'US', 'language': 'en-US', 'methods': []}
            d['catalogue']['assortmentIds'] = ['A1']
            d['history']['reset'] = True
        report, _ = self.run_with(m, dry_run=True)
        ignored = {x['member'] for x in report['ignored']}
        for member in ('build.areaId', 'build.defaultLanguage', 'brand', 'debrand', 'content.pages', 'pim.workflow', 'checkout',
                       'catalogue.assortmentIds', 'history.reset', 'history.numbering'):
            self.assertIn(member, ignored)


class MoreRowsThanTheSample(unittest.TestCase):
    """60 products (beyond the 54 free product slots), a third account and extra users."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-m-'))
        data = absolutise(fixture())
        base = data['catalogue']['products']
        extra = []
        for i in range(60 - len(base)):
            p = copy.deepcopy(base[i % len(base)])
            p['number'] = 'VF-EXTRA-%03d' % i
            p['name'] = 'Extra item %03d' % i
            p['related'] = {}
            p.pop('documents', None)
            extra.append(p)
        data['catalogue']['products'] = base + extra
        data['users.accounts']['groups'].insert(2, {'name': 'Halden Marine Works', 'kind': 'account', 'customerNumber': 'C-10630',
                                                     'users': [{'userName': 'mira.halden@halden.example', 'name': 'Mira Halden'},
                                                               {'userName': 'otto.brand@halden.example', 'name': 'Otto Brand', 'role': 'accountAdmin'}]})
        data['users.accounts']['groups'][3]['users'].append({'userName': 'sam.reyes@vellmark.example', 'name': 'Sam Reyes'})
        data['history']['favourites'].append({'user': 'mira.halden@halden.example', 'name': 'Halden basics', 'products': ['VF-EXTRA-001']})
        inp = cls.tmp / 'customer-data.json'
        inp.write_text(json.dumps(data), encoding='utf-8')
        cls.out = cls.tmp / 'out' / NAME
        cls.report, _ = gen.generate(inp, cls.out, logins='input', acts_for=ACTS_FOR)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_extra_products_take_keys_above_the_sample(self):
        ids = sorted(n.split('$$')[0] for n in read_rows(self.out, 'EcomProducts'))
        self.assertEqual(len(ids), 60)
        self.assertIn('TCPROD1001', ids)
        self.assertTrue(set(ids).isdisjoint({'TCPROD0001', 'TCPROD0003', 'TCPROD0020', 'TCPROD0042', 'TCPROD0046', 'TCPROD0052', 'TCPROD0061'}))
        self.assertIn('101201.yml', read_rows(self.out, 'EcomStockUnit'))

    def test_extra_accounts_and_users_widen_the_fences(self):
        users = read_rows(self.out, 'AccessUser')
        self.assertIn('100110.yml', users)
        self.assertEqual(users['100110.yml'].get('AccessUserName'), 'Halden Marine Works')
        self.assertEqual(max(int(n[:-4]) for n in users), 100114)
        cfg = json.loads((self.out / 'config' / 'sample-data-2.4.json').read_text(encoding='utf-8'))
        where = {p['table']: p['where'] for p in cfg['predicates']}
        self.assertEqual(where['AccessUser'], 'AccessUserId >= 100100 AND AccessUserId <= 100114')
        self.assertIn('100110', where['AccessUserSecondaryRelation'])
        self.assertEqual(self.report['outsidePredicateFence'], [])
        self.assertIn('1292$$100110.yml', read_rows(self.out, 'AccessUserSecondaryRelation'))

    def test_logins_input_writes_the_customer_user_names(self):
        users = read_rows(self.out, 'AccessUser')
        self.assertEqual(users['100101.yml'].get('AccessUserUserName'), 'edda.marlowe@brannoch.example')
        self.assertEqual(users['100105.yml'].get('AccessUserUserName'), 'edda.marlowe@brannoch.example')
        self.assertEqual(self.report['residualSampleTokens'], [])

    def test_logins_input_satisfies_what_the_gate_legs_read(self):
        """The Foundry reads the personas the way Get-SampleDataPersona (tools/harness/Set-PersonaCredential.ps1) does:
        each base contract role with an AccessUser id counts when the shipped row exists, and its user name is the
        row's AccessUserUserName line, matched with the same two expressions. gate.ps1 Step 3c2 then requires
        config layers.buyerUsername to equal the buyer's, and the Switch account profile shares it."""
        contract = json.loads((DIST / 'layers' / 'base' / 'base.contract.json').read_text(encoding='utf-8-sig'))
        guaranteed = contract['sampleData']['guaranteedRows']
        expected = {'buyer': 'edda.marlowe@brannoch.example', 'csr': 'ines.okafor@vellmark.example', 'accountAdmin': 'corin.haskett@brannoch.example'}
        for role, name in expected.items():
            row = self.out / 'merge' / '_sql' / 'AccessUser' / ('%d.yml' % guaranteed[role]['id'])
            self.assertTrue(row.is_file(), role)
            lines = [l for l in row.read_text(encoding='utf-8').splitlines() if re.match(r'^\s*"?AccessUserUserName"?\s*:', l)]
            self.assertEqual(len(lines), 1, role)
            m = re.search(r':\s*"?([^"]+)"?\s*$', lines[0])
            self.assertEqual(m.group(1).strip(), name, role)
        users = read_rows(self.out, 'AccessUser')
        buyer, profile = users['%d.yml' % guaranteed['buyer']['id']], users['100105.yml']
        self.assertTrue(buyer.get('AccessUserIsLogin'))
        self.assertFalse(profile.get('AccessUserIsLogin'))
        self.assertEqual(profile.get('AccessUserUserName'), buyer.get('AccessUserUserName'))
        self.assertNotEqual(profile.get('AccessUserCustomerNumber'), buyer.get('AccessUserCustomerNumber'))
        stable = {'TruvioBuyer', 'TruvioCsr', 'TruvioAdmin'}
        self.assertEqual([n for n, r in users.items() if r.get('AccessUserUserName') in stable], [])
        # a configRow that pins a stable user name is rewritten or dropped, never left naming a user the copy lacks
        lj = json.loads((self.out / 'layer.json').read_text(encoding='utf-8'))
        self.assertEqual([c['where'] for c in lj['configRows'] if any(x in c['where'] for x in stable)], [])


class LiftedLimits(TreeChecks, unittest.TestCase):
    """Six top groups (the sample carries four product categories), nine spec fields on one top group (its category
    carries seven field slots) and a product without images."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-l-'))
        data = absolutise(fixture())
        groups, products = data['catalogue']['groups'], data['catalogue']['products']
        fasteners = groups[0]
        for k in ('finish', 'thread', 'headStyle', 'grade'):
            fasteners['specFields'].append({'key': k, 'label': k.capitalize()})
        products[0]['specs'].update(finish='Plain', thread='Coarse', headStyle='Hex', grade='A4-70')
        for i, (key, name) in enumerate((('sealants', 'Sealants'), ('safety', 'Safety Wear'), ('storage', 'Storage'))):
            groups.append({'key': key, 'name': name, 'specFields': [{'key': 'volume', 'label': 'Volume', 'facet': True}, {'key': 'colour', 'label': 'Colour'}]})
            p = copy.deepcopy(products[1])
            p.update(number='VF-%s-1' % key.upper(), name='%s item' % name, group=key, specs={'volume': '%d ml' % (100 * (i + 1)), 'colour': 'Grey'})
            p.pop('related', None)
            if key == 'storage':
                p.pop('images')
            products.append(p)
        cls.data = data
        inp = cls.tmp / 'customer-data.json'
        inp.write_text(json.dumps(data), encoding='utf-8')
        cls.out = cls.tmp / 'out' / NAME
        cls.report, _ = gen.generate(inp, cls.out, acts_for=ACTS_FOR)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_every_top_group_has_a_data_model_and_a_category(self):
        groups = {r.get('GroupId'): r for r in self.rows('EcomGroups').values()}
        models = [r for r in groups.values() if r.get('GroupType') == 2]
        self.assertEqual(len(models), 6)
        cats = {r.get('CategoryId') for r in self.rows('EcomProductCategory').values()}
        rules = {str(r.get('EcomCompletionRuleId')) for r in self.rows('EcomCompletionRules').values()}
        for m in models:
            self.assertIn(m.get('ProductCategoryId'), cats)
            self.assertIn(m.get('GroupCompletionRules'), rules)
        self.assertEqual(len(cats), 6)
        self.assertIn('TCDM-SAFETY', groups)
        self.assertIn('tc_safety', cats)
        folder = next(r.get('GroupId') for r in groups.values() if r.get('GroupType') == 1)
        parents = {r.get('GroupRelationsGroupId'): r.get('GroupRelationsParentId') for r in self.rows('EcomGroupRelations').values()}
        self.assertTrue(all(parents.get(m.get('GroupId')) == folder for m in models))
        shops = {r.get('ShopGroupGroupId'): r.get('ShopGroupShopId') for r in self.rows('EcomShopGroupRelation').values()}
        self.assertTrue(all(shops.get(m.get('GroupId')) == 'TCSHOP-PIM' for m in models))
        cfg = json.loads((self.out / 'config' / 'sample-data-2.4.json').read_text(encoding='utf-8'))
        where = {p['table']: p['where'] for p in cfg['predicates']}
        self.assertEqual(where['EcomCompletionRules'], 'EcomCompletionRuleId >= 100160 AND EcomCompletionRuleId <= 100165')
        self.assertEqual(self.report['outsidePredicateFence'], [])

    def test_spec_fields_beyond_the_slots_are_new_fields(self):
        fields = {(r.get('FieldCategoryId'), r.get('FieldId')) for r in self.rows('EcomProductCategoryField').values()}
        for fid in ('tcFastenersHeadStyle', 'tcFastenersGrade'):
            self.assertTrue(any(f == fid and c != 'reference_category' for c, f in fields), fid)
            self.assertIn(('reference_category', fid), fields)
        rule = next(r for r in self.rows('EcomCompletionRules').values() if r.get('EcomCompletionRuleName') == 'Fasteners data complete')
        self.assertEqual(len(rule.get('EcomCompletionRuleProductFields').split(',')), 9)
        display = [r.get('FieldDisplayGroupFieldSystemName') for r in self.rows('EcomFieldDisplayGroupFields').values()]
        self.assertEqual(len(display), 9 + 3 + 3 + 3 * 2)

    def test_a_product_without_images(self):
        pid = self.report['ids']['products']['VF-STORAGE-1']
        product = next(r for r in self.rows('EcomProducts').values() if r.get('ProductId') == pid)
        self.assertIsNone(product.get('ProductImageSmall'))
        self.assertEqual([r for r in self.rows('EcomDetails').values() if r.get('DetailProductId') == pid], [])


class NoGuaranteedProfile(unittest.TestCase):
    """A source layer with no base contract beside it guarantees no Switch account profile: the generator writes none
    unless the input names the account, and never picks one."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-p-'))
        cls.src = cls.tmp / 'src' / 'sample-data'
        shutil.copytree(SOURCE, cls.src, ignore=shutil.ignore_patterns('files', 'tools'))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_no_second_profile_without_acts_for(self):
        report, files = gen.generate(FIXTURE, self.tmp / 'out' / NAME, source=str(self.src), dry_run=True)
        self.assertIsNone(report['ids']['buyerSecondProfile'])
        self.assertNotIn('merge/_sql/AccessUser/100105.yml', files)
        self.assertNotIn('merge/_sql/AccessUserGroupRelation/1325$$100105.yml', files)
        self.assertTrue(any('No second profile' in w for w in report['warnings']))
        lj = json.loads(files['layer.json'].decode('utf-8'))
        self.assertEqual([c for c in lj['configRows'] if '100105' in c['where']], [])

    def test_acts_for_still_writes_it(self):
        report, files = gen.generate(FIXTURE, self.tmp / 'out2' / NAME, source=str(self.src), dry_run=True, acts_for=ACTS_FOR)
        self.assertEqual(report['ids']['buyerSecondProfile']['id'], 100105)
        self.assertIn('merge/_sql/AccessUser/100105.yml', files)


class PlainCatalogue(unittest.TestCase):
    """A catalogue with list prices only, no relations, documents, quotes or favourite lists (the shape of the first
    real build on this route, minus what it did carry): the copy names none of those and counts its figures from
    what is left."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-plain-'))
        data = absolutise(fixture())
        for p in data['catalogue']['products']:
            p.pop('related', None)
            p.pop('documents', None)
        for k in ('tiers', 'groupPrices', 'contracts', 'customerGroup'):
            data['prices'].pop(k, None)
        for k in ('quotes', 'favourites', 'carts'):
            data['history'].pop(k, None)
        cls.data = data
        inp = cls.tmp / 'customer-data.json'
        inp.write_text(json.dumps(data), encoding='utf-8')
        cls.out = cls.tmp / 'out' / NAME
        cls.report, _ = gen.generate(inp, cls.out, acts_for=ACTS_FOR)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_no_claim_of_what_the_copy_does_not_carry(self):
        self.assertEqual(self.report['residualSampleClaims'], [])
        absent = ['quantity', 'contract', 'customer-group', 'quote', 'favourite', 'document', 'related product', 'relation']
        self.assertEqual(content_hits(self.out, SAMPLE_CLAIMS + absent), [])
        lj = json.loads((self.out / 'layer.json').read_text(encoding='utf-8'))
        for fn in ('pim.documents', 'pim.product-relations', 'commerce.customer-prices', 'commerce.quantity-prices', 'orders.quotes', 'orders.favorite-lists'):
            self.assertNotIn(fn, lj['ledger']['provides'])

    def test_figures_fall_back_to_what_the_file_counts(self):
        counts = expected_counts(self.data)
        self.assertEqual(counts['home'][2], (3, 'Top-level groups'))
        self.assertEqual(counts['about'][1:], [(12, 'List prices'), (12, 'Products')])
        self.assertEqual(stat_tiles(self.out), counts)

    def test_the_product_page_keeps_its_two_paragraphs(self):
        """Features and FAQ are rewritten, never emptied: the PDP grid rows keep their paragraph."""
        values = {(f, k): v for f, k, v in field_values(self.out)}
        features = values[('replace/_content/Swift 2/Shop/Product Details/grid-row-10/paragraph-c1-20.yml', 'Text')]
        faq = values[('replace/_content/Swift 2/Shop/Product Details/grid-row-11/paragraph-c1-21.yml', 'Text')]
        self.assertGreaterEqual(features.count('<li>'), 3)
        self.assertGreaterEqual(faq.count('<p><strong>'), 2)


class CommandLine(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-cli-'))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_report_into_a_folder_that_does_not_exist(self):
        report = self.tmp / 'reports' / 'new' / 'report.json'
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = gen.main(['--input', str(FIXTURE), '--out', str(self.tmp / 'copy' / NAME), '--acts-for', ACTS_FOR,
                             '--dry-run', '--report', str(report)])
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(report.read_text(encoding='utf-8'))['layer'], NAME)

    def test_list_prices_naming_fewer_products_prices_the_copy_the_same(self):
        """prices.listPrices restates listPrice for the recipes. A product it does not name is priced from its listPrice
        all the same, so the generator does not report it (Foundry #1753)."""
        def run(case, mutate):
            data = absolutise(fixture())
            mutate(data)
            d = self.tmp / case
            d.mkdir()
            (d / 'customer-data.json').write_text(json.dumps(data), encoding='utf-8')
            return gen.generate(d / 'customer-data.json', d / 'out' / NAME, dry_run=True, acts_for=ACTS_FOR)

        def name_all(d):
            d['prices']['listPrices'] = [{'product': p['number'], 'amount': p['listPrice']} for p in d['catalogue']['products']]
        full_report, full = run('full', name_all)
        few_report, few = run('few', lambda d: d['prices'].update(listPrices=d['prices']['listPrices'][:1]))
        priced = [k for k in full if k.startswith(('merge/_sql/EcomPrices/', 'merge/_sql/EcomProducts/'))]
        self.assertTrue(priced)
        self.assertEqual(sorted(priced), sorted(k for k in few if k.startswith(('merge/_sql/EcomPrices/', 'merge/_sql/EcomProducts/'))))
        self.assertEqual([k for k in priced if full[k] != few[k]], [])
        self.assertEqual([w for w in few_report['warnings'] if 'listPrices' in w], [])


def _recipe_schema_path():
    root = os.environ.get('TRUVIO_SKILLS_PATH')
    if not root:
        return None
    p = Path(root) / 'skills' / 'dw-demo-ledger' / 'assets' / 'recipe-input.schema.json'
    return p if p.is_file() else None


@unittest.skipIf(_recipe_schema_path() is None, 'TRUVIO_SKILLS_PATH has no skills/dw-demo-ledger/assets/recipe-input.schema.json')
class RecipeSchemaParity(unittest.TestCase):
    """The generator schema accepts every member the recipe input schema defines, with the same constraints, except the
    two documented generator-only additions; and the fixture is one file both read."""

    # a member only the generator reads (actsFor) is not a difference here: the generator may read more
    EXTENSIONS = {'$.catalogue.products[].required', '$.catalogue.products[].images.minItems'}
    RECIPE_OWNED = {'$.brand', '$.debrand', '$.content.pages', '$.pim.workflow', '$.checkout'}

    @classmethod
    def setUpClass(cls):
        cls.recipe = json.loads(_recipe_schema_path().read_text(encoding='utf-8-sig'))
        cls.ours = json.loads((TOOLS / 'customer-data.schema.json').read_text(encoding='utf-8-sig'))

    def test_the_fixture_passes_the_recipe_input_schema(self):
        self.assertEqual(gen.schema_errors(fixture(), self.recipe, self.recipe), [])

    def test_every_recipe_member_is_accepted_with_its_constraints(self):
        def resolve(node, root):
            while isinstance(node, dict) and '$ref' in node:
                target = root
                for part in node['$ref'].lstrip('#/').split('/'):
                    target = target[part]
                node = target
            return node
        diffs = []

        def walk(r, g, path):
            r, g = resolve(r, self.recipe), resolve(g, self.ours) if g is not None else None
            if path in self.RECIPE_OWNED:
                if g is None or g.get('type') != 'object':
                    diffs.append(path + ': not accepted')
                return
            if g is None:
                diffs.append(path + ': not declared')
                return
            for k in ('type', 'const', 'enum', 'minLength', 'maxLength', 'pattern', 'minimum', 'exclusiveMinimum', 'minItems', 'maxItems'):
                if r.get(k) != g.get(k):
                    diffs.append('%s.%s' % (path, k))
            if sorted(r.get('required', [])) != sorted(g.get('required', [])):
                diffs.append(path + '.required')
            if r.get('then') != g.get('then'):
                diffs.append(path + '.then')
            for k, v in r.get('properties', {}).items():
                walk(v, g.get('properties', {}).get(k), path + '.' + k)
            if 'items' in r:
                walk(r['items'], g.get('items'), path + '[]')
        walk(self.recipe, self.ours, '$')
        self.assertEqual(sorted(set(diffs) - self.EXTENSIONS), [])


if __name__ == '__main__':
    unittest.main()

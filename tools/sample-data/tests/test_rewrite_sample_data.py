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
skip it. TRUVIO_SKILLS_PATH, when set, lets the ledger checks run in both trees.
"""
import copy
import importlib.util
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


class GeneratedCopy(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='sdrw-'))
        cls.out = cls.tmp / 'a' / NAME
        cls.report, _ = gen.generate(FIXTURE, cls.out)
        cls.data = fixture()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def rows(self, table):
        return read_rows(self.out, table)

    # --------------------------------------------------------------- determinism
    def test_two_runs_write_identical_trees(self):
        other = self.tmp / 'b' / NAME
        gen.generate(FIXTURE, other)

        def tree(root):
            return {p.relative_to(root).as_posix(): p.read_bytes() for p in sorted(root.rglob('*')) if p.is_file()}
        a, b = tree(self.out), tree(other)
        self.assertEqual(sorted(a), sorted(b))
        self.assertEqual([k for k in a if a[k] != b[k]], [])

    def test_dry_run_writes_nothing(self):
        target = self.tmp / 'dry' / NAME
        report, files = gen.generate(FIXTURE, target, dry_run=True)
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
        self.assertRefused(lambda d: d['users.accounts']['groups'][0]['users'][0].update(role='user'), 'exactly one user needs role buyer')

    def test_one_account_breaks_the_second_profile(self):
        def m(d):
            g = d['users.accounts']['groups']
            del g[1]
            d['history']['orders'] = [o for o in d['history']['orders'] if 'user' not in o]
            d['prices']['contracts'] = [c for c in d['prices']['contracts'] if c['account'] != 'C-10520']
        self.assertRefused(m, 'second profile')

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

    def test_too_many_top_groups(self):
        def m(d):
            for i in range(2):
                d['catalogue']['groups'].append({'key': 'extra%d' % i, 'name': 'Extra %d' % i})
                d['catalogue']['products'].append(dict(d['catalogue']['products'][0], number='VF-X-%d' % i, group='extra%d' % i, specs={}, related={}))
        self.assertRefused(m, 'product categories')

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
        cls.report, _ = gen.generate(inp, cls.out, logins='input')

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


if __name__ == '__main__':
    unittest.main()

# Changelog — digital-asset-portal/1.0

## 1.0.5

### The MOBILE footer navigation renders on Vertical.cshtml (Foundry #728)

`Header _ Footer/Mobile Footer/grid-row-2/paragraph-c1-2.yml` shipped
`template: Horizontal.cshtml`. A horizontal list of root pages cannot shrink, and Chrome widens
the LAYOUT VIEWPORT to fit content that cannot: measured on the sibling report, four of six
pages rendered at `body.scrollWidth 652 / innerWidth 652` against a requested 390, i.e. visibly
zoomed out on a phone. The shipped choice only ever survived because the source baseline this
area was captured from has a SINGLE root page, so the row happened to fit; any real site with
more than one breaks it. The two desktop footer navigations in the same area already use
`Vertical.cshtml`, so this repoints the mobile one onto the template its own siblings use.

The measurement half of that issue belongs to the harness and is NOT in this repo: an overflow
check that compares `body.scrollWidth` with `window.innerWidth` can never fire once Chrome has
widened the viewport, because the two are then equal by construction - the number that moved is
`innerWidth`, and the assertion has to read it against the REQUESTED width. With
`Horizontal.cshtml` in place the naive check reported zero offenders on a 652px-wide page, which
is why the template defect and the probe defect were one report.


## 1.0.4

Neutralization sweep (same pass as `surface-swift` 1.4.0 / `sample-data` 2.1.0). The DAP
header and footer shipped real-world data: the literal word **"Swift"** as the wordmark
on all four logo paragraphs and in the mobile footer nav heading ("About Swift"), a real
postal address, phone number and e-mail address in the footer contact block, and a
"Copyright (c) Dynamicweb 2026" line. All replaced with `Placeholder — <function>` copy
naming the slot, e.g. `Placeholder — footer address line 1`. The literal word
`Placeholder` is the machine-detectable marker a design gate scans for
(`/placeholder/i`).

Patch bump: nine field values, no structural change.

## 1.0.3

Area style-id migration to the `default` scheme (LRN-uipass-03), mirroring the surface-swift
P1 migration. `replace/_content/Digital Assets Portal/area.yml` `properties`: the legacy Swift
design-package style ids were re-pointed to the shipped `default` asset scheme —
`AreaColorSchemeGroupId` `swift`→`default`, `AreaTypographyId` `fonts`→`default`,
`AreaButtonStyleId` `buttons`→`default`; `AreaColorSchemeId` stays `light` (the `light` scheme
ships in the `default` ColorScheme group, matching surface-swift's `default/light/default/default`).
The legacy `swift`/`fonts`/`buttons` ids resolved to **no shipped `{json,css}` pair** in the
composed host Styles root (`wwwroot/Files/System/Styles` ships only `default.{json,css}` for
ColorSchemes/Typography/Buttons), so `TryGet*Style` fell back silently to serif defaults — the
exact defect class the RUN-DISTRIBUTION-QUALITY gate exists to kill. The gate Step 10d3
Area style-wiring assert (added in the P1 back-sync) is the first pipeline pass to reach this
edition and correctly named it. Content/pages/data unchanged; only the four Area style columns.
Re-proven on DW 10.28.1-PreRelease (full cold matrix).

## 1.0.2

Config predicate-mode migration (LRN-base232-03), mirroring the base + surface-swift
migration (`ee81375`). `config/digital-asset-portal-1.0.json`: the single Content predicate
mode migrated `Deploy`→`Replace`; the output-subfolder keys renamed
`deployOutputSubfolder`→`replaceOutputSubfolder` and `seedOutputSubfolder`→`mergeOutputSubfolder`
(values already `replace`/`merge`). Engine `0.9.0-beta` validates predicate modes strictly
(`Replace`/`Merge` only) and the harness probes `SerializerSettings` before deserializing, so
the retired `Deploy` enum returned HTTP 500 and aborted the DAP surface deserialize. No
data/content changes; output split unchanged. Re-proven on DW 10.28.1-PreRelease
(full cold matrix).

## 1.0.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). Composes on the framework-only base; Swift-v2 item-type definitions come from the host design-package overlay (unchanged). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

## 1.0.0 — graduated out of Beta (2026-07-10)

First gate-proven, tag-eligible release of the Digital Asset Portal surface. Proven
end-to-end on base **2.4.1** + engine **0.8.0-beta** via `gate.ps1 -Edition dap-portal`
(base replace+merge HTTP 200, permissions parity 133, title integrity 122, DAP surface
replace HTTP 200 / 117 created / 0 failed, `/dap` smoke green). Re-pins `base@2.4.1`.

- **Dangling `CreateUserPageId` page-8330 link pruned** (data-only). The Sign-in
  `UserAuthentication` module referenced a non-existent create-account page (8330); the
  portal has no self-registration flow, so the reference is blanked. Its two sibling links
  (`RedirectToSpecificPage` 8308, `CreatePasswordPageId` 8329) resolve normally. The
  now-moot `acknowledgedOrphanPageIds: [8330]` config entry is cleared.
- **The two prior Beta blockers were already resolved in content** and re-confirmed by this
  gate: the account page uses `Swift-v2_Navigation` (not the absent `Swift-v2_VerticalNavigation`),
  and the Desktop Header no longer carries the `Default.aspx?ID=6869` cross-link (the base
  2.3.2 DAP-decoupling B3 removal, now graduated from Unreleased).

## 1.0.0 (beta)

- First captured baseline for the Digital Asset Portal on DW 10.26.7.
- Deploy tree (1 predicate): the Digital Assets Portal area (area 26) — Home,
  Digital Assets browser, Download Cart, Customer center, Sign in (~32 pages,
  122 YAML files).
- Built on Swift-v2 item types; deploys as an add-on to the `swift/2.2` baseline.
- Beta: requires the Swift-v2 design (incl. `Swift-v2_VerticalNavigation` item
  type) on the target; one acknowledged dangling demo link (page 8330). See
  BASELINE.md.
- Config: `config/digital-asset-portal-1.0.json`.

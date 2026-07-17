# Changelog — digital-asset-portal/1.0

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

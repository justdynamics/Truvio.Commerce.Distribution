# Changelog — digital-asset-portal/1.0

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

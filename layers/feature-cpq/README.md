# feature-cpq 1.0.0-candidate

This is the neutral workbench CPQ candidate for a blank DW 10.29.8 proving host. It declares 18 core CPQ functions and ten platform prerequisites. It is separate from the native BOM configurator. Routing, 3D and ERP operations are excluded from this profile.

`layer.json` points to the portable spec, package evidence, behavior declaration and generated review artifacts. The 15 compiler rows use a deterministic identity map, stay version-owned and inactive, and leave five unresolved delivery requirements visible. The content plan carries four component products, exact EUR prices, page/theme intent and local card/cart/quote/document requirements. Its symbolic bindings are not deployable Serializer content yet. The candidate is refused before delivery, so none of these files silently stands in for installed content.

The package file is intentionally `kind:cpq-packages-candidate`, not an installable lock. The retained hashes are evidence from package inspection. They do not authorize redistributing the modified runtime DLL or hotfix. Blockers are named in the layer and repeated in the edition:

- `openxml-closure`: original OpenXml 3.1.0, OpenXml.Framework packages and dependency closure remain unresolved.
- `runtime-identity`: the original vendor runtime package source needs delivery resolution; only vendor nupkg bytes qualify, never the differing installed replacement.
- `runtime-verification`: loaded identities and a blank 10.29.8 proving run are missing.
- `content-bindings`: scoped catalogue, price, page, owner and document bindings need a verified importer.
- `engine-adapter`: runtime payloads, behavior readbacks and app defects need characterization.

Studio availability and the MCP prerelease are resolved package questions. The evidence pins
the published Studio v0.7.0 nupkg at `577c2be7ffd4117c88d9bc83cfbbbaa1f4375ed4` and MCP
0.6.5-beta, whose package bundles MCP.Host. Studio's NuGet dependency list is empty; its
admin/runtime/MCP site prerequisites remain explicit. Neither verified archive claims a host run.

Changing a status or filename cannot promote this evidence. Structural validation checks the candidate schema, content digests, deterministic compiler output, identity map and case fixtures. `Test-CpqLayerContract -ForDelivery` refuses it with the named reasons. Foundry's dedicated proving delivery is the eventual consumer; generic composition refuses CPQ instead of ignoring its declaration.

`editions/cpq-demo.json` composes base 4.6.1, surface-swift 1.19.3, theme-default 2.8.0 and this candidate, with sampleData false. Its 74 explicit checks are locked to skills `d049f8fb6596a1ccd5a03ed6f8b22e70bc3a37b6` (snapshot 10.30.6 revision 4): all composition-provided checks, the 28 core CPQ checks and the CPQ prerequisite checks. Existing editions retain their earlier locks. Required platform functions are measured prerequisites, not claims that this feature owns their implementation.

No gateProven, provenTree, edition release, tag or bacpac is claimed. Promotion requires the real package lock, resolved scoped content, the reviewed Foundry adapter, complete behavior readers, green/red/restored-green evidence on a blank host, repeat apply and restart checks, and a second independent blank-host proof. Release provenance must come through the existing solution record and gate projection.

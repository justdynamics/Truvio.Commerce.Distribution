# seed/ — Swift 2.2 seed tree

This directory holds the **Seed-mode** YAML for the Swift 2.2 baseline: the
bootstrap catalog and customer-tunable content that deserialize fills only where
the target is empty.

Captured from a clean source host (18 seed predicates): the customer-owned
content subtrees (Homepage, Site chrome, About, Starter blog posts, Find dealers,
footers, Newsletter examples) and the starter catalog (`EcomGroups`,
`EcomProducts`, variants, discounts, and their relations).

## Re-capturing

To refresh after a config or source change, re-run the
[authoring loop](../../../../docs/authoring-a-baseline.md):

```powershell
pwsh tools/capture/new-baseline.ps1 -Product swift -Version 2.2 `
  -SourceHostUrl https://localhost:56100 `
  -SourceFilesRoot <host>\wwwroot\Files -Mode seed
```

Then verify the round-trip into a clean target before release.

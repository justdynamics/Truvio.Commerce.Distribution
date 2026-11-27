# Example: a PIM solution

A small solution repository in the layout the deploy core reads, for a PIM without a storefront. It
is delivered on top of the `base-only` edition:

```powershell
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://<host> -Edition base-only -SolutionRoot pipelines/core/examples/pim-solution
```

| Part | What it shows |
|---|---|
| `serializer/merge.pim-reference/` | Database configuration as Serializer files: four completeness rules (the rules of the Distribution's sample PIM), with the folder's own `merge-manifest.json`. |
| `serializer/config/pim-solution.json` | The Serializer predicate for that folder. |
| `files/System/Repositories/ProductsBackend/Products.index` | A file on disk: the back-office product index of the Swift release with `SkipCompletionRules` `False` on both builds, so the index carries completeness scores. A changed stock file; it follows the Swift release when that rolls. |
| `settings.json` | The approved settings list: the Completeness feature switch. |

A real solution adds its data model, workflows, workspaces, dashboards and groups as further class
folders under `serializer/`, its integration jobs and shared queries under `files/`, and its sample
products under `testdata/`, which reaches a test environment only.

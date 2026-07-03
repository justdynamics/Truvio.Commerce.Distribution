# Package format

A package is a directory under `packages/<product>/<version>/` with a fixed
shape. It is consumed by the
[Truvio.Commerce.Serializer](https://github.com/justdynamics/Truvio.Commerce.Serializer)
engine; this document describes the contract, not the engine internals.

```
packages/<product>/<version>/
  config/<name>.json        # predicate configuration
  deploy/                   # Deploy-mode YAML tree
  seed/                     # Seed-mode YAML tree
  BASELINE.md               # human documentation of the split
  INSTALL.txt               # the Management-API deserialize flow
  CHANGELOG.md
```

## The config (`config/<name>.json`)

A single object with output settings, optional global exclusions, and a flat
`predicates` array. Each predicate carries its own mode and provider type:

```jsonc
{
  "outputDirectory": "Serializer",
  "deployOutputSubfolder": "deploy",
  "seedOutputSubfolder": "seed",
  "excludeXmlElementsByType": { /* per-XML-type element names to strip */ },
  "predicates": [
    {
      "name": "Content - Swift 2 (full baseline as shipped)",
      "mode": "Deploy",            // Deploy | Seed
      "providerType": "Content",   // Content | SqlTable
      "areaId": 3,
      "path": "/"
    },
    {
      "name": "EcomCountries",
      "mode": "Deploy",
      "providerType": "SqlTable",
      "table": "EcomCountries",
      "nameColumn": "CountryCode2"
    }
  ]
}
```

- **`mode`** — `Deploy` (source wins; YAML overwrites the target) or `Seed`
  (field-level merge; fills only empty fields, preserves customer edits).
- **`providerType`** — `Content` (an area page tree) or `SqlTable` (rows of one
  table).
- Content predicates use `areaId`, `path`, optional `excludes`,
  `excludeFields`, `includeLanguageLayers`.
- SqlTable predicates use `table`, optional `nameColumn`, `where`, `xmlColumns`,
  `resolveLinksInColumns`, `serviceCaches`.

See the engine's `docs/configuration.md` and `docs/concepts.md` for the full
schema.

## The YAML trees (`deploy/`, `seed/`)

Each tree is the engine's serialize output for the predicates of that mode,
laid out exactly as the deserializer reads it:

- **Content predicates** produce an area-mirrored tree:
  `deploy/<Area>/area.yml`, then `<Page Path>/page.yml`, with grid rows and
  paragraphs nested beneath.
- **SqlTable predicates** produce a flat per-table directory:
  `deploy/<TableName>/<RowKey>.yml`.

Both kinds sit side by side in the same `deploy/` (or `seed/`) folder. Identity
is by GUID (`areaId`, `pageUniqueId`, …), so the same baseline resolves to the
right rows in any target regardless of local numeric IDs. Cross-environment
page links (`Default.aspx?ID=N`) are rewritten on deserialize for columns listed
in `resolveLinksInColumns`.

## `templates.manifest.yml`

Shipped inside each `_content/` tree, it lists the layouts, grid rows, and item
types the content references — a manifest of the template dependencies the
target host must already carry (from the Swift design) for the content to render.

## What is deliberately absent

Environment-specific data is never in a package: live domains, secrets,
payment-gateway keys, analytics IDs, CDN hosts, and the template filesystem
itself. Configure these per target host. Each package's `BASELINE.md` lists its
not-serialized items.

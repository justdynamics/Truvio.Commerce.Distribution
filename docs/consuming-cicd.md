# Consuming a baseline in CI/CD

Your pipeline clones this repo at a pinned commit, copies a package's YAML into
the target host's Serializer folder, and calls the deserialize endpoints under
strict mode. The baseline promotes identically across dev/test/QA/prod and every
change is reviewable as a YAML diff. There are no release zips — pin by commit SHA.

## Prerequisites

- The target host has the **Truvio.Commerce.Serializer** app installed (from the
  DW10 AppStore / NuGet).
- A Management API token for the target host (`DW_API_KEY`) and its base URL
  (`DW_HOST_URL`).
- The target host runs the platform version this package was tested against —
  see [COMPATIBILITY.md](../COMPATIBILITY.md).

## Layout on the host

The engine reads from `Files/System/Serializer/`:

```
Files/System/Serializer/
  Serializer.config.json              # the package's config/<name>.json
  SerializeRoot/
    deploy/                           # the package's deploy/ tree
    seed/                             # the package's seed/ tree
```

## Pipeline outline

```yaml
# 1. Check out this baselines repo (pin a commit SHA to reproduce exactly)
- uses: actions/checkout@v4
  with:
    repository: justdynamics/Truvio.Commerce.Serializer.Baselines
    ref: <commit-sha>
    path: baselines

# 2. Stage the package into the target host's Serializer folder
#    (adjust the transport — file copy, FTPS, deploy task — to your infra)
- run: |
    PKG=baselines/packages/swift/2.3
    cp $PKG/config/swift-2.3.json   "$HOST_FILES/System/Serializer/Serializer.config.json"
    rsync -a --delete $PKG/deploy/  "$HOST_FILES/System/Serializer/SerializeRoot/deploy/"
    rsync -a --delete $PKG/seed/    "$HOST_FILES/System/Serializer/SerializeRoot/seed/"

# 3. Deserialize under strict mode — deploy first, then seed
- run: |
    curl -fsS -X POST "$DW_HOST_URL/Admin/.../SerializerDeserialize?mode=deploy" \
      -H "Authorization: Bearer $DW_API_KEY"
    curl -fsS -X POST "$DW_HOST_URL/Admin/.../SerializerDeserialize?mode=seed" \
      -H "Authorization: Bearer $DW_API_KEY"
```

> Deploy before seed: seed merges onto the structure that deploy lays down.

## Strict mode and dry runs

Run the deserialize in **report / dry-run mode first** against a new platform
version and review any schema-drift or escalation warnings before applying. A
clean run returns HTTP 200 with zero escalations. Treat any escalation as a gate
failure in the pipeline.

## Promotion model

- Pin the baseline commit SHA your environments track.
- To roll an update forward, bump to a newer commit and re-run the same
  deserialize step. Deploy data is overwritten (source wins); seed data merges
  without clobbering customer edits.

For the reference end-to-end pipeline that also restores a clean database and
verifies preservation, see `tools/e2e/full-clean-roundtrip.ps1` and
[authoring-a-baseline.md](authoring-a-baseline.md).

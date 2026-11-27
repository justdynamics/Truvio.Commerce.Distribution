# Pipelines

The Distribution sets up a solution, and with the items in this folder it also sets up the way that
solution is deployed. A pipeline item is versioned deploy tooling: it delivers a Distribution edition,
and a solution repository on top of it, onto a Dynamicweb 10 host that is reached by its address and
an Admin API key. No SQL access, file share or remote shell is needed, so the same run works against
Dynamicweb Cloud, an Azure App Service and an IIS server.

| Item | What it is | Version | State |
|---|---|---|---|
| [`core`](core/README.md) | The deploy script every engine runs: `Deploy-Edition.ps1` and its module. PowerShell 7, no other dependency. | 1.0.0 | Proven: delivered the PIM-only composition (with and without a solution on top) and the Swift storefront with sample data onto blank hosts. |
| [`azure`](azure/README.md) | Azure Pipelines templates: one stage per environment, each a deployment job on an Azure DevOps Environment, running the core. | 1.0.0 | Not yet run in Azure DevOps. |

Each item states what has been measured in the `proof` block of its `pipeline.json`. A pipeline item
is tooling, not content: it is not part of `layers/INDEX.json` `gateProven` and proves no edition.

## What a release is

A solution is one repository. A release of it is one tag, and the same release goes to every
environment unchanged. The repository holds only what the solution adds to its edition:

```
<solution repository>/
  layers/<name>/               layers in the Distribution's own shape (layer.json, replace/, merge/, files/ ...)
  serializer/
    replace.<name>/            database configuration as Serializer files, one folder per class of data;
    merge.<name>/              each folder carries its <mode>-manifest.json
    config/*.json              the Serializer predicates for those folders
  files/                       whole files for the host's Files folder: repositories, shared queries,
                               integration jobs, templates
  settings.json                the approved list of settings: { "settings": { "/Globalsettings/...": "value" } }
  testdata/                    sample data, in the same three folders (layers/, serializer/, files/)
  azure-pipelines.yml          the pipeline: a copy of azure/examples/, a dozen lines of its own
```

What is never in it: products and their values, prices, stock, users, passwords, keys, the host's
settings files, its database connection, its licence. `settings.json` is refused when a key names a
password, a database, a licence, mail or a secret. `testdata/` reaches a test environment and no
other.

[`core/examples/pim-solution`](core/examples/pim-solution) is a small PIM solution in this layout:
completeness rules as database configuration, the back-office product index with completeness
scoring on as a file, and the Completeness feature switch as a setting.

## What a run does

One order, on every environment and with every engine:

1. **Plan.** The edition is resolved into its layers at the versions it pins; the solution's folders
   follow. Demo data is refused where it does not belong.
2. **Probe.** The host's Dynamicweb version is checked against the base contract's floor, and the key
   is proven to work.
3. **Apps.** The Serializer is installed from nuget.org when the host does not have it.
4. **Files.** The Swift release files the base contract pins (all of them for a storefront, only the
   back-office product repository for a PIM), then the layers' files, then the solution's.
5. **Settings.** The settings the base contract requires, the layers' settings fragments and the
   solution's list, one by one, each read back.
6. **Database configuration.** Everything serialized is composed into one tree per mode and
   deserialized, replace before merge, strict: any warning stops the run. The Serializer's dry run
   precedes each pass and is reported.
7. **Indexes.** Every product index the delivery brought is built and waited for. Scheduled index
   tasks are uploaded only after the configuration is in.
8. **Verify.** The Serializer's state and the edition's critical paths.

A run deletes nothing on the host: it adds and overwrites. Removing a field, a workflow state or a
page is a separate, reviewed change. Every stage can be run again.

| | test | acceptance | production |
|---|---|---|---|
| Edition without sample data, solution configuration, files, settings | yes | yes | yes |
| Edition with sample data (`sampleData: true`), `testdata/` | yes | refused | refused |
| Sample persona passwords | when `DW_PERSONA_PASSWORD` is set | never | never |
| Approval | none | on the Environment | on the Environment |

All environments run the same Dynamicweb version before the first delivery; a strict import stops
on differences in the database schema.

## Three ways to run it

**Azure Pipelines.** The solution's `azure-pipelines.yml` names the Distribution as a repository
resource at a released tag and uses [`azure/deploy-edition.yml`](azure/deploy-edition.yml). Approvals,
checks and the run history live in Azure DevOps. See [azure/README.md](azure/README.md).

**No pipeline engine at all.** The same script from any machine with PowerShell 7:

```powershell
$env:DW_API_KEY = (Get-Content C:\keys\acme-test.dw-apikey -Raw).Trim()
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://acme-test.example.com -Edition base-only -SolutionRoot C:\src\acme
```

On the web server itself, `-Restart command -RestartCommand '<recycle the application pool>'` makes
it a complete scripted deploy to an IIS host, and a scheduled task or a one-line wrapper script is
all the automation it needs. What this route does not give: a named approver recorded with the run,
and a history that lives anywhere but in the report files it writes.

**GitHub Actions (proposed, not shipped).** A workflow in the solution repository would check out
the Distribution at a tag beside the solution and run the same script, with the key as a repository
or environment secret:

```yaml
jobs:
  deliver:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
        with: { path: solution }
      - uses: actions/checkout@v4
        with: { repository: justdynamics/Truvio.Commerce.Distribution, ref: pipelines/core/1.0.0, path: distribution }
      - shell: pwsh
        env: { DW_API_KEY: '${{ secrets.DW_API_KEY }}' }
        run: ./distribution/pipelines/core/Deploy-Edition.ps1 -HostUrl '${{ vars.DW_HOST_URL }}' -Edition base-only -SolutionRoot ./solution -Environment test
```

What it would take to ship as an item: this workflow as a reusable one (`workflow_call`) in the
Distribution, one run against a host, and a decision on approvals. GitHub's own approval gate
(required reviewers on an Environment) needs a paid plan for a private repository; without it the
approval is an input the person dispatching the run fills in.

## Releases

Each item carries its own semver in `pipeline.json` and a `CHANGELOG.md`. On merge to main the tag
`pipelines/<name>/<version>` is cut for a version that has no tag yet. A change to any file of an
item needs a new version: the validator compares the item with its tag. A consumer pins a tag for a
reproducible run (the tag fixes the scripts and the layers together), or follows `main`.

## Not covered yet

- A database backup before a delivery. A host reached by address and key has no backup route; on
  Dynamicweb Cloud it is requested from operations, on an own server it is a step before the run.
- A check that a release was proven on a clean host before it may go to acceptance or production.
- A report of what differs on the target before a replace pass, beyond the Serializer's dry run.
- The SQL scripts a layer declares (the sample data's demo clock, email statistics and number
  counters): there is no SQL route, so they are listed in the report and not run.
- The Swift release's own settings file is not laid over the host's. One Swift default the
  storefront needs is applied as a setting; a host that never carried the Swift files may need more.
- Compositions with more than one content area (the headless edition).
- A restart on Dynamicweb Cloud through its control file is implemented and has not been measured.

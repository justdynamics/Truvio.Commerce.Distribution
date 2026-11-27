# core: the deploy script

`Deploy-Edition.ps1` delivers a Distribution edition, and optionally a solution repository on top of
it, onto a Dynamicweb 10 host reached by its address and an Admin API key. `DeployCore.psm1` holds
its functions. PowerShell 7.2 or newer; nothing else is installed or downloaded except the Swift
release files and the Serializer package the base contract names.

The model, the layout of a solution repository and the order of a run are in
[../README.md](../README.md). This page is the reference of the script.

## Use

```powershell
# The key: an environment variable, or a file. There is no parameter that takes the key itself.
$env:DW_API_KEY = (Get-Content C:\keys\acme-test.dw-apikey -Raw).Trim()

# PIM only, onto a blank host.
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://acme-test.example.com -Edition base-only

# The same with the solution's own configuration, files and settings on top.
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://acme-test.example.com -Edition base-only -SolutionRoot C:\src\acme

# What would be delivered; nothing is sent.
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://acme-test.example.com -Edition base-only -Stage plan
```

The key is created in the admin under Settings > System > Developer > Api Keys. It is held in
memory, sent as a bearer header and never written to a log, the report or a URL.

## Parameters

| Parameter | Meaning |
|---|---|
| `-HostUrl` | The host's address, `https://...`, without a path. |
| `-Edition` | An edition under `editions/`. Default `base-only`, the PIM-only composition. |
| `-Environment` | `test` (default), `acceptance` or `production`. Decides whether demo data may be delivered. |
| `-SolutionRoot` | A solution repository in the layout of [../README.md](../README.md). |
| `-ExtraLayer` | Layer folders from outside the Distribution, delivered after the edition's layers. |
| `-ApiKeyFile` | A file holding the key. Without it the key is read from `DW_API_KEY`. |
| `-Stage` | `all` (default) or any of `plan`, `probe`, `apps`, `hostfiles`, `layerfiles`, `settings`, `content`, `index`, `verify`. |
| `-HostFiles` | `auto` (default), `full`, `repositories` or `none`: how much of the Swift release is pushed. `auto` is `full` for an edition with a surface or a theme and `repositories` otherwise. |
| `-Restart` | `control-file` (default), `command` or `none`. See below. |
| `-RestartCommand` | A PowerShell command line that recycles the application, for `-Restart command`. |
| `-AreaId` | The website the edition's content area lands on. Default 1, the website the stock setup wizard creates. |
| `-WorkDir` | Downloads, the composition, logs and reports. Default `.deploy` under the current directory. |
| `-RunName` | Names this invocation's report and log folder, for a pipeline that runs the stages as separate steps. |
| `-DryRun` | Plan, probe and compose only. Nothing that changes the host is sent. |
| `-NonStrict` | Deserialize with strict mode off. An exception to name in the run's record. |

Environment variables: `DW_API_KEY` (the key) and, on a test environment, `DW_PERSONA_PASSWORD`
(the password the sample personas get; without it they have none and the report says so).

## Restarts

Item types, repositories and settings are read when the application starts, so a run restarts the
host after it pushed files that need it and after it changed a setting.

| `-Restart` | How | For |
|---|---|---|
| `control-file` | Uploads `recycle.txt` into `System/CloudHosting`. The restart counts only when the platform consumed the file; a file that is still there after three minutes is reported as a restart owed, and the run stops. | Dynamicweb Cloud |
| `command` | Runs `-RestartCommand` on the machine the script runs on. | An IIS server (`appcmd recycle apppool`), an Azure App Service (`az webapp restart`) |
| `none` | Never restarts. A step that needs one reports it as owed and the run stops; restart the application and run again. | A host only its operator may restart |

## What a run leaves behind

`deploy-report.json` in `-WorkDir`: the facts of the run (host, edition, layers with versions, the
Distribution commit, the Dynamicweb version) and one row per step with `PASS`, `FAIL`, `OWED`,
`SKIP` or `WARN` and what was read back. `logs/` holds the host's answer to every request. The
script exits 1 when a row reads `FAIL` or `OWED`.

A status code is never taken as the evidence: an upload counts when the host lists every file of
the batch, a setting when it reads back, a deserialize when it reports no failure and no escalated
warning, an index when a build stamped after the request reports success.

## Tests

`tests/DeployCore.Tests.ps1` (Pester) resolves the plan of the editions, composes them into one
tree per mode and exercises the solution layout and its refusals. It needs no host and runs in the
repository's validation workflow on Linux. The delivery itself is proven against a live host.

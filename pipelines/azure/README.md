# azure: Azure Pipelines templates

Two templates that run the [deploy core](../core/README.md) from Azure Pipelines:

- [`deploy-edition.yml`](deploy-edition.yml): stages. One stage per environment in the order given,
  each a deployment job bound to an Azure DevOps Environment.
- [`steps/deploy-edition.yml`](steps/deploy-edition.yml): the steps of one delivery, for a pipeline
  that brings its own stages and jobs.

**State: not yet run in Azure DevOps.** The script the steps call has delivered the PIM-only
composition and the Swift storefront end to end; the YAML around it parses and is otherwise unmeasured. The first run in an
Azure DevOps organisation is the proof this item still owes.

## Set up a solution's pipeline

In the Azure DevOps project of the solution:

1. **Service connection.** Project settings > Service connections > New > GitHub. It lets the
   pipeline read `justdynamics/Truvio.Commerce.Distribution`. The examples call it
   `github-distribution`.
2. **Environments.** Pipelines > Environments: one per target, for example `pim-test`,
   `pim-acceptance`, `pim-production`. On acceptance and production add an Approvals check with the
   named approver.
3. **Variable groups.** Pipelines > Library: one group per target, holding `DW_HOST_URL` (the
   host's address) and `DW_API_KEY` as a secret (an Admin API key of that host, created under
   Settings > System > Developer > Api Keys). On test, optionally the secret `DW_PERSONA_PASSWORD`.
4. **The pipeline.** Copy [`examples/pim.azure-pipelines.yml`](examples/pim.azure-pipelines.yml)
   into the solution repository as `azure-pipelines.yml`, set the names from steps 1 to 3, and
   create a pipeline from it. The first run asks once for permission to use the service connection,
   the variable groups and the Environments.

The same with the Azure CLI (`az extension add --name azure-devops`), for a project `acme`:

```bash
az devops configure --defaults organization=https://dev.azure.com/<organisation> project=acme
az pipelines variable-group create --name pim-test --variables DW_HOST_URL=https://acme-test.example.com
az pipelines variable-group variable create --group-id <id> --name DW_API_KEY --secret true   # prompts for the value
az pipelines create --name deploy --repository <solution repository> --branch main --yml-path azure-pipelines.yml --skip-first-run
az pipelines run --name deploy
```

Environments and their approval checks are created in the web interface or through the REST API;
the CLI has no command for them.

## Parameters of `deploy-edition.yml`

| Parameter | Meaning |
|---|---|
| `edition` | The edition every environment gets unless it names its own. Default `base-only`. |
| `environments` | The list of targets, in order. See the table below. |
| `solutionPath` | The solution's folder in the consuming repository, `.` for its root. Empty: the edition alone. |
| `extraLayers` | Layer folders in the consuming repository, delivered after the edition's layers. |
| `distributionRepository` | The alias of the Distribution repository resource. Default `distribution`. |
| `areaId` | The website a storefront's content area lands on. Default 1. |
| `strict` | Default `true`. `false` deserializes with strict mode off, an exception to name in the run's record. |

Each entry of `environments`:

| Key | Meaning |
|---|---|
| `name` | `test`, `acceptance` or `production`. Decides what may be delivered. |
| `environment` | The Azure DevOps Environment of the deployment job. |
| `variableGroup` | The Library group with `DW_HOST_URL` and `DW_API_KEY`. |
| `edition` | Optional: another edition for this environment only, such as the one with sample data on test. |
| `pool` | Optional: default `vmImage: windows-latest`. A self-hosted pool for a host a Microsoft-hosted agent cannot reach. |
| `restart`, `restartCommand` | Optional: `control-file` (default), `command` with its command line, or `none`. |
| `hostFiles` | Optional: `auto` (default), `full`, `repositories` or `none`. |

## What a run shows

Per stage, six steps: plan and probe, apps, files, settings, compose and deserialize, indexes and
verify. A failed step names the stage that failed. The reports and the host's answers to every
request are published as the artifact `deploy-<stage>-<attempt>`, whatever the outcome.

## Pinning

The `ref` of the repository resource decides the templates, the script and the layers together.
`refs/tags/pipelines/azure/<version>` gives a reproducible run; `refs/heads/main` follows the
Distribution. Until a tag exists for a version under review, a branch ref works the same way.

## Agents

The default is a Microsoft-hosted Windows agent, which is what the deploy core has been run on. It
reaches any host with a public address. A host behind a firewall needs a self-hosted agent that can
reach it; an agent on the web server itself can also restart the application
(`restart: command`). The plan and the composition are tested on Linux; a whole delivery from a
Linux agent has not been run.

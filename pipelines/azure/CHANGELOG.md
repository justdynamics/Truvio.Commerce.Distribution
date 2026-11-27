# Changelog: pipelines/azure

## 1.0.0 (2026-11-27)

The first release. `deploy-edition.yml` turns a list of environments into stages, each a deployment
job on an Azure DevOps Environment; `steps/deploy-edition.yml` runs the deploy core 1.0.0 in six
steps and publishes its reports and logs. Two example pipelines: a PIM-only solution and a Swift
storefront.

Not measured in this release: the templates have not run in Azure DevOps. The YAML parses; the
script it calls is proven by `pipelines/core` 1.0.0.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Modular Azure Bicep IaC templates for provisioning Azure infrastructure. The project has 27 Bicep modules covering 60+ resource types, organized in dependency layers with a main orchestrator (`main.bicep`) that targets subscription scope.

## Common Commands

```bash
# Lint a single module
az bicep lint --file modules/<module-name>/main.bicep

# Lint all modules
for file in modules/*/main.bicep; do az bicep lint --file "$file"; done

# Build (compile to ARM) a single module
az bicep build --file modules/<module-name>/main.bicep

# Build the orchestrator
az bicep build --file main.bicep

# Validate parameter files
az bicep build-params --file environments/dev.bicepparam

# What-If simulation (dry run)
az deployment sub what-if --location brazilsouth --template-file main.bicep --parameters environments/dev.bicepparam

# Deploy to an environment
az deployment sub create --location brazilsouth --template-file main.bicep --parameters environments/dev.bicepparam
```

Prerequisites: Azure CLI >= 2.50, Bicep CLI >= 0.24.

## Architecture

### Orchestrator (`main.bicep`)

Deploys at **subscription scope** and composes all 27 modules across 8 dependency layers, each controlled by a boolean toggle:

| Layer | Toggle Parameter | Resources |
|-------|-----------------|-----------|
| 0 | (always on) | Resource Group |
| 1 | `enableNetworking` | VNet, Subnets, NSG, NAT Gateway, Private DNS |
| 2 | `enableMonitoring` | Log Analytics, App Insights, Storage Account |
| 3 | `enableSecurity` | Key Vault, Certificates |
| 4 | `enableData` | SQL Server, SQL Database, Redis Cache |
| 5 | `enableCompute` | ACR, AKS, Node Pool, App Gateway, Bastion, VM |
| 6 | `enableMessaging` | API Management, Event Hub, Service Bus, SignalR |
| 7 | `enableGovernance` | Role Assignments, Policies |

### Module Convention

Every module lives in `modules/<resource-name>/main.bicep` with its own `README.md`. All modules share these common parameters:

- `name` (string, optional) — full override for the auto-generated name
- `workloadName` (string, required, 2-20 chars)
- `environment` (string, required) — any string like `dev`, `staging`, `prod`
- `location` (string, default `brazilsouth`)
- `tags` (object, defaults to `{ ManagedBy: 'Bicep', Environment: env }`)

### Naming Convention (CAF)

Pattern: `{workloadName}-{abbreviation}-{environment}` (or without hyphens for resources like ACR and Storage Account). If `name` is provided, it overrides the generated name entirely.

### Environment Parameters

Three environment configs in `environments/`:
- **dev.bicepparam** — Layers 1-3 enabled, `10.10.0.0/16`
- **staging.bicepparam** — Layers 1-5 enabled, `10.20.0.0/16`
- **prod.bicepparam** — All layers enabled, `10.30.0.0/16`

## Linting Rules

`bicepconfig.json` enforces strict rules. Key **error-level** rules: no hardcoded URLs/locations, no unused params/vars, secure parameter defaults, no exposed secrets, no literal admin usernames, secure values for secure inputs. Violations will fail CI.

## CI/CD (GitHub Actions)

- **validate.yml** — Runs on PR to `main`: lints all modules, builds, validates params, runs what-if
- **deploy-dev.yml** — Auto-deploys on push to `main` (only `*.bicep`/`*.bicepparam` changes)
- **deploy-staging.yml** / **deploy-prod.yml** — Manual dispatch; prod requires approval
- **reusable-deploy.yml** — Shared workflow: validate → what-if → deploy (one deployment per environment via concurrency)

Authentication uses OIDC with secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.

## Adding a New Module

1. Create `modules/<resource-name>/main.bicep` with the standard parameters above
2. Use the CAF naming variable pattern: `var autoName = '${workloadName}-<abbr>-${environment}'` and `var resourceName = empty(name) ? autoName : name`
3. Output at minimum `id` and `name`
4. Add a `modules/<resource-name>/README.md` with usage examples and parameter table
5. Wire the module into `main.bicep` under the appropriate layer with the correct `dependsOn`
6. Add relevant parameters to the environment `.bicepparam` files

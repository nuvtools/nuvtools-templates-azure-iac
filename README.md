# Azure Bicep Templates

Collection of modular and reusable Azure Bicep templates for infrastructure provisioning on Azure, following best practices and a configurable naming convention based on the CAF (Cloud Adoption Framework) standard.

## Overview

This project contains **27 Bicep modules** covering over **60 Azure resource types**, organized in dependency layers with a main orchestrator that composes all modules.

## Project Structure

```
azure-bicep-templates/
├── modules/                      # Reusable Bicep modules (template library)
│   ├── resource-group/           # Resource Group
│   ├── virtual-network/          # Virtual Network
│   ├── subnet/                   # Subnet
│   ├── nsg/                      # Network Security Group
│   ├── nat-gateway/              # NAT Gateway + PIP Prefix
│   ├── private-dns-zone/         # Private DNS + VNet links
│   ├── private-endpoint/         # Generic Private Endpoint
│   ├── container-registry/       # Azure Container Registry
│   ├── kubernetes-cluster/       # Azure Kubernetes Service
│   ├── kubernetes-nodepool/      # Additional AKS Node Pool
│   ├── key-vault/                # Azure Key Vault
│   ├── key-vault-certificate/    # Key Vault Certificate
│   ├── app-gateway/              # Application Gateway + WAF
│   ├── app-insights/             # Application Insights
│   ├── log-analytics/            # Log Analytics Workspace
│   ├── storage-account/          # Storage Account
│   ├── sql-server/               # SQL Server + auditing
│   ├── sql-database/             # SQL Database
│   ├── api-management/           # API Management
│   ├── bastion/                  # Azure Bastion
│   ├── event-hub/                # Event Hub Namespace + Hubs
│   ├── redis-cache/              # Redis Cache
│   ├── service-bus/              # Service Bus + queues/topics
│   ├── signalr/                  # Azure SignalR Service
│   ├── virtual-machine-windows/  # Windows VM + NIC
│   ├── role-assignment/          # RBAC Assignment
│   └── policy/                   # Azure Policy
├── examples/                     # Reference consumer implementation
│   ├── main.bicep                # Example orchestrator (subscription scope)
│   ├── main.bicepparam           # Default parameters
│   ├── environments/             # Parameters per environment
│   │   ├── dev.bicepparam
│   │   ├── staging.bicepparam
│   │   └── prod.bicepparam
│   └── .github/workflows/        # Reference deploy workflow templates
│       ├── reusable-deploy.yml
│       ├── deploy-dev.yml
│       ├── deploy-staging.yml
│       └── deploy-prod.yml
├── bicepconfig.json              # Shared lint rules
└── .github/workflows/            # Repo CI
    └── validate.yml
```

## Naming Convention

All resources follow the pattern: **`{workloadName}-{abbreviation}-{environment}`**

- If the `name` parameter is provided, the automatically generated name is ignored and the value of `name` is used directly.
- Resources that do not support hyphens (ACR, Storage Account) use the format: **`{workloadName}{abbreviation}{environment}`**
- The `environment` parameter accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`, etc.).

### Naming Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | string | `''` | Full resource name. When provided, overrides the automatically generated name |
| `workloadName` | string | (required) | Workload name |
| `environment` | string | (required) | Environment (accepts any string: `dev`, `uat`, `hml`, `staging`, `prod`, etc.) |

### CAF Abbreviations per Resource

| Resource | Abbreviation | Pattern | Example |
|---|---|---|---|
| Resource Group | `rg` | `{workloadName}-rg-{env}` | `myapp-rg-dev` |
| Virtual Network | `vnet` | `{workloadName}-vnet-{env}` | `myapp-vnet-dev` |
| Subnet | `snet` | `{workloadName}-snet-{env}` | `myapp-snet-dev` |
| NSG | `nsg` | `{workloadName}-nsg-{env}` | `myapp-nsg-dev` |
| NAT Gateway | `ng` | `{workloadName}-ng-{env}` | `myapp-ng-dev` |
| Private Endpoint | `pep` | `{workloadName}-pep-{env}` | `myapp-pep-dev` |
| Key Vault | `kv` | `{workloadName}-kv-{env}` | `myapp-kv-dev` |
| AKS | `aks` | `{workloadName}-aks-{env}` | `myapp-aks-dev` |
| SQL Server | `sql` | `{workloadName}-sql-{env}` | `myapp-sql-dev` |
| SQL Database | `sqldb` | `{workloadName}-sqldb-{env}` | `myapp-sqldb-dev` |
| Log Analytics | `log` | `{workloadName}-log-{env}` | `myapp-log-dev` |
| App Insights | `appi` | `{workloadName}-appi-{env}` | `myapp-appi-dev` |
| App Gateway | `agw` | `{workloadName}-agw-{env}` | `myapp-agw-dev` |
| WAF Policy | `waf` | `{workloadName}-waf-{env}` | `myapp-waf-dev` |
| API Management | `apim` | `{workloadName}-apim-{env}` | `myapp-apim-dev` |
| Bastion | `bas` | `{workloadName}-bas-{env}` | `myapp-bas-dev` |
| Event Hub | `evh` | `{workloadName}-evh-{env}` | `myapp-evh-dev` |
| Redis Cache | `redis` | `{workloadName}-redis-{env}` | `myapp-redis-dev` |
| Service Bus | `sbns` | `{workloadName}-sbns-{env}` | `myapp-sbns-dev` |
| SignalR | `sigr` | `{workloadName}-sigr-{env}` | `myapp-sigr-dev` |
| Virtual Machine | `vm` | `{workloadName}-vm-{env}` | `myapp-vm-dev` |
| Storage Account | `st` | `{workloadName}st{env}` | `myappstdev` |
| Container Registry | `cr` | `{workloadName}cr{env}` | `myappcrdev` |

> See [Abbreviation recommendations for Azure resources](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations) for the full list.

> **Note on CAF abbreviation changes:** `natgw` was changed to `ng`, `pve` to `pep`, `law` to `log`, `sb` to `sbns`, and `wafpol` to `waf`.

## Dependency Layers

The orchestrator organizes the modules into 8 layers:

| Layer | Resources | Toggle |
|---|---|---|
| 0 | Resource Group | (always active) |
| 1 | VNet, Subnets, NSG, NAT Gateway, Private DNS | `enableNetworking` |
| 2 | Log Analytics, App Insights, Storage Account | `enableMonitoring` |
| 3 | Key Vault, Certificates | `enableSecurity` |
| 4 | SQL Server, SQL Database, Redis Cache | `enableData` |
| 5 | ACR, AKS, Node Pool, App Gateway, Bastion, VM | `enableCompute` |
| 6 | API Management, Event Hub, Service Bus, SignalR | `enableMessaging` |
| 7 | Role Assignments, Policies | `enableGovernance` |

## Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) >= 2.50
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) >= 0.26
- Azure subscription with Contributor permissions

### Validate the templates

```bash
# Lint all modules
for file in modules/*/main.bicep; do
  az bicep lint --file "$file"
done

# Build the orchestrator
az bicep build --file examples/main.bicep
```

### Deploy to the dev environment

```bash
az deployment sub create \
  --location brazilsouth \
  --template-file examples/main.bicep \
  --parameters examples/environments/dev.bicepparam
```

### What-If (simulation)

```bash
az deployment sub what-if \
  --location brazilsouth \
  --template-file examples/main.bicep \
  --parameters examples/environments/dev.bicepparam
```

## Examples

The `examples/` folder contains a full reference implementation showing how to consume the modules. Module paths are relative to the consumer file — if your orchestrator lives in a different location, adjust the paths accordingly (e.g., `'../modules/...'` from `examples/`, or `'./modules/...'` from the repo root).

### Deploy a single resource

A minimal subscription-scoped file that deploys just a Resource Group:

```bicep
targetScope = 'subscription'

module rg 'modules/resource-group/main.bicep' = {
  name: 'deploy-resource-group'
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
  }
}
```

> Generated name: `myapp-rg-dev`

### Compose multiple resources

Deploy a Resource Group, then scope a Log Analytics workspace and a Key Vault (with diagnostics) into it. The `scope:` property requires a compile-time value, so we compute the resource group name from the same naming convention the module uses:

```bicep
targetScope = 'subscription'

param workloadName string = 'myapp'
param environment string = 'dev'
param location string = 'brazilsouth'

// Compile-time RG name (must match the resource-group module's naming pattern)
var resourceGroupName = '${workloadName}-rg-${environment}'

// Layer 0 — Resource Group
module rg 'modules/resource-group/main.bicep' = {
  name: 'deploy-resource-group'
  params: {
    workloadName: workloadName
    environment: environment
    location: location
  }
}

// Layer 2 — Log Analytics Workspace
module logAnalytics 'modules/log-analytics/main.bicep' = {
  name: 'deploy-log-analytics'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    retentionInDays: 90
  }
}

// Layer 3 — Key Vault with diagnostics
module kv 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}
```

> Generated names: `myapp-rg-dev`, `myapp-log-dev`, `myapp-kv-dev`

### Override the generated name

Pass the `name` parameter to use a custom name instead of the auto-generated one:

```bicep
module kv 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-keyvault-name'
    workloadName: 'myapp'
    environment: 'dev'
  }
}
```

## CI/CD with GitHub Actions

The repo includes a validation workflow that runs on PRs. Deploy workflows are provided as **reference templates** in `examples/.github/workflows/` — copy them to your repo's `.github/workflows/` to use.

| Workflow | Location | Trigger | Description |
|---|---|---|---|
| `validate.yml` | `.github/workflows/` | PR to `main` | Lint + Build + What-If (repo CI) |
| `deploy-dev.yml` | `examples/.github/workflows/` | Push to `main` | Automatic deploy to dev |
| `deploy-staging.yml` | `examples/.github/workflows/` | Manual | Deploy to staging |
| `deploy-prod.yml` | `examples/.github/workflows/` | Manual + Approval | Deploy to production |
| `reusable-deploy.yml` | `examples/.github/workflows/` | Called by deploy workflows | Shared validate → what-if → deploy |

### Configuration

1. Create an App Registration in Azure AD with federated credentials for GitHub OIDC
2. Configure the following secrets in the GitHub repository:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
3. Create GitHub Environments (`dev`, `staging`, `prod`) with protection rules for `prod`

## Default Parameters

All modules accept the following common parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | string | `''` | Full resource name. When provided, overrides the automatically generated name |
| `workloadName` | string | (required) | Workload name |
| `environment` | string | (required) | Environment (accepts any string: `dev`, `uat`, `hml`, `staging`, `prod`, etc.) |
| `location` | string | `brazilsouth` | Azure region |
| `tags` | object | `{ ManagedBy: 'Bicep', Environment: env }` | Resource tags |

## Contributing

1. Fork the repository
2. Create a branch for the feature (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -m 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Open a Pull Request

## License

This project is licensed under the [MIT License](LICENSE).

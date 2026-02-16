# Azure Bicep Templates

Collection of modular and reusable Azure Bicep templates for infrastructure provisioning on Azure, following best practices and a configurable naming convention based on the CAF (Cloud Adoption Framework) standard.

## Overview

This project contains **27 Bicep modules** covering over **60 Azure resource types**, organized in dependency layers with a main orchestrator that composes all modules.

## Project Structure

```
nuvtools-azure-bicep-templates/
├── main.bicep                    # Main orchestrator (targetScope = 'subscription')
├── main.bicepparam               # Default parameters
├── bicepconfig.json              # Strict lint rules
├── modules/                      # 27 Bicep modules
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
├── environments/                 # Parameters per environment
│   ├── dev.bicepparam
│   ├── staging.bicepparam
│   └── prod.bicepparam
└── .github/workflows/            # CI/CD GitHub Actions
    ├── validate.yml
    ├── reusable-deploy.yml
    ├── deploy-dev.yml
    ├── deploy-staging.yml
    └── deploy-prod.yml
```

## Naming Convention

All resources follow the pattern: **`{prefix}-{workloadName}-{abbreviation}-{environment}`**

- If the `prefix` parameter is empty: **`{workloadName}-{abbreviation}-{environment}`**
- If the `name` parameter is provided, the automatically generated name is ignored and the value of `name` is used directly.
- Resources that do not support hyphens (ACR, Storage Account) use the format: **`{prefix}{workloadName}{abbreviation}{environment}`**
- The `environment` parameter accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`, etc.).

### Naming Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | string | `''` | Full resource name. When provided, overrides the automatically generated name |
| `prefix` | string | `''` | Resource name prefix. Previously hardcoded as `nvt` |
| `workloadName` | string | (required) | Workload name |
| `environment` | string | (required) | Environment (accepts any string: `dev`, `uat`, `hml`, `staging`, `prod`, etc.) |

### CAF Abbreviations per Resource

| Resource | Abbreviation | Pattern (with prefix) | Example (`prefix=hd`) |
|---|---|---|---|
| Resource Group | `rg` | `{prefix}-{name}-rg-{env}` | `hd-myapp-rg-dev` |
| Virtual Network | `vnet` | `{prefix}-{name}-vnet-{env}` | `hd-myapp-vnet-dev` |
| Subnet | `snet` | `{prefix}-{name}-snet-{env}` | `hd-myapp-snet-dev` |
| NSG | `nsg` | `{prefix}-{name}-nsg-{env}` | `hd-myapp-nsg-dev` |
| NAT Gateway | `ng` | `{prefix}-{name}-ng-{env}` | `hd-myapp-ng-dev` |
| Private Endpoint | `pep` | `{prefix}-{name}-pep-{env}` | `hd-myapp-pep-dev` |
| Key Vault | `kv` | `{prefix}-{name}-kv-{env}` | `hd-myapp-kv-dev` |
| AKS | `aks` | `{prefix}-{name}-aks-{env}` | `hd-myapp-aks-dev` |
| SQL Server | `sql` | `{prefix}-{name}-sql-{env}` | `hd-myapp-sql-dev` |
| SQL Database | `sqldb` | `{prefix}-{name}-sqldb-{env}` | `hd-myapp-sqldb-dev` |
| Log Analytics | `log` | `{prefix}-{name}-log-{env}` | `hd-myapp-log-dev` |
| App Insights | `appi` | `{prefix}-{name}-appi-{env}` | `hd-myapp-appi-dev` |
| App Gateway | `agw` | `{prefix}-{name}-agw-{env}` | `hd-myapp-agw-dev` |
| WAF Policy | `waf` | `{prefix}-{name}-waf-{env}` | `hd-myapp-waf-dev` |
| API Management | `apim` | `{prefix}-{name}-apim-{env}` | `hd-myapp-apim-dev` |
| Bastion | `bas` | `{prefix}-{name}-bas-{env}` | `hd-myapp-bas-dev` |
| Event Hub | `evh` | `{prefix}-{name}-evh-{env}` | `hd-myapp-evh-dev` |
| Redis Cache | `redis` | `{prefix}-{name}-redis-{env}` | `hd-myapp-redis-dev` |
| Service Bus | `sbns` | `{prefix}-{name}-sbns-{env}` | `hd-myapp-sbns-dev` |
| SignalR | `sigr` | `{prefix}-{name}-sigr-{env}` | `hd-myapp-sigr-dev` |
| Virtual Machine | `vm` | `{prefix}-{name}-vm-{env}` | `hd-myapp-vm-dev` |
| Storage Account | `st` | `{prefix}{name}st{env}` | `hdmyappstdev` |
| Container Registry | `cr` | `{prefix}{name}cr{env}` | `hdmyappcrdev` |

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
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) >= 0.24
- Azure subscription with Contributor permissions

### Validate the templates

```bash
# Lint all modules
for file in modules/*/main.bicep; do
  az bicep lint --file "$file"
done

# Build the orchestrator
az bicep build --file main.bicep
```

### Deploy to the dev environment

```bash
az deployment sub create \
  --location brazilsouth \
  --template-file main.bicep \
  --parameters environments/dev.bicepparam
```

### What-If (simulation)

```bash
az deployment sub what-if \
  --location brazilsouth \
  --template-file main.bicep \
  --parameters environments/dev.bicepparam
```

### Use a module individually

```bicep
// Example with prefix — generates the name: hd-myapp-kv-dev
module kv 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup('my-rg')
  params: {
    prefix: 'hd'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
  }
}

// Example without prefix — generates the name: myapp-kv-dev
module kv2 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault-no-prefix'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
  }
}

// Example with name (full override) — uses exactly the provided name
module kv3 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault-custom'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-keyvault-name'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
  }
}
```

## CI/CD with GitHub Actions

| Workflow | Trigger | Description |
|---|---|---|
| `validate.yml` | PR to `main` | Lint + Build + What-If |
| `deploy-dev.yml` | Push to `main` | Automatic deploy to dev |
| `deploy-staging.yml` | Manual | Deploy to staging |
| `deploy-prod.yml` | Manual + Approval | Deploy to production |

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
| `prefix` | string | `''` | Resource name prefix (e.g.: `hd`, `nvt`). If empty, the name is generated without a prefix |
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

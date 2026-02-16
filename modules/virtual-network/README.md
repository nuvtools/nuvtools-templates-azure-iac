# Virtual Network

Bicep Module for provisioning a Virtual Network following a configurable naming convention (`{prefix}-{workloadName}-vnet-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-vnet-{environment}`. The `name` parameter allows you to completely override the automatic name. Supports custom DNS servers, DDoS protection, and optional diagnostics via Log Analytics.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-vnet-dev)
module vnet 'modules/virtual-network/main.bicep' = {
  name: 'deploy-virtual-network'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    addressPrefixes: [
      '10.0.0.0/16'
    ]
  }
}

// Usage with a custom full name
module vnet2 'modules/virtual-network/main.bicep' = {
  name: 'deploy-virtual-network-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'minha-vnet-customizada'
    workloadName: 'myapp'
    environment: 'dev'
    addressPrefixes: [
      '10.0.0.0/16'
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is ignored. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `addressPrefixes` | `array` | *(required)* | Virtual network address prefixes (CIDR). Example: `['10.0.0.0/16']`. |
| `dnsServers` | `array` | `[]` | List of custom DNS servers. Leave empty to use Azure default DNS. |
| `enableDdosProtection` | `bool` | `false` | Enables DDoS protection on the virtual network. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created virtual network. |
| `name` | `string` | Name of the created virtual network. |

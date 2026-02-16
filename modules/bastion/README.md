# NuvTools - Bastion Host

Bicep Module for provisioning an Azure Bastion Host with a dedicated public IP, Basic and Standard SKU support, conditional tunneling, IP-based connection, link sharing, and optional diagnostics, following the NuvTools naming convention (`{prefix}-{workloadName}-bas-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-bas-{environment}`. The public IP follows the pattern `{prefix}-{workloadName}-pip-bas-{environment}`. The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-bas-dev and nvt-myapp-pip-bas-dev)
module bastion 'modules/bastion/main.bicep' = {
  name: 'deploy-bastion'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    skuName: 'Standard'
    subnetId: '/subscriptions/.../subnets/AzureBastionSubnet'
    enableTunneling: true
    enableIpConnect: true
    scaleUnits: 4
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}

// Usage with a fully custom name
module bastion2 'modules/bastion/main.bicep' = {
  name: 'deploy-bastion-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'meu-bastion-customizado'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    subnetId: '/subscriptions/.../subnets/AzureBastionSubnet'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Standard'` | Bastion Host SKU. Allowed values: `Basic`, `Standard`. |
| `subnetId` | `string` | *(required)* | AzureBastionSubnet subnet ID. The subnet must have the exact name `AzureBastionSubnet`. |
| `enableTunneling` | `bool` | `false` | Enables Bastion native tunneling (available only on the Standard SKU). |
| `enableIpConnect` | `bool` | `false` | Enables IP-based connection directly through Bastion (available only on the Standard SKU). |
| `scaleUnits` | `int` | `2` | Number of Bastion Host scale units. Min: 2, Max: 50. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Bastion Host. |
| `name` | `string` | Name of the created Bastion Host. |
| `dnsName` | `string` | DNS name of the Bastion Host. |

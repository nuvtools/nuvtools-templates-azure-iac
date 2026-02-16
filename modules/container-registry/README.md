# Container Registry

Bicep module for provisioning an Azure Container Registry with AcrPull role assignments and diagnostics following a configurable naming convention (`{workloadName}cr{environment}`). The name is alphanumeric, without hyphens, as required by Azure Container Registry. The `name` parameter allows you to completely override the automatic name. Supports Basic, Standard, and Premium SKUs, configurable public network access, zone redundancy, and conditional AcrPull role assignment.

## Usage

```bicep
// Generates: myappcrdev
module acr 'modules/container-registry/main.bicep' = {
  name: 'deploy-container-registry'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    skuName: 'Basic'
    acrPullPrincipalIds: [
      aksCluster.outputs.kubeletIdentityObjectId
    ]
  }
}

// Usage with a fully custom name
module acr2 'modules/container-registry/main.bicep' = {
  name: 'deploy-container-registry-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'mycustomacr'
    workloadName: 'myapp'
    environment: 'dev'
    skuName: 'Standard'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. Must be alphanumeric, without hyphens. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Basic'` | Container Registry SKU. Allowed values: `Basic`, `Standard`, `Premium`. |
| `adminUserEnabled` | `bool` | `false` | Enables the Container Registry admin user. |
| `publicNetworkAccess` | `string` | `'Enabled'` | Public network access control. Allowed values: `Enabled`, `Disabled`. |
| `zoneRedundancy` | `string` | `'Disabled'` | Enables zone redundancy (available only with the Premium SKU). Allowed values: `Disabled`, `Enabled`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for diagnostics. Required when `enableDiagnostics` is `true`. |
| `acrPullPrincipalIds` | `array` | `[]` | List of principal IDs that will receive the AcrPull role on the Container Registry. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Container Registry. |
| `name` | `string` | Name of the created Container Registry. |
| `loginServer` | `string` | Login server URL of the Container Registry. |

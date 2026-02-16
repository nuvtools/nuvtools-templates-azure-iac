# API Management

Bicep Module for provisioning an Azure API Management service with managed identity, custom domains, VNet integration, conditional auto-scaling, availability zones, and diagnostics, following a configurable naming convention (`{workloadName}-apim-{environment}`).

## Naming Convention

The resource name is automatically generated based on the `workloadName` and `environment` parameters:

- Pattern: `{workloadName}-apim-{environment}` (e.g., `myapp-apim-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Usage

```bicep
module apiManagement 'modules/api-management/main.bicep' = {
  name: 'deploy-api-management'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    skuName: 'Developer'
    skuCapacity: 1
    publisherName: 'Contoso'
    publisherEmail: 'admin@contoso.com'
    enableSystemAssignedIdentity: true
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name. Used to compose the resource name. Min: 2, Max: 20 characters. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Developer'` | API Management service SKU. Allowed values: `Consumption`, `Developer`, `Basic`, `Standard`, `Premium`. |
| `skuCapacity` | `int` | `1` | Capacity (number of units) of the API Management service. |
| `publisherName` | `string` | *(required)* | Publisher name of the API Management service. |
| `publisherEmail` | `string` | *(required)* | Publisher email of the API Management service. |
| `virtualNetworkType` | `string` | `'None'` | Virtual network integration type. Allowed values: `None`, `External`, `Internal`. |
| `subnetId` | `string` | `''` | Subnet ID for VNet integration. Required when `virtualNetworkType` is not `None`. |
| `enableSystemAssignedIdentity` | `bool` | `true` | Enables the System Assigned managed identity. |
| `customDomains` | `array` | `[]` | List of custom domains. Each object must contain: `type` (Proxy, Portal, DeveloperPortal, Management, or Scm), `hostName` (string), and `keyVaultSecretId` (string, optional). |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |
| `publicIpAddressId` | `string` | `''` | Public IP address ID for VNet deployments. |
| `enableAutoScale` | `bool` | `false` | Enables auto-scaling for the API Management service. |
| `minCapacity` | `int` | `1` | Minimum capacity for auto-scaling. |
| `maxCapacity` | `int` | `2` | Maximum capacity for auto-scaling. |
| `zones` | `array` | `[]` | Availability zones for the API Management service. Applicable only to the Premium SKU. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created API Management service. |
| `name` | `string` | Name of the created API Management service. |
| `gatewayUrl` | `string` | API Management gateway URL. |
| `portalUrl` | `string` | API Management developer portal URL. |
| `managementApiUrl` | `string` | API Management management API URL. |
| `principalId` | `string` | Managed identity (principal) ID of the API Management service. Empty when identity is not enabled. |

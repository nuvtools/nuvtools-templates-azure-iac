# Network Security Group

Bicep Module for provisioning a Network Security Group following a configurable naming convention (`{workloadName}-nsg-{environment}`). The `name` parameter allows you to completely override the automatic name. Supports custom security rules and optional diagnostics via Log Analytics.

## Usage

```bicep
// Generates: myapp-nsg-dev
module nsg 'modules/nsg/main.bicep' = {
  name: 'deploy-nsg'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    securityRules: [
      {
        name: 'AllowHTTPS'
        priority: 100
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourcePortRange: '*'
        destinationPortRange: '443'
        sourceAddressPrefix: '*'
        destinationAddressPrefix: '*'
      }
    ]
  }
}

// Usage with a custom full name
module nsg2 'modules/nsg/main.bicep' = {
  name: 'deploy-nsg-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-nsg'
    workloadName: 'myapp'
    environment: 'dev'
    securityRules: []
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is ignored. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `securityRules` | `array` | `[]` | List of security rules. Each rule must contain: `name`, `priority`, `direction`, `access`, `protocol`, `sourcePortRange`, `destinationPortRange`, `sourceAddressPrefix`, `destinationAddressPrefix`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Network Security Group. |
| `name` | `string` | Name of the created Network Security Group. |

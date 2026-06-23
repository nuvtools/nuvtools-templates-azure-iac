# Web App (App Service)

Bicep Module for provisioning a Linux/Windows Web App on an existing App Service Plan, with regional VNet integration, system and/or user-assigned managed identity and application settings (which may include Key Vault references), following a configurable naming convention (`{workloadName}-app-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-app-dev (Linux .NET, VNet-integrated, both identities)
module api 'modules/web-app/main.bicep' = {
  name: 'deploy-web-app'
  scope: resourceGroup('my-rg')
  params: {
    name: 'myapp-api-dev'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    appServicePlanId: plan.outputs.id
    linuxFxVersion: 'DOTNETCORE|10.0'
    httpsOnly: true
    alwaysOn: true
    virtualNetworkSubnetId: '/subscriptions/.../subnets/app-snet'
    userAssignedIdentityId: identity.outputs.id
    enableSystemAssignedIdentity: true
    healthCheckPath: '/health'
    appSettings: [
      { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.outputs.connectionString }
      { name: 'ConnectionStrings__Database', value: '@Microsoft.KeyVault(VaultName=myapp-kv-dev;SecretName=database)' }
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `appServicePlanId` | `string` | *(required)* | Resource ID of the App Service Plan that will host the web app. |
| `linux` | `bool` | `true` | Hosts a Linux container when `true`; Windows when `false`. |
| `linuxFxVersion` | `string` | `''` | Runtime stack for Linux apps (e.g., `DOTNETCORE|10.0`). Ignored for Windows apps. |
| `httpsOnly` | `bool` | `true` | Redirects all HTTP traffic to HTTPS when `true`. |
| `alwaysOn` | `bool` | `true` | Keeps the app warm (recommended for production and background workers). |
| `vnetRouteAllEnabled` | `bool` | `true` | Routes all outbound traffic through the integrated VNet when `true`. |
| `virtualNetworkSubnetId` | `string` | `''` | Resource ID of the subnet used for regional VNet integration. Empty disables integration. |
| `userAssignedIdentityId` | `string` | `''` | Resource ID of a user-assigned managed identity to attach. Empty attaches none. |
| `enableSystemAssignedIdentity` | `bool` | `true` | Enables the system-assigned managed identity. |
| `keyVaultReferenceIdentityId` | `string` | `''` | Resource ID of the identity used to resolve Key Vault references. Empty uses the system-assigned identity. |
| `appSettings` | `array` | `[]` | Application settings as `{ name, value }` objects. Values may be Key Vault references. |
| `healthCheckPath` | `string` | `''` | Relative health-check path (e.g., `/health`). Empty disables the health check. |
| `minTlsVersion` | `string` | `'1.2'` | Minimum TLS version accepted by the app. Allowed: `1.0`, `1.1`, `1.2`. |
| `ftpsState` | `string` | `'Disabled'` | FTP/FTPS publishing state. Allowed: `AllAllowed`, `FtpsOnly`, `Disabled`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Web App. |
| `name` | `string` | Name of the created Web App. |
| `defaultHostName` | `string` | Default host name of the Web App. |
| `principalId` | `string` | Principal (object) ID of the system-assigned identity. Empty when disabled. |

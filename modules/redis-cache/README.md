# Redis Cache

Bicep Module for provisioning an Azure Cache for Redis instance with SKU configuration, TLS, VNet injection (available on the Premium SKU), managed identity (System Assigned), firewall rules, and conditional diagnostics, following a configurable naming convention (`{workloadName}-redis-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-redis-dev
module redisCache 'modules/redis-cache/main.bicep' = {
  name: 'deploy-redis-cache'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    skuName: 'Standard'
    skuFamily: 'C'
    skuCapacity: 1
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}

// Usage with fully custom name
module redisCache2 'modules/redis-cache/main.bicep' = {
  name: 'deploy-redis-cache-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-redis'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
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
| `skuName` | `string` | `'Standard'` | Redis Cache SKU name. Allowed values: `Basic`, `Standard`, `Premium`. |
| `skuFamily` | `string` | `'C'` | Redis Cache SKU family. `C` for Basic/Standard, `P` for Premium. |
| `skuCapacity` | `int` | `1` | Redis Cache instance capacity (size). Valid values: 0-6 for Basic/Standard, 1-5 for Premium. |
| `enableNonSslPort` | `bool` | `false` | Enables the non-SSL port (6379). It is recommended to keep it disabled for better security. |
| `minimumTlsVersion` | `string` | `'1.2'` | Minimum TLS version allowed for connections. Allowed values: `1.0`, `1.1`, `1.2`. |
| `redisVersion` | `string` | `'6'` | Redis version. Allowed values: `4`, `6`. |
| `publicNetworkAccess` | `string` | `'Disabled'` | Defines whether public network access is enabled or disabled. Allowed values: `Enabled`, `Disabled`. |
| `subnetId` | `string` | `''` | Subnet ID for VNet injection. Available only for the Premium SKU. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |
| `redisConfiguration` | `object` | `{}` | Additional Redis configuration as key-value pairs (e.g.: `maxmemory-policy`, `maxmemory-reserved`). |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Azure Cache for Redis. |
| `name` | `string` | Name of the created Azure Cache for Redis. |
| `hostName` | `string` | Host name of the Azure Cache for Redis. |
| `sslPort` | `int` | SSL port of the Azure Cache for Redis. |

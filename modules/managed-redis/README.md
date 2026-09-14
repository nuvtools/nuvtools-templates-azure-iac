# Azure Managed Redis

Bicep Module for provisioning Azure Managed Redis (`Microsoft.Cache/redisEnterprise`) with its single `default` database, Microsoft Entra authentication, access policy assignments for managed identities, network access control and conditional diagnostics, following a configurable naming convention (`{workloadName}-amr-{environment}`). The `name` parameter allows you to completely override the automatic name.

**Use this instead of `redis-cache`.** Azure Cache for Redis (Basic, Standard, Premium) can no longer be created by new customers since April 1, 2026, nor by existing customers from October 1, 2026, and retires on September 30, 2028. See Microsoft's [retirement FAQ](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/retirement-faq).

## Defaults worth knowing

- **Entra only.** `accessKeysAuthentication` is `Disabled`, so the only way in is a Microsoft Entra token for a principal listed in `accessPolicyAssignments`. With StackExchange.Redis that is the `Microsoft.Azure.StackExchangeRedis` package and `ConfigureForAzureWithTokenCredentialAsync`.
- **Private by default.** `publicNetworkAccess` is `Disabled`. Azure Managed Redis has no service-endpoint option, so pair it with the `private-endpoint` module (group ID `redisEnterprise`) and the `privatelink.redis.azure.net` private DNS zone.
- **`EnterpriseCluster`.** One endpoint, with sharding handled behind it — the simplest policy behind a private endpoint, since the client never needs a path to individual nodes. Multi-key commands must stay within one hash slot. The policy cannot be changed after creation.
- **Port 10000**, TLS only.

## Usage

```bicep
// Generates: myapp-amr-prod
module managedRedis 'modules/managed-redis/main.bicep' = {
  name: 'deploy-managed-redis'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'prod'
    location: 'eastus2'
    skuName: 'Balanced_B0'
    highAvailability: 'Enabled'
    accessPolicyAssignments: [
      {
        name: 'appidentity'
        objectId: identity.outputs.principalId
      }
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}

// Private endpoint into the cluster
module redisPrivateEndpoint 'modules/private-endpoint/main.bicep' = {
  name: 'deploy-redis-pe'
  scope: resourceGroup('my-network-rg')
  params: {
    name: 'myapp-amr-pe-prod'
    workloadName: 'myapp'
    environment: 'prod'
    location: 'eastus2'
    subnetId: privateEndpointSubnetId
    privateConnectionResourceId: managedRedis.outputs.id
    groupIds: [
      'redisEnterprise'
    ]
    privateDnsZoneId: redisPrivateDnsZoneId // privatelink.redis.azure.net
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
| `skuName` | `string` | `'Balanced_B0'` | Cluster SKU (memory and throughput). `Balanced_B0` is the smallest. |
| `highAvailability` | `string` | `'Enabled'` | Replicates the data set within the region. `Disabled` halves the cost and removes the SLA. |
| `publicNetworkAccess` | `string` | `'Disabled'` | Whether the public endpoint answers. `Disabled` leaves a private endpoint as the only way in. |
| `minimumTlsVersion` | `string` | `'1.2'` | Minimum TLS version accepted. |
| `clusteringPolicy` | `string` | `'EnterpriseCluster'` | `OSSCluster`, `EnterpriseCluster` or `NoCluster`. Fixed at creation, except from `NoCluster`. |
| `evictionPolicy` | `string` | `'VolatileLRU'` | What is evicted when memory is full. The default evicts only keys that carry an expiry. |
| `port` | `int` | `10000` | TCP port of the database endpoint. Fixed at creation. |
| `accessKeysAuthentication` | `string` | `'Disabled'` | Whether the database accepts its access keys. |
| `accessPolicyAssignments` | `array` | `[]` | Principals granted the `default` data access policy: `{ name, objectId }`. `name` is 1-60 letters and digits. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the cluster — the private endpoint's target, with group ID `redisEnterprise`. |
| `name` | `string` | Name of the cluster. |
| `hostName` | `string` | Host name clients connect to (`<name>.<region>.redis.azure.net`). |
| `port` | `int` | Port of the database endpoint. |
| `endpoint` | `string` | `host:port`, ready for a StackExchange.Redis configuration string. |

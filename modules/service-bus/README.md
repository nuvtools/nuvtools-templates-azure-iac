# NuvTools - Service Bus

Bicep Module for provisioning an Azure Service Bus namespace with queues, topics, managed identity (System Assigned), zone redundancy, and conditional diagnostics, following the NuvTools naming convention (`{prefix}-{workloadName}-sbns-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-sbns-{environment}`. The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-sbns-dev)
module serviceBus 'modules/service-bus/main.bicep' = {
  name: 'deploy-service-bus'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    skuName: 'Standard'
    queues: [
      {
        name: 'orders-queue'
        maxSizeInMegabytes: 2048
        enablePartitioning: false
        deadLetteringOnExpiration: true
        maxDeliveryCount: 10
      }
    ]
    topics: [
      {
        name: 'notifications-topic'
        maxSizeInMegabytes: 1024
        enablePartitioning: false
      }
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}

// Usage with fully custom name
module serviceBus2 'modules/service-bus/main.bicep' = {
  name: 'deploy-service-bus-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'meu-servicebus-customizado'
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
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g.: `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Standard'` | Service Bus namespace SKU. Allowed values: `Basic`, `Standard`, `Premium`. |
| `skuCapacity` | `int` | `1` | Service Bus namespace capacity. Applicable only to the Premium SKU. |
| `zoneRedundant` | `bool` | `false` | Enables zone redundancy for the namespace. Applicable only to the Premium SKU. |
| `queues` | `array` | `[]` | List of queues to be created. Each object must contain: `name` (string), `maxSizeInMegabytes` (int, default 1024), `enablePartitioning` (bool, default false), `deadLetteringOnExpiration` (bool, default true), and `maxDeliveryCount` (int, default 10). |
| `topics` | `array` | `[]` | List of topics to be created. Each object must contain: `name` (string), `maxSizeInMegabytes` (int, default 1024), and `enablePartitioning` (bool, default false). |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Service Bus namespace. |
| `name` | `string` | Name of the created Service Bus namespace. |
| `namespaceFqdn` | `string` | FQDN of the Service Bus namespace. |

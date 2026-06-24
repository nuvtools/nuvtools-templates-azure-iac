# Service Bus

Bicep Module for provisioning an Azure Service Bus namespace with queues, topics, managed identity (System Assigned), zone redundancy, and conditional diagnostics, following a configurable naming convention (`{workloadName}-sbns-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-sbns-dev
module serviceBus 'modules/service-bus/main.bicep' = {
  name: 'deploy-service-bus'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    skuName: 'Standard'
    queues: [
      {
        name: 'orders-queue'
        maxSizeInMegabytes: 2048
        enablePartitioning: false
        requiresSession: false
        deadLetteringOnExpiration: true
        maxDeliveryCount: 10
        lockDuration: 'PT4M'
        defaultMessageTimeToLive: 'P14D'
        requiresDuplicateDetection: true
        duplicateDetectionHistoryTimeWindow: 'PT5M'
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
    name: 'my-custom-servicebus'
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
| `skuName` | `string` | `'Standard'` | Service Bus namespace SKU. Allowed values: `Basic`, `Standard`, `Premium`. |
| `skuCapacity` | `int` | `1` | Service Bus namespace capacity. Applicable only to the Premium SKU. |
| `zoneRedundant` | `bool` | `false` | Enables zone redundancy for the namespace. Applicable only to the Premium SKU. |
| `queues` | `array` | `[]` | List of queues to be created. Each object accepts: `name` (string), `maxSizeInMegabytes` (int, default 1024), `enablePartitioning` (bool, default false), `requiresSession` (bool, default false), `deadLetteringOnExpiration` (bool, default true), `maxDeliveryCount` (int, default 10), `lockDuration` (ISO 8601 duration, e.g. `PT4M`), `defaultMessageTimeToLive` (ISO 8601 duration, e.g. `P14D`), `requiresDuplicateDetection` (bool) and `duplicateDetectionHistoryTimeWindow` (ISO 8601 duration, e.g. `PT5M`). Omitted optional values fall back to the Service Bus defaults. `requiresDuplicateDetection` and `requiresSession` are immutable after creation. |
| `topics` | `array` | `[]` | List of topics to be created. Each object must contain: `name` (string), `maxSizeInMegabytes` (int, default 1024), and `enablePartitioning` (bool, default false). |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Service Bus namespace. |
| `name` | `string` | Name of the created Service Bus namespace. |
| `namespaceFqdn` | `string` | FQDN of the Service Bus namespace. |

# Event Hub

Bicep Module for provisioning an Azure Event Hub namespace with individual Event Hubs, consumer groups, auto-inflate, zone redundancy, and conditional diagnostics, following a configurable naming convention (`{workloadName}-evhns-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-evhns-dev
module eventHub 'modules/event-hub/main.bicep' = {
  name: 'deploy-event-hub'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    skuName: 'Standard'
    skuCapacity: 2
    isAutoInflateEnabled: true
    maximumThroughputUnits: 10
    eventHubs: [
      {
        name: 'orders'
        partitionCount: 4
        messageRetentionInDays: 3
        consumerGroups: [
          'processor'
          'analytics'
        ]
      }
      {
        name: 'notifications'
        partitionCount: 2
        messageRetentionInDays: 1
      }
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}

```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Standard'` | Event Hub namespace SKU. Allowed values: `Basic`, `Standard`, `Premium`. |
| `skuCapacity` | `int` | `1` | Capacity (throughput units) of the Event Hub namespace. |
| `isAutoInflateEnabled` | `bool` | `false` | Enables auto-inflate to automatically scale throughput units. |
| `maximumThroughputUnits` | `int` | `0` | Maximum number of throughput units when auto-inflate is enabled. Use `0` to disable. |
| `zoneRedundant` | `bool` | `false` | Enables zone redundancy for the namespace. |
| `eventHubs` | `array` | `[]` | List of Event Hubs to be created. Each object must contain: `name` (string), `partitionCount` (int, default 2), `messageRetentionInDays` (int, default 1), and `consumerGroups` (array of strings, optional). |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Event Hub namespace. |
| `name` | `string` | Name of the created Event Hub namespace. |
| `namespaceFqdn` | `string` | FQDN of the Event Hub namespace (Service Bus endpoint). |

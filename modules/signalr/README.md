# SignalR Service

Bicep Module for provisioning an Azure SignalR service with configurable service mode (Default, Serverless, Classic), allowed origins (CORS), live trace, managed identity (System Assigned), and conditional diagnostics, following a configurable naming convention (`{workloadName}-sigr-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-sigr-dev
module signalR 'modules/signalr/main.bicep' = {
  name: 'deploy-signalr'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    skuName: 'Standard_S1'
    skuCapacity: 1
    serviceMode: 'Default'
    enableConnectivityLogs: true
    enableLiveTrace: true
    allowedOrigins: [
      'https://myapp.example.com'
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}

// Usage with fully custom name
module signalR2 'modules/signalr/main.bicep' = {
  name: 'deploy-signalr-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-signalr'
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
| `skuName` | `string` | `'Standard_S1'` | SignalR service SKU. |
| `skuCapacity` | `int` | `1` | SignalR service capacity (number of units). |
| `serviceMode` | `string` | `'Default'` | SignalR service operation mode. Allowed values: `Default`, `Serverless`, `Classic`. |
| `enableConnectivityLogs` | `bool` | `true` | Enables connectivity logs in live trace. |
| `enableMessagingLogs` | `bool` | `false` | Enables messaging logs in live trace. |
| `enableLiveTrace` | `bool` | `false` | Enables live trace for real-time monitoring. |
| `allowedOrigins` | `array` | `['*']` | List of allowed origins for CORS. Use `['*']` to allow all origins. |
| `publicNetworkAccess` | `string` | `'Enabled'` | Defines whether public network access is enabled or disabled. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created SignalR service. |
| `name` | `string` | Name of the created SignalR service. |
| `hostName` | `string` | Host name of the SignalR service. |
| `publicPort` | `int` | Public port of the SignalR service. |

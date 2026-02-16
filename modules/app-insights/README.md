# Application Insights

Bicep module for provisioning Application Insights (workspace-based) with configurable sampling and retention following a configurable naming convention (`{workloadName}-appi-{environment}`). Requires an existing Log Analytics workspace for linking.

## Naming Convention

The resource name is automatically generated based on the `workloadName` and `environment` parameters:

- Pattern: `{workloadName}-appi-{environment}` (e.g., `myapp-appi-dev`)
- Override: use the `name` parameter to define a fully custom name, ignoring the automatic convention.

## Usage

```bicep
module appInsights 'modules/app-insights/main.bicep' = {
  name: 'deploy-app-insights'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    retentionInDays: 90
    samplingPercentage: 100
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `applicationType` | `string` | `'web'` | Type of application monitored by Application Insights. |
| `logAnalyticsWorkspaceId` | `string` | *(required)* | ID of the Log Analytics workspace to which Application Insights will be linked. |
| `disableIpMasking` | `bool` | `false` | Disables IP address masking in telemetry data. |
| `retentionInDays` | `int` | `90` | Data retention period in days. |
| `samplingPercentage` | `int` | `100` | Ingestion sampling percentage (0 to 100). A value of 100 means no sampling. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Application Insights. |
| `name` | `string` | Name of the created Application Insights. |
| `instrumentationKey` | `string` | Application Insights instrumentation key. Should be stored securely. |
| `connectionString` | `string` | Application Insights connection string. Should be stored securely. |

# NuvTools - Log Analytics Workspace

Bicep Module for provisioning an Azure Log Analytics workspace with configurable retention, daily ingestion quota, and optional linked storage accounts, following the NuvTools naming convention (`{prefix}-{workloadName}-log-{environment}`).

## Naming Convention

The resource name is automatically generated based on the `prefix`, `workloadName`, and `environment` parameters:

- With prefix: `{prefix}-{workloadName}-log-{environment}` (e.g., `nvt-myapp-log-dev`)
- Without prefix: `{workloadName}-log-{environment}` (e.g., `myapp-log-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Usage

```bicep
module logAnalytics 'modules/log-analytics/main.bicep' = {
  name: 'deploy-log-analytics'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    retentionInDays: 90
    dailyQuotaGb: 5
    linkedStorageAccountIds: [
      '/subscriptions/.../storageAccounts/mystorageaccount'
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name. Used to compose the resource name. Min: 2, Max: 20 characters. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'PerGB2018'` | Log Analytics workspace SKU. |
| `retentionInDays` | `int` | `30` | Data retention period in days. Min: 30, Max: 730. |
| `dailyQuotaGb` | `int` | `-1` | Daily ingestion quota in GB. The value `-1` means no limit. |
| `linkedStorageAccountIds` | `array` | `[]` | List of storage account IDs to be linked to the workspace (linked storage accounts). |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Log Analytics workspace. |
| `name` | `string` | Name of the created Log Analytics workspace. |
| `customerId` | `string` | Customer ID of the workspace, used for agent configuration. |

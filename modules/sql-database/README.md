# NuvTools - SQL Database

Bicep Module for provisioning an Azure SQL Database with serverless SKU support, short-term backup policy, conditional Long-Term Retention (LTR), and diagnostics, following the NuvTools naming convention (`{prefix}-{workloadName}-sqldb-{environment}`).

## Naming Convention

The resource name is automatically generated based on the `prefix`, `workloadName`, and `environment` parameters:

- With prefix: `{prefix}-{workloadName}-sqldb-{environment}` (e.g., `nvt-myapp-sqldb-dev`)
- Without prefix: `{workloadName}-sqldb-{environment}` (e.g., `myapp-sqldb-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Usage

```bicep
module sqlDatabase 'modules/sql-database/main.bicep' = {
  name: 'deploy-sql-database'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    sqlServerName: 'nvt-myapp-sql-dev'
    skuName: 'GP_S_Gen5_1'
    skuTier: 'GeneralPurpose'
    maxSizeBytes: 34359738368
    autoPauseDelay: 60
    backupRetentionDays: 14
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
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
| `sqlServerName` | `string` | *(required)* | Name of the existing SQL Server where the database will be created. |
| `skuName` | `string` | `'GP_S_Gen5_1'` | Database SKU name. The default `GP_S_Gen5_1` corresponds to serverless mode. |
| `skuTier` | `string` | `'GeneralPurpose'` | Database SKU tier. |
| `maxSizeBytes` | `int` | `34359738368` | Maximum database size in bytes. The default is 34359738368 (32 GB). |
| `collation` | `string` | `'SQL_Latin1_General_CP1_CI_AS'` | Database collation. |
| `autoPauseDelay` | `int` | `60` | Time in minutes for automatic pause of the serverless database. The value `-1` disables automatic pause. |
| `minCapacity` | `string` | `'0.5'` | Minimum vCore capacity for the serverless database. |
| `zoneRedundant` | `bool` | `false` | Enables zone redundancy for the database. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |
| `backupRetentionDays` | `int` | `7` | Number of days for short-term backup retention. Min: 1, Max: 35. |
| `enableLongTermRetention` | `bool` | `false` | Enables the Long-Term Retention (LTR) policy. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created SQL database. |
| `name` | `string` | Name of the created SQL database. |

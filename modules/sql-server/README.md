# NuvTools - SQL Server

Bicep Module for provisioning an Azure SQL Server with managed identity (System Assigned), Azure AD administrator configuration, auditing policy, Advanced Threat Protection, vulnerability assessment, and conditional diagnostics, following the NuvTools naming convention (`{prefix}-{workloadName}-sql-{environment}`).

## Naming Convention

The resource name is automatically generated based on the `prefix`, `workloadName`, and `environment` parameters:

- With prefix: `{prefix}-{workloadName}-sql-{environment}` (e.g., `nvt-myapp-sql-dev`)
- Without prefix: `{workloadName}-sql-{environment}` (e.g., `myapp-sql-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Usage

```bicep
module sqlServer 'modules/sql-server/main.bicep' = {
  name: 'deploy-sql-server'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    administratorLogin: 'sqladmin'
    administratorPassword: 'S3cur3P@ssw0rd!'
    enableAuditing: true
    storageAccountId: '/subscriptions/.../storageAccounts/myauditsa'
    enableAdvancedThreatProtection: true
    azureAdAdministrator: {
      login: 'admin@contoso.com'
      sid: '00000000-0000-0000-0000-000000000000'
      tenantId: '00000000-0000-0000-0000-000000000000'
    }
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
| `administratorLogin` | `string` | *(required)* | SQL Server administrator login. |
| `administratorPassword` | `string` (secure) | *(required)* | SQL Server administrator password. |
| `minimalTlsVersion` | `string` | `'1.2'` | Minimum allowed TLS version for connections. |
| `publicNetworkAccess` | `string` | `'Disabled'` | Defines whether public network access is enabled or disabled. Allowed values: `Enabled`, `Disabled`. |
| `azureAdAdministrator` | `object` | `{}` | Azure Active Directory administrator configuration. Object with the following properties: `login` (string), `sid` (string), and `tenantId` (string). |
| `enableAuditing` | `bool` | `true` | Enables the SQL Server auditing policy. |
| `storageAccountId` | `string` | `''` | Storage account ID used to store audit logs. Required when `enableAuditing` is `true`. |
| `enableAdvancedThreatProtection` | `bool` | `true` | Enables Advanced Threat Protection. |
| `enableVulnerabilityAssessment` | `bool` | `false` | Enables Vulnerability Assessment. |
| `vulnerabilityAssessmentStorageAccountId` | `string` | `''` | Storage account ID to store vulnerability assessment results. Required when `enableVulnerabilityAssessment` is `true`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created SQL Server. |
| `name` | `string` | Name of the created SQL Server. |
| `fullyQualifiedDomainName` | `string` | Fully qualified domain name of the SQL Server (e.g., myserver.database.windows.net). |

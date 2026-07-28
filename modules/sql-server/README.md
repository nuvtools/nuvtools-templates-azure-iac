# SQL Server

Bicep Module for provisioning an Azure SQL Server with managed identity (System Assigned), Azure AD administrator configuration, auditing policy, Advanced Threat Protection, vulnerability assessment, firewall rules, and conditional diagnostics, following a configurable naming convention (`{workloadName}-sql-{environment}`).

## Authentication

Three shapes, chosen by which parameters you pass:

| | `administratorLogin` | `azureAdAdministrator` | `azureAdOnlyAuthentication` |
|---|---|---|---|
| SQL only | set | — | `false` |
| Both | set | set | `false` |
| Entra only | *empty* | set | `true` |

`azureAdOnlyAuthentication` is ignored when no `azureAdAdministrator` is given — the combination
would leave the server with no administrator at all.

An Entra-only server is created with **no SQL login**, so there is no shared password anywhere.
Point `azureAdAdministrator.sid` at a security **group** rather than a person: membership then
governs access without a redeploy, and the group is `dbo` in every database on the server.

Applications reach an Entra-only server with their managed identity —
`Authentication=Active Directory Managed Identity;User Id=<client-id>` — which requires a contained
user created inside each database (`CREATE USER [<identity-name>] FROM EXTERNAL PROVIDER`). That is
a data-plane operation Bicep cannot perform; it has to run once per database, as a member of the
Entra admin group.

## Network access

The production path is `publicNetworkAccess: 'Disabled'` plus a private endpoint — the firewall is then irrelevant. When the server is opened (`publicNetworkAccess: 'Enabled'`, e.g. a development environment reached from a workstation), `allowAzureServices` and `firewallRules` are what let callers in.

The rules are created regardless of `publicNetworkAccess`: they are inert while the server is closed, and gating them would delete rules already deployed alongside a private endpoint.

## Naming Convention

The resource name is automatically generated based on the `workloadName` and `environment` parameters:

- Pattern: `{workloadName}-sql-{environment}` (e.g., `myapp-sql-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Usage

```bicep
module sqlServer 'modules/sql-server/main.bicep' = {
  name: 'deploy-sql-server'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    administratorLogin: 'sqladmin'
    administratorPassword: 'S3cur3P@ssw0rd!'
    enableAuditing: true
    storageAccountId: '/subscriptions/.../storageAccounts/myauditsa'
    enableAdvancedThreatProtection: true
    // Public access reached from known IPs (development environments).
    publicNetworkAccess: 'Enabled'
    firewallRules: [
      { name: 'dev-workstation', startIpAddress: '203.0.113.10', endIpAddress: '203.0.113.10' }
    ]
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
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `administratorLogin` | `string` | `''` | SQL Server administrator login. Empty creates the server with no SQL authentication — see [Authentication](#authentication). |
| `administratorPassword` | `string` (secure) | `''` | SQL Server administrator password. Required when `administratorLogin` is set. |
| `minimalTlsVersion` | `string` | `'1.2'` | Minimum allowed TLS version for connections. |
| `publicNetworkAccess` | `string` | `'Disabled'` | Defines whether public network access is enabled or disabled. Allowed values: `Enabled`, `Disabled`. |
| `azureAdAdministrator` | `object` | `{}` | Azure Active Directory administrator configuration. Object with the following properties: `login` (string), `sid` (string), and `tenantId` (string). |
| `azureAdOnlyAuthentication` | `bool` | `false` | Disables SQL authentication, leaving Entra ID as the only way in. Ignored unless `azureAdAdministrator` is set. |
| `allowAzureServices` | `bool` | `true` | Adds the `AllowAzureServices` firewall rule (0.0.0.0). Only takes effect when `publicNetworkAccess` is `Enabled`. |
| `firewallRules` | `array` | `[]` | Additional firewall rules. Array of objects with `name`, `startIpAddress` and `endIpAddress`. Only take effect when `publicNetworkAccess` is `Enabled`. |
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

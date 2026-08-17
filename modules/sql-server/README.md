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

No rule is submitted while `publicNetworkAccess` is `Disabled`. A closed server does not hold inert rules — it refuses to have any, and the deployment fails with `DenyPublicEndpointEnabled`.

## Auditing

`enableAuditing` writes the trail to two independent places, and neither implies the other:

| sink | driven by | retention |
|---|---|---|
| Log Analytics | `logAnalyticsWorkspaceId` | the workspace's |
| Storage account | `storageAccountId` | 90 days |

**Server-level auditing surfaces on the `master` database, not on the server.** The server resource exposes no log categories at all — only `AllMetrics` — so the module puts a second diagnostic setting (`{name}-audit-diag`, category `SQLSecurityAuditEvents`) on `master`. Without it `isAzureMonitorTargetEnabled` is set but nothing carries the records, and the audit exists only as blobs.

That setting follows `enableAuditing`, not `enableDiagnostics`: an audit trail that cannot be queried is the failure this closes, so it is not optional telemetry. Supply a workspace whenever you enable auditing.

Only `SQLSecurityAuditEvents` is enabled. `DevOpsOperationsAudit` is a separate trail with its own reason to exist and is not switched on by proxy, and the operational log categories belong to the `sql-database` module, on the databases they actually describe.

`storageAccountId` is optional — Log Analytics alone is a complete configuration. When supplied, the module reads the account's blob endpoint and key off the account itself, so it may live in another resource group or subscription.

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
| `allowAzureServices` | `bool` | `true` | Adds the `AllowAzureServices` firewall rule (0.0.0.0). Ignored while `publicNetworkAccess` is `Disabled` — Azure rejects the write rather than storing an inert rule. |
| `firewallRules` | `array` | `[]` | Additional firewall rules. Array of objects with `name`, `startIpAddress` and `endIpAddress`. Ignored while `publicNetworkAccess` is `Disabled` — Azure rejects the write rather than storing inert rules. |
| `enableAuditing` | `bool` | `true` | Enables the SQL Server auditing policy. With `logAnalyticsWorkspaceId` set, the trail is also routed to that workspace and becomes queryable with KQL. |
| `storageAccountId` | `string` | `''` | Storage account receiving the audit log. Optional: auditing to Log Analytics alone is a complete configuration. |
| `enableAdvancedThreatProtection` | `bool` | `true` | Enables Advanced Threat Protection. |
| `enableVulnerabilityAssessment` | `bool` | `false` | Enables Vulnerability Assessment. |
| `vulnerabilityAssessmentStorageAccountId` | `string` | `''` | Storage account ID to store vulnerability assessment results. Required when `enableVulnerabilityAssessment` is `true`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID. Required when `enableDiagnostics` is `true`, and also consumed by `enableAuditing` to make the audit trail queryable. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created SQL Server. |
| `name` | `string` | Name of the created SQL Server. |
| `fullyQualifiedDomainName` | `string` | Fully qualified domain name of the SQL Server (e.g., myserver.database.windows.net). |

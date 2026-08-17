// ---------------------------------------------------------------------------
// Bicep Module: SQL Server
// Creates an Azure SQL Server with auditing, advanced threat protection,
// vulnerability assessments and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'SQL Server'
metadata description = 'Module for creating an Azure SQL Server with auditing, threat protection, vulnerability assessments and diagnostics following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Full resource name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the resource name when name is not provided.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('SQL Server administrator login. Leave empty to create the server without SQL authentication, which requires azureAdAdministrator to be set.')
param administratorLogin string = ''

@description('SQL Server administrator password. Required when administratorLogin is set.')
@secure()
param administratorPassword string = ''

@description('Minimum TLS version allowed for connections.')
param minimalTlsVersion string = '1.2'

@description('Defines whether public network access is enabled or disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Azure Active Directory administrator configuration. Object with properties: login (string), sid (string) and tenantId (string).')
param azureAdAdministrator object = {}

@description('Disables SQL authentication, leaving Entra ID as the only way to connect. Requires azureAdAdministrator to be set: without it the server would have no administrator at all.')
param azureAdOnlyAuthentication bool = false

@description('Adds a firewall rule allowing access from Azure services (0.0.0.0). Ignored while publicNetworkAccess is Disabled — Azure rejects the write rather than storing an inert rule.')
param allowAzureServices bool = true

@description('Additional firewall rules. Array of objects with name, startIpAddress and endIpAddress. Ignored while publicNetworkAccess is Disabled — Azure rejects the write rather than storing inert rules.')
param firewallRules array = []

@description('Enables the SQL Server auditing policy.')
param enableAuditing bool = true

@description('Storage account ID used to store audit logs. Required when enableAuditing is true.')
param storageAccountId string = ''

@description('Enables Advanced Threat Protection.')
param enableAdvancedThreatProtection bool = true

@description('Enables Vulnerability Assessment.')
param enableVulnerabilityAssessment bool = false

@description('Storage account ID used to store vulnerability assessment results. Required when enableVulnerabilityAssessment is true.')
param vulnerabilityAssessmentStorageAccountId string = ''

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-sql-{environment}
var autoName = '${workloadName}-sql-${environment}'
var sqlServerName = empty(name) ? autoName : name

// Checks if the Azure AD administrator was provided
var hasAzureAdAdmin = !empty(azureAdAdministrator)

// Entra-only is only coherent with an Entra administrator to fall back on; asking for it
// without one would produce a server nobody can sign in to.
var entraOnly = azureAdOnlyAuthentication && hasAzureAdAdmin

// A server created without a SQL login is the Entra-only case. Sending empty strings
// instead of omitting the properties is rejected, so they collapse to null.
var hasSqlAdmin = !empty(administratorLogin)

// Every firewall rule below hangs off this. A closed server does not merely ignore
// firewall rules — it refuses to have any, failing the deployment with
// DenyPublicEndpointEnabled, so the rules must not be submitted at all.
var publicAccessEnabled = publicNetworkAccess == 'Enabled'

// The auditing and vulnerability-assessment policies are given a storage account by
// resource ID but want a blob endpoint URI, so the endpoint is read off the account
// itself. Composing it as a string would both hardcode a cloud-specific suffix and
// trip the no-hardcoded-env-urls rule. The placeholder keeps the segment indexing
// valid when no account is supplied; the resources that use it are off in that case.
var auditStorageIdSegments = split(
  empty(storageAccountId) ? resourceId('Microsoft.Storage/storageAccounts', 'placeholder') : storageAccountId,
  '/'
)
var hasAuditStorage = enableAuditing && !empty(storageAccountId)

var vulnerabilityStorageIdSegments = split(
  empty(vulnerabilityAssessmentStorageAccountId)
    ? resourceId('Microsoft.Storage/storageAccounts', 'placeholder')
    : vulnerabilityAssessmentStorageAccountId,
  '/'
)
var hasVulnerabilityStorage = enableVulnerabilityAssessment && !empty(vulnerabilityAssessmentStorageAccountId)

// =============================================================================
// Resources
// =============================================================================

resource sqlServer 'Microsoft.Sql/servers@2025-01-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: hasSqlAdmin ? administratorLogin : null
    administratorLoginPassword: hasSqlAdmin ? administratorPassword : null
    version: '12.0'
    minimalTlsVersion: minimalTlsVersion
    publicNetworkAccess: publicNetworkAccess
    administrators: hasAzureAdAdmin
      ? {
          administratorType: 'ActiveDirectory'
          login: azureAdAdministrator.login
          sid: azureAdAdministrator.sid
          tenantId: azureAdAdministrator.tenantId
          azureADOnlyAuthentication: entraOnly
        }
      : null
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Firewall rule to allow access from Azure services (0.0.0.0 - 0.0.0.0)
resource firewallRuleAllowAzureServices 'Microsoft.Sql/servers/firewallRules@2025-01-01' = if (allowAzureServices && publicAccessEnabled) {
  name: 'AllowAzureServices'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Additional firewall rules, on the same gate: a server reached over a private
// endpoint has publicNetworkAccess Disabled and rejects every rule write.
resource customFirewallRules 'Microsoft.Sql/servers/firewallRules@2025-01-01' = [
  for rule in (publicAccessEnabled ? firewallRules : []): {
    name: rule.name
    parent: sqlServer
    properties: {
      startIpAddress: rule.startIpAddress
      endIpAddress: rule.endIpAddress
    }
  }
]

// Storage account receiving the audit log, read for its blob endpoint and key. May
// live in another resource group or subscription, hence the parsed scope.
resource auditStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = if (hasAuditStorage) {
  name: last(auditStorageIdSegments)
  scope: resourceGroup(auditStorageIdSegments[2], auditStorageIdSegments[4])
}

// Auditing policy - conditionally enabled. With no storage account it still audits to
// Log Analytics through isAzureMonitorTargetEnabled; the storage properties then have
// to be absent rather than empty, which ARM rejects.
resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2025-01-01' = if (enableAuditing) {
  name: 'default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    storageEndpoint: hasAuditStorage ? auditStorageAccount!.properties.primaryEndpoints.blob : null
    storageAccountSubscriptionId: hasAuditStorage ? auditStorageIdSegments[2] : null
    storageAccountAccessKey: hasAuditStorage ? auditStorageAccount!.listKeys().keys[0].value : null
    retentionDays: hasAuditStorage ? 90 : null
  }
}

// Security alert policy (Advanced Threat Protection) - conditionally enabled
resource securityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2025-01-01' = if (enableAdvancedThreatProtection) {
  name: 'Default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
  }
}

// Storage account receiving the scan results, read for its blob endpoint and key.
resource vulnerabilityStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = if (hasVulnerabilityStorage) {
  name: last(vulnerabilityStorageIdSegments)
  scope: resourceGroup(vulnerabilityStorageIdSegments[2], vulnerabilityStorageIdSegments[4])
}

// Vulnerability assessment - conditionally enabled. primaryEndpoints.blob already
// carries its trailing slash, so the container name appends directly.
resource vulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2025-01-01' = if (hasVulnerabilityStorage) {
  name: 'default'
  parent: sqlServer
  properties: {
    storageContainerPath: '${vulnerabilityStorageAccount!.properties.primaryEndpoints.blob}vulnerability-assessment'
    storageAccountAccessKey: vulnerabilityStorageAccount!.listKeys().keys[0].value
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
    }
  }
  dependsOn: [
    securityAlertPolicy
  ]
}

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${sqlServerName}-diag'
  scope: sqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created SQL Server.')
output id string = sqlServer.id

@description('Name of the created SQL Server.')
output name string = sqlServer.name

@description('Fully qualified domain name of the SQL Server (e.g., myserver.database.windows.net).')
output fullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName

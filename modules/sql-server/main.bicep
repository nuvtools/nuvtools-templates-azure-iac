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

@description('SQL Server administrator login.')
param administratorLogin string

@description('SQL Server administrator password.')
@secure()
param administratorPassword string

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

// =============================================================================
// Resources
// =============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: '12.0'
    minimalTlsVersion: minimalTlsVersion
    publicNetworkAccess: publicNetworkAccess
    administrators: hasAzureAdAdmin
      ? {
          administratorType: 'ActiveDirectory'
          login: azureAdAdministrator.login
          sid: azureAdAdministrator.sid
          tenantId: azureAdAdministrator.tenantId
          azureADOnlyAuthentication: false
        }
      : null
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Firewall rule to allow access from Azure services (0.0.0.0 - 0.0.0.0)
resource firewallRuleAllowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  name: 'AllowAzureServices'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Auditing policy - conditionally enabled
resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = if (enableAuditing) {
  name: 'default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    storageEndpoint: !empty(storageAccountId) ? '${storageAccountId}' : ''
    retentionDays: 90
  }
}

// Security alert policy (Advanced Threat Protection) - conditionally enabled
resource securityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = if (enableAdvancedThreatProtection) {
  name: 'Default'
  parent: sqlServer
  properties: {
    state: 'Enabled'
  }
}

// Vulnerability assessment - conditionally enabled
resource vulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-08-01-preview' = if (enableVulnerabilityAssessment && !empty(vulnerabilityAssessmentStorageAccountId)) {
  name: 'default'
  parent: sqlServer
  properties: {
    storageContainerPath: '${vulnerabilityAssessmentStorageAccountId}vulnerability-assessment'
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

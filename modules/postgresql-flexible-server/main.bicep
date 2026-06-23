// ---------------------------------------------------------------------------
// Bicep Module: PostgreSQL Flexible Server
// Creates an Azure Database for PostgreSQL Flexible Server with configurable
// SKU, storage, backup, high availability, public or VNet-integrated access
// and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'PostgreSQL Flexible Server'
metadata description = 'Module for creating an Azure Database for PostgreSQL Flexible Server with configurable SKU, storage, backup, high availability, network access and diagnostics following configurable naming conventions.'
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

@description('PostgreSQL administrator login.')
param administratorLogin string

@description('PostgreSQL administrator password.')
@secure()
param administratorPassword string

@description('Major PostgreSQL engine version.')
@allowed([
  '13'
  '14'
  '15'
  '16'
  '17'
])
param postgresqlVersion string = '16'

@description('Compute SKU name (e.g., Standard_B1ms, Standard_D2s_v3, Standard_E2ds_v5).')
param skuName string = 'Standard_B1ms'

@description('Compute SKU tier.')
@allowed([
  'Burstable'
  'GeneralPurpose'
  'MemoryOptimized'
])
param skuTier string = 'Burstable'

@description('Allocated storage size in GB.')
@allowed([
  32
  64
  128
  256
  512
  1024
  2048
  4096
  8192
  16384
])
param storageSizeGB int = 32

@description('Enables storage auto-grow.')
@allowed([
  'Enabled'
  'Disabled'
])
param storageAutoGrow string = 'Enabled'

@description('Number of days to retain backups.')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enables geo-redundant backups.')
@allowed([
  'Enabled'
  'Disabled'
])
param geoRedundantBackup string = 'Disabled'

@description('High availability mode. ZoneRedundant and SameZone require a GeneralPurpose or MemoryOptimized tier.')
@allowed([
  'Disabled'
  'ZoneRedundant'
  'SameZone'
])
param highAvailabilityMode string = 'Disabled'

@description('Availability zone for the primary server. Empty lets Azure choose.')
param availabilityZone string = ''

@description('Defines whether public network access is enabled or disabled. Ignored when delegatedSubnetResourceId is provided (VNet-integrated).')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Resource ID of the delegated subnet for VNet integration (private access). When set, the server is created with private access and firewall rules are not applied.')
param delegatedSubnetResourceId string = ''

@description('Resource ID of the private DNS zone to link for VNet integration. Required when delegatedSubnetResourceId is provided.')
param privateDnsZoneArmResourceId string = ''

@description('Adds a firewall rule allowing access from Azure services (0.0.0.0). Applies only when using public access.')
param allowAzureServices bool = false

@description('Additional firewall rules. Array of objects with name, startIpAddress and endIpAddress. Applies only when using public access.')
param firewallRules array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-psql-{environment}
var autoName = '${workloadName}-psql-${environment}'
var postgresqlServerName = empty(name) ? autoName : name

// VNet-integrated (private access) when a delegated subnet is provided.
var usePrivateAccess = !empty(delegatedSubnetResourceId)

// =============================================================================
// Resources
// =============================================================================

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: postgresqlServerName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    version: postgresqlVersion
    availabilityZone: availabilityZone
    storage: {
      storageSizeGB: storageSizeGB
      autoGrow: storageAutoGrow
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup
    }
    highAvailability: {
      mode: highAvailabilityMode
    }
    network: usePrivateAccess
      ? {
          delegatedSubnetResourceId: delegatedSubnetResourceId
          privateDnsZoneArmResourceId: privateDnsZoneArmResourceId
        }
      : {
          publicNetworkAccess: publicNetworkAccess
        }
  }
}

// Firewall rule to allow access from Azure services (0.0.0.0 - 0.0.0.0) - public access only
resource firewallRuleAllowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = if (!usePrivateAccess && allowAzureServices) {
  name: 'AllowAzureServices'
  parent: postgresqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Additional firewall rules - public access only
resource customFirewallRules 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = [
  for rule in firewallRules: if (!usePrivateAccess) {
    name: rule.name
    parent: postgresqlServer
    properties: {
      startIpAddress: rule.startIpAddress
      endIpAddress: rule.endIpAddress
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${postgresqlServerName}-diag'
  scope: postgresqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'PostgreSQLLogs'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexSessions'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexQueryStoreRuntime'
        enabled: true
      }
      {
        category: 'PostgreSQLFlexQueryStoreWaitStats'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created PostgreSQL Flexible Server.')
output id string = postgresqlServer.id

@description('Name of the created PostgreSQL Flexible Server.')
output name string = postgresqlServer.name

@description('Fully qualified domain name of the PostgreSQL Flexible Server (e.g., myserver.postgres.database.azure.com).')
output fullyQualifiedDomainName string = postgresqlServer.properties.fullyQualifiedDomainName

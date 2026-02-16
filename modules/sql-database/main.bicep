// ---------------------------------------------------------------------------
// Bicep Module: SQL Database
// Creates an Azure SQL Database with serverless SKU configuration,
// backup policies and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'SQL Database'
metadata description = 'Module for creating an Azure SQL Database with serverless SKU, short-term and long-term backup policies and diagnostics following configurable naming conventions.'
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

@description('Name of the existing SQL Server where the database will be created.')
param sqlServerName string

@description('Database SKU name. The default GP_S_Gen5_1 corresponds to serverless mode.')
param skuName string = 'GP_S_Gen5_1'

@description('Database SKU tier.')
param skuTier string = 'GeneralPurpose'

@description('Maximum database size in bytes. Default is 34359738368 (32 GB).')
param maxSizeBytes int = 34359738368

@description('Database collation.')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'

@description('Time in minutes for automatic pause of the serverless database. A value of -1 disables automatic pause.')
param autoPauseDelay int = 60

@description('Minimum vCore capacity for the serverless database.')
param minCapacity string = '0.5'

@description('Enables zone redundancy for the database.')
param zoneRedundant bool = false

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('Number of days for short-term backup retention.')
@minValue(1)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enables the long-term retention policy (Long-Term Retention).')
param enableLongTermRetention bool = false

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-sqldb-{environment}
var autoName = '${workloadName}-sqldb-${environment}'
var databaseName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing SQL Server
resource sqlServer 'Microsoft.Sql/servers@2024-05-01-preview' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  name: databaseName
  parent: sqlServer
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    collation: collation
    maxSizeBytes: maxSizeBytes
    autoPauseDelay: autoPauseDelay
    minCapacity: json(minCapacity)
    zoneRedundant: zoneRedundant
    createMode: 'Default'
    requestedBackupStorageRedundancy: zoneRedundant ? 'Zone' : 'Local'
  }
}

// Short-term backup policy
resource shortTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2024-05-01-preview' = {
  name: 'default'
  parent: sqlDatabase
  properties: {
    retentionDays: backupRetentionDays
    diffBackupIntervalInHours: 12
  }
}

// Long-term retention policy - conditionally enabled
resource longTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies@2024-05-01-preview' = if (enableLongTermRetention) {
  name: 'default'
  parent: sqlDatabase
  properties: {
    weeklyRetention: 'P5W'
    monthlyRetention: 'P12M'
    yearlyRetention: 'P10Y'
    weekOfYear: 38
  }
}

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${databaseName}-diag'
  scope: sqlDatabase
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
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'AutomaticTuning'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
      {
        category: 'Blocks'
        enabled: true
      }
      {
        category: 'Deadlocks'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created SQL database.')
output id string = sqlDatabase.id

@description('Name of the created SQL database.')
output name string = sqlDatabase.name

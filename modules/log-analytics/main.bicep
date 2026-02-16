// ---------------------------------------------------------------------------
// Bicep Module: Log Analytics Workspace
// Creates a Log Analytics Workspace with configurable retention, daily cap,
// and optional linked storage accounts.
// ---------------------------------------------------------------------------

metadata name = 'Log Analytics Workspace'
metadata description = 'Module for creating a Log Analytics Workspace with configurable retention, daily cap, and linked storage accounts.'
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

@description('SKU of the Log Analytics Workspace.')
param skuName string = 'PerGB2018'

@description('Data retention period in days.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Daily ingestion quota in GB. A value of -1 means no limit.')
param dailyQuotaGb int = -1

@description('List of storage account IDs to be linked to the workspace (linked storage accounts).')
param linkedStorageAccountIds array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-log-{environment} (CAF: log)
var autoName = '${workloadName}-log-${environment}'
var workspaceName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
    }
    retentionInDays: retentionInDays
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }
  }
}

// Linked storage accounts - created only when provided
resource linkedStorageAccounts 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2025-02-01' = if (length(linkedStorageAccountIds) > 0) {
  name: 'CustomLogs'
  parent: logAnalyticsWorkspace
  properties: {
    storageAccountIds: linkedStorageAccountIds
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Log Analytics Workspace.')
output id string = logAnalyticsWorkspace.id

@description('Name of the created Log Analytics Workspace.')
output name string = logAnalyticsWorkspace.name

@description('Customer ID of the workspace, used for agent configuration.')
output customerId string = logAnalyticsWorkspace.properties.customerId

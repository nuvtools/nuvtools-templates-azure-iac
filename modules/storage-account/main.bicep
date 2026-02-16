// ---------------------------------------------------------------------------
// Bicep Module: Storage Account
// Creates a storage account with optional containers, network rules,
// and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Storage Account'
metadata description = 'Module for creating a Storage Account with optional containers, network rules, and diagnostics.'
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
param tags object = {}

@description('SKU of the storage account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param skuName string = 'Standard_LRS'

@description('Type of the storage account.')
@allowed([
  'StorageV2'
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
])
param kind string = 'StorageV2'

@description('Access tier of the storage account.')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('Allows public access to blobs.')
param allowBlobPublicAccess bool = false

@description('Minimum allowed TLS version.')
@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
param minimumTlsVersion string = 'TLS1_2'

@description('Default action for network rules (Allow or Deny).')
@allowed([
  'Allow'
  'Deny'
])
param networkDefaultAction string = 'Deny'

@description('List of subnet IDs allowed for access via service endpoints.')
param virtualNetworkSubnetIds array = []

@description('List of blob container names to be created.')
param containers array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('ID of the Log Analytics Workspace for diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}st{environment} (no hyphens, max 24 characters)
var autoName = take('${workloadName}st${environment}', 24)
var storageAccountName = empty(name) ? autoName : name

// Builds virtual network rules only if subnets are provided
var virtualNetworkRules = [
  for subnetId in virtualNetworkSubnetIds: {
    id: subnetId
    action: 'Allow'
  }
]

// =============================================================================
// Resources
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: kind
  sku: {
    name: skuName
  }
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    minimumTlsVersion: minimumTlsVersion
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: networkDefaultAction
      bypass: 'AzureServices, Logging, Metrics'
      virtualNetworkRules: virtualNetworkRules
      ipRules: []
    }
  }
}

// Blob service - default resource of the storage account
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  name: 'default'
  parent: storageAccount
}

// Optional blob containers
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = [
  for containerName in containers: {
    name: containerName
    parent: blobServices
    properties: {
      publicAccess: 'None'
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${storageAccountName}-diag'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created storage account.')
output id string = storageAccount.id

@description('Name of the created storage account.')
output name string = storageAccount.name

@description('Primary blob endpoint URL of the storage account.')
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob

// ---------------------------------------------------------------------------
// Bicep Module: Container Registry
// Creates an Azure Container Registry with configurable SKU, conditional
// role assignments for AcrPull, and optional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Container Registry'
metadata description = 'Module for provisioning an Azure Container Registry with AcrPull role assignments and diagnostics following configurable naming conventions.'
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

@description('SKU of the Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('Enables the Container Registry admin user.')
param adminUserEnabled bool = false

@description('Public network access control for the Container Registry.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Enables zone redundancy (available only on Premium SKU).')
@allowed([
  'Disabled'
  'Enabled'
])
param zoneRedundancy string = 'Disabled'

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('ID of the Log Analytics workspace for diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('List of principal IDs that will receive the AcrPull role on the Container Registry.')
param acrPullPrincipalIds array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}cr{environment} (no hyphens, alphanumeric)
var autoName = '${workloadName}cr${environment}'
var containerRegistryName = empty(name) ? autoName : name

// Built-in AcrPull role ID
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// =============================================================================
// Resources
// =============================================================================

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: skuName == 'Premium' ? zoneRedundancy : 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Conditional role assignments for AcrPull
resource acrPullRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (principalId, index) in acrPullPrincipalIds: {
    name: guid(containerRegistry.id, principalId, acrPullRoleDefinitionId)
    scope: containerRegistry
    properties: {
      roleDefinitionId: acrPullRoleDefinitionId
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${containerRegistryName}-diag'
  scope: containerRegistry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
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

@description('ID of the created Container Registry.')
output id string = containerRegistry.id

@description('Name of the created Container Registry.')
output name string = containerRegistry.name

@description('Login server URL of the Container Registry.')
output loginServer string = containerRegistry.properties.loginServer

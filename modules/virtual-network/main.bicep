// ---------------------------------------------------------------------------
// Bicep Module: Virtual Network
// Creates a Virtual Network in Azure following configurable naming conventions.
// ---------------------------------------------------------------------------

metadata name = 'Virtual Network'
metadata description = 'Module for creating a Virtual Network following configurable naming conventions.'
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

@description('Address prefixes for the virtual network (CIDR). Example: [\'10.0.0.0/16\'].')
param addressPrefixes array

@description('List of custom DNS servers. Leave empty to use Azure default DNS.')
param dnsServers array = []

@description('Enables DDoS protection on the virtual network.')
param enableDdosProtection bool = false

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('ID of the Log Analytics workspace for diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-vnet-{environment}
var autoName = '${workloadName}-vnet-${environment}'
var virtualNetworkName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: virtualNetworkName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    dhcpOptions: !empty(dnsServers) ? {
      dnsServers: dnsServers
    } : null
    enableDdosProtection: enableDdosProtection
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && logAnalyticsWorkspaceId != '') {
  name: '${virtualNetworkName}-diag'
  scope: virtualNetwork
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
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

@description('ID of the created virtual network.')
output id string = virtualNetwork.id

@description('Name of the created virtual network.')
output name string = virtualNetwork.name

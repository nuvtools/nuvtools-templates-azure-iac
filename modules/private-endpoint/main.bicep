// ---------------------------------------------------------------------------
// Bicep Module: Private Endpoint
// Creates a Private Endpoint in Azure with configurable naming conventions,
// including optional private DNS zone integration.
// ---------------------------------------------------------------------------

metadata name = 'Private Endpoint'
metadata description = 'Module for creating a Private Endpoint with optional DNS Zone Group integration following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parametros
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

@description('ID of the subnet where the Private Endpoint will be created.')
param subnetId string

@description('ID of the target resource to which the Private Endpoint will be connected.')
param privateConnectionResourceId string

@description('List of target resource group IDs. Example: [\'blob\'], [\'sqlServer\'].')
param groupIds array

@description('Private DNS zone ID for automatic DNS record integration. Leave empty to skip DNS Zone Group creation.')
param privateDnsZoneId string = ''

// =============================================================================
// Variaveis
// =============================================================================

// Pattern: {workloadName}-pep-{environment} (CAF: pep)
var autoName = '${workloadName}-pep-${environment}'
var privateEndpointName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: privateConnectionResourceId
          groupIds: groupIds
        }
      }
    ]
  }
}

// DNS zone group for automatic DNS registration when a private zone is provided
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = if (privateDnsZoneId != '') {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Private Endpoint.')
output id string = privateEndpoint.id

@description('Name of the created Private Endpoint.')
output name string = privateEndpoint.name

@description('Network interface ID of the Private Endpoint.')
output networkInterfaceId string = privateEndpoint.properties.networkInterfaces[0].id

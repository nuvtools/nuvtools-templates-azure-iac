// ---------------------------------------------------------------------------
// Bicep Module: Private DNS Resolver
// Creates an Azure DNS Private Resolver with an inbound endpoint, giving
// callers outside the virtual network a private IP to send DNS queries to.
// ---------------------------------------------------------------------------

metadata name = 'Private DNS Resolver'
metadata description = 'Module for creating an Azure DNS Private Resolver with an inbound endpoint following configurable naming conventions.'
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

@description('Azure region where the resource will be created. Must match the region of the virtual network.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('ID of the virtual network the resolver is attached to. Its linked private DNS zones are what the resolver answers for.')
param virtualNetworkId string

@description('ID of the subnet hosting the inbound endpoint. Must be at least /28, delegated to Microsoft.Network/dnsResolvers, and hold nothing else.')
param inboundSubnetId string

@description('Name of the inbound endpoint.')
param inboundEndpointName string = 'inbound'

@description('Private IP for the inbound endpoint, taken from the inbound subnet. Empty assigns one dynamically; a fixed address is what lets callers be pointed at the resolver by configuration rather than after the fact.')
param inboundPrivateIpAddress string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-dnspr-{environment} (CAF: dnspr)
var autoName = '${workloadName}-dnspr-${environment}'
var dnsResolverName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource dnsResolver 'Microsoft.Network/dnsResolvers@2025-05-01' = {
  name: dnsResolverName
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// Inbound endpoint: a private IP inside the virtual network that accepts DNS
// queries and answers them exactly as Azure DNS would for a resource in that
// network — private DNS zones linked to it first, public names after.
resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01' = {
  name: inboundEndpointName
  parent: dnsResolver
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        subnet: {
          id: inboundSubnetId
        }
        privateIpAllocationMethod: empty(inboundPrivateIpAddress) ? 'Dynamic' : 'Static'
        privateIpAddress: empty(inboundPrivateIpAddress) ? null : inboundPrivateIpAddress
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created DNS private resolver.')
output id string = dnsResolver.id

@description('Name of the created DNS private resolver.')
output name string = dnsResolver.name

@description('ID of the inbound endpoint.')
output inboundEndpointId string = inboundEndpoint.id

@description('Private IP address the inbound endpoint listens on.')
output inboundIpAddress string = inboundEndpoint.properties.ipConfigurations[0].privateIpAddress

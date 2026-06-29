// ---------------------------------------------------------------------------
// Bicep Module: Subnet
// Creates a subnet within an existing virtual network in Azure.
// This is a child resource module.
// ---------------------------------------------------------------------------

metadata name = 'Subnet'
metadata description = 'Module for creating a Subnet as a child resource of an existing Virtual Network.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Name of the existing virtual network where the subnet will be created.')
param virtualNetworkName string

@description('Name of the subnet to be created.')
param subnetName string

@description('Address prefix for the subnet (CIDR). Example: \'10.0.1.0/24\'. Ignored when addressPrefixes is provided.')
param addressPrefix string = ''

@description('Multiple address prefixes for the subnet (CIDR). Takes precedence over addressPrefix when not empty.')
param addressPrefixes array = []

@description('ID of the Network Security Group to associate with the subnet. Leave empty to skip association.')
param networkSecurityGroupId string = ''

@description('ID of the Route Table to associate with the subnet. Leave empty to skip association.')
param routeTableId string = ''

@description('NAT Gateway ID to associate with the subnet. Leave empty to skip association.')
param natGatewayId string = ''

@description('List of Service Endpoints to enable on the subnet. Example: [\'Microsoft.Storage\', \'Microsoft.Sql\'].')
param serviceEndpoints array = []

@description('List of subnet delegations. Each object must contain name and serviceName.')
param delegations array = []

@description('Network policy for Private Endpoints on the subnet.')
@allowed([
  'Enabled'
  'Disabled'
  'NetworkSecurityGroupEnabled'
  'RouteTableEnabled'
])
param privateEndpointNetworkPolicies string = 'Enabled'

@description('Controls default outbound internet access for the subnet. Leave null to use the platform default.')
param defaultOutboundAccess bool?

// =============================================================================
// Variables
// =============================================================================

// Builds the Service Endpoints list in the format expected by Azure
var formattedServiceEndpoints = [for endpoint in serviceEndpoints: {
  service: endpoint
}]

// Builds the delegations list in the format expected by Azure
var formattedDelegations = [for delegation in delegations: {
  name: delegation.name
  properties: {
    serviceName: delegation.serviceName
  }
}]

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing virtual network (parent)
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-07-01' existing = {
  name: virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2025-07-01' = {
  name: subnetName
  parent: virtualNetwork
  properties: {
    addressPrefix: empty(addressPrefixes) ? addressPrefix : null
    addressPrefixes: !empty(addressPrefixes) ? addressPrefixes : null
    networkSecurityGroup: networkSecurityGroupId != '' ? {
      id: networkSecurityGroupId
    } : null
    routeTable: routeTableId != '' ? {
      id: routeTableId
    } : null
    natGateway: natGatewayId != '' ? {
      id: natGatewayId
    } : null
    serviceEndpoints: !empty(formattedServiceEndpoints) ? formattedServiceEndpoints : null
    delegations: !empty(formattedDelegations) ? formattedDelegations : null
    privateEndpointNetworkPolicies: privateEndpointNetworkPolicies
    defaultOutboundAccess: defaultOutboundAccess
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created subnet.')
output id string = subnet.id

@description('Name of the created subnet.')
output name string = subnet.name

@description('Address prefix of the created subnet (first prefix when multiple are set).')
output addressPrefix string = empty(addressPrefixes) ? addressPrefix : first(addressPrefixes)

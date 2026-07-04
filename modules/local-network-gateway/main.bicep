// ---------------------------------------------------------------------------
// Bicep Module: Local Network Gateway
// Creates a Local Network Gateway (the on-premises / peer side definition of a
// Site-to-Site VPN) following configurable naming conventions.
// ---------------------------------------------------------------------------

metadata name = 'Local Network Gateway'
metadata description = 'Module for creating a Local Network Gateway (peer definition for Site-to-Site VPN) following configurable naming conventions.'
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

@description('Public IP address of the on-premises / peer VPN device.')
param gatewayIpAddress string

@description('Address prefixes reachable behind the peer (its local network address space).')
param addressPrefixes array

@description('Optional BGP settings for the local network gateway (e.g., { asn, bgpPeeringAddress }). Empty = no BGP.')
param bgpSettings object = {}

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-lgw-{environment} (CAF: lgw)
var autoName = '${workloadName}-lgw-${environment}'
var localNetworkGatewayName = empty(name) ? autoName : name

// =============================================================================
// Resource
// =============================================================================

resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2025-07-01' = {
  name: localNetworkGatewayName
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: gatewayIpAddress
    localNetworkAddressSpace: {
      addressPrefixes: addressPrefixes
    }
    bgpSettings: empty(bgpSettings) ? null : bgpSettings
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Local Network Gateway.')
output id string = localNetworkGateway.id

@description('Name of the created Local Network Gateway.')
output name string = localNetworkGateway.name

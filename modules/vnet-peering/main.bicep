// ---------------------------------------------------------------------------
// Bicep Module: Virtual Network Peering
// Creates a peering from an existing local Virtual Network to a remote one.
// This is a child resource module (one direction of the peering).
// ---------------------------------------------------------------------------

metadata name = 'Virtual Network Peering'
metadata description = 'Module for creating a single-direction peering on an existing Virtual Network.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Name of the existing local virtual network where the peering will be created.')
param localVnetName string

@description('Name of the peering to be created.')
param peeringName string

@description('Resource ID of the remote virtual network to peer with.')
param remoteVirtualNetworkId string

@description('Allows traffic from the local virtual network to reach the remote one.')
param allowVirtualNetworkAccess bool = true

@description('Allows forwarded (non-originated) traffic from the remote virtual network.')
param allowForwardedTraffic bool = false

@description('Allows the remote virtual network to use this network\'s gateway. Set on the hub side.')
param allowGatewayTransit bool = false

@description('Uses the remote virtual network\'s gateway. Set on the spoke side. Mutually exclusive with allowGatewayTransit.')
param useRemoteGateways bool = false

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing local virtual network (parent)
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-07-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-07-01' = {
  name: peeringName
  parent: virtualNetwork
  properties: {
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkId
    }
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created peering.')
output id string = peering.id

@description('Name of the created peering.')
output name string = peering.name

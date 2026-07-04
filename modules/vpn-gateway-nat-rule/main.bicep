// ---------------------------------------------------------------------------
// Bicep Module: VPN Gateway NAT Rule
// Creates a NAT rule on an EXISTING Virtual Network Gateway (VPN). Used to
// translate source address spaces for Site-to-Site connections whose peer
// expects a specific (or non-overlapping) range — the native equivalent of a
// "SNAT before the tunnel" rule on an on-premises appliance.
// ---------------------------------------------------------------------------

metadata name = 'VPN Gateway NAT Rule'
metadata description = 'Module for creating a NAT rule on an existing Virtual Network Gateway (VPN), for Site-to-Site connections that require address translation.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('NAT rule name. Slashes are not allowed by the platform.')
param name string

@description('Name of the existing Virtual Network Gateway that owns this NAT rule.')
param virtualNetworkGatewayName string

@description('NAT direction: EgressSnat translates the VNet source; IngressSnat translates the peer source.')
@allowed([
  'EgressSnat'
  'IngressSnat'
])
param mode string

@description('NAT type: Static (1:1, equal-size) or Dynamic (PAT; external mapping up to /26).')
@allowed([
  'Static'
  'Dynamic'
])
param type string = 'Dynamic'

@description('Internal (pre-NAT) address prefixes. Use a single prefix per rule to avoid overlap.')
param internalMappings array

@description('External (post-NAT) address prefixes.')
param externalMappings array

@description('IP configuration ID this rule applies to (for active-active gateways). Empty = default instance.')
param ipConfigurationId string = ''

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing parent gateway.
resource gateway 'Microsoft.Network/virtualNetworkGateways@2025-07-01' existing = {
  name: virtualNetworkGatewayName
}

resource natRule 'Microsoft.Network/virtualNetworkGateways/natRules@2025-07-01' = {
  name: name
  parent: gateway
  properties: {
    mode: mode
    type: type
    internalMappings: [for prefix in internalMappings: { addressSpace: prefix }]
    externalMappings: [for prefix in externalMappings: { addressSpace: prefix }]
    ipConfigurationId: empty(ipConfigurationId) ? null : ipConfigurationId
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created NAT rule.')
output id string = natRule.id

@description('Name of the created NAT rule.')
output name string = natRule.name

// ---------------------------------------------------------------------------
// Bicep Module: Virtual Network Gateway (VPN)
// Creates a route-based VPN gateway, optionally active-active, with BGP and a
// Point-to-Site (P2S) configuration. Public IPs and the GatewaySubnet are passed
// in by ID (referenced, not created here). Following configurable naming.
// ---------------------------------------------------------------------------

metadata name = 'Virtual Network Gateway'
metadata description = 'Module for creating a route-based VPN gateway (optional active-active, BGP and Point-to-Site) following configurable naming conventions.'
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

@description('Gateway SKU (name and tier). Prefer the AZ SKUs — non-AZ VpnGw1..5 are being retired. e.g. VpnGw1AZ..5AZ.')
param skuName string = 'VpnGw2AZ'

@description('VPN type.')
@allowed([
  'RouteBased'
  'PolicyBased'
])
param vpnType string = 'RouteBased'

@description('Gateway generation.')
@allowed([
  'Generation1'
  'Generation2'
])
param vpnGatewayGeneration string = 'Generation2'

@description('Deploy the gateway in active-active mode (requires two IP configurations).')
param activeActive bool = false

@description('Enable BGP on the gateway.')
param enableBgp bool = false

@description('BGP Autonomous System Number (used only when enableBgp is true).')
param bgpAsn int = 65515

@description('''IP configurations. One per gateway instance (+ one for P2S when applicable).
Array of objects: { name, publicIpId, subnetId }. privateIPAllocationMethod is Dynamic.''')
param ipConfigurations array

@description('Enable a Point-to-Site (VPN client) configuration.')
param enablePointToSite bool = false

@description('P2S client address pool (address prefixes).')
param pointToSiteAddressPool array = []

@description('P2S tunnel protocols.')
param pointToSiteProtocols array = [
  'OpenVPN'
]

@description('P2S authentication types (e.g. AAD, Certificate, Radius).')
param pointToSiteAuthTypes array = [
  'AAD'
]

@description('Entra ID (AAD) tenant URL for P2S AAD auth. e.g. https://login.microsoftonline.com/<tenantId>/')
param aadTenant string = ''

@description('Entra ID (AAD) audience (app id) for P2S AAD auth.')
param aadAudience string = ''

@description('Entra ID (AAD) issuer for P2S AAD auth. e.g. https://sts.windows.net/<tenantId>/')
param aadIssuer string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-vgw-{environment} (CAF: vgw)
var autoName = '${workloadName}-vgw-${environment}'
var gatewayName = empty(name) ? autoName : name

var gatewayIpConfigurations = [
  for config in ipConfigurations: {
    name: config.name
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      publicIPAddress: {
        id: config.publicIpId
      }
      subnet: {
        id: config.subnetId
      }
    }
  }
]

var vpnClientConfiguration = enablePointToSite
  ? {
      vpnClientAddressPool: {
        addressPrefixes: pointToSiteAddressPool
      }
      vpnClientProtocols: pointToSiteProtocols
      vpnAuthenticationTypes: pointToSiteAuthTypes
      aadTenant: empty(aadTenant) ? null : aadTenant
      aadAudience: empty(aadAudience) ? null : aadAudience
      aadIssuer: empty(aadIssuer) ? null : aadIssuer
    }
  : null

// =============================================================================
// Resource
// =============================================================================

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2025-07-01' = {
  name: gatewayName
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: vpnType
    vpnGatewayGeneration: vpnGatewayGeneration
    sku: {
      name: skuName
      tier: skuName
    }
    activeActive: activeActive
    enableBgp: enableBgp
    bgpSettings: enableBgp ? { asn: bgpAsn } : null
    ipConfigurations: gatewayIpConfigurations
    vpnClientConfiguration: vpnClientConfiguration
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Virtual Network Gateway.')
output id string = virtualNetworkGateway.id

@description('Name of the created Virtual Network Gateway.')
output name string = virtualNetworkGateway.name

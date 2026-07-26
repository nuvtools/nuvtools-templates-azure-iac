// ---------------------------------------------------------------------------
// Bicep Module: Virtual Network Gateway (VPN)
// Creates a route-based VPN gateway, optionally active-active, with BGP and a
// Point-to-Site (P2S) configuration. Following configurable naming.
//
// The public IPs come one of two ways:
//   - Bring your own: pass ipConfigurations with the IDs of public IPs you
//     manage yourself. Required when the gateway address is allow-listed in a
//     third party's firewall, and the only way to adopt an existing gateway.
//   - Managed here: leave ipConfigurations empty and pass gatewaySubnetId; the
//     module creates the Standard/Static public IPs it needs.
// The GatewaySubnet is always referenced by ID, never created here.
// ---------------------------------------------------------------------------

metadata name = 'Virtual Network Gateway'
metadata description = 'Module for creating a route-based VPN gateway (optional active-active, BGP and Point-to-Site) following configurable naming conventions.'
metadata version = '1.1.0'

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

@description('''IP configurations, one per gateway instance (+ one for P2S when applicable).
Array of objects: { name, publicIpId, subnetId }. privateIPAllocationMethod is Dynamic.
Pass this to front the gateway with public IPs you manage yourself - the right choice
whenever the address is allow-listed by a third party, since an IP created alongside the
gateway changes if the gateway is ever recreated. Leave empty to have the module create
its own public IPs from gatewaySubnetId.''')
param ipConfigurations array = []

@description('''Resource ID of the GatewaySubnet. Required when ipConfigurations is empty,
ignored otherwise (there each configuration carries its own subnetId).''')
param gatewaySubnetId string = ''

@description('''Availability zones of the public IPs created by this module. The AZ SKUs
require a zone-redundant Standard IP. Empty deploys them non-zonal.''')
param publicIpZones array = [
  '1'
  '2'
  '3'
]

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

// Public IPs owned by this module, named with the resource type last:
// {workloadName}-vgw-<role>-pip-{environment}. An active-active gateway needs a
// second address, and adding P2S on top of active-active needs a third,
// dedicated one.
var createPublicIps = empty(ipConfigurations)
var publicIpName = '${workloadName}-vgw-pip-${environment}'
var secondaryPublicIpName = '${workloadName}-vgw-sec-pip-${environment}'
var pointToSitePublicIpName = '${workloadName}-vgw-vpnp2s-pip-${environment}'

var managedIpConfigurations = concat(
  [
    {
      name: 'default'
      publicIpId: publicIp.?id ?? ''
      subnetId: gatewaySubnetId
    }
  ],
  activeActive
    ? [
        {
          name: 'activeActive'
          publicIpId: secondaryPublicIp.?id ?? ''
          subnetId: gatewaySubnetId
        }
      ]
    : [],
  (activeActive && enablePointToSite)
    ? [
        {
          name: pointToSitePublicIpName
          publicIpId: pointToSitePublicIp.?id ?? ''
          subnetId: gatewaySubnetId
        }
      ]
    : []
)

var effectiveIpConfigurations = createPublicIps ? managedIpConfigurations : ipConfigurations

var gatewayIpConfigurations = [
  for config in effectiveIpConfigurations: {
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
// Resources
// =============================================================================

// Public IPs fronting the gateway, created only when the caller did not bring
// its own. Standard + Static: a VPN gateway requires it, and the address must
// not move while the gateway lives.
resource publicIp 'Microsoft.Network/publicIPAddresses@2025-07-01' = if (createPublicIps) {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: !empty(publicIpZones) ? publicIpZones : null
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource secondaryPublicIp 'Microsoft.Network/publicIPAddresses@2025-07-01' = if (createPublicIps && activeActive) {
  name: secondaryPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: !empty(publicIpZones) ? publicIpZones : null
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// An active-active gateway serving P2S needs an address of its own for the
// client tunnels; a single-instance gateway serves P2S on its only address.
resource pointToSitePublicIp 'Microsoft.Network/publicIPAddresses@2025-07-01' = if (createPublicIps && activeActive && enablePointToSite) {
  name: pointToSitePublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: !empty(publicIpZones) ? publicIpZones : null
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

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

@description('ID of the primary public IP created by this module. Empty when the caller brought its own.')
output publicIpId string = createPublicIps ? (publicIp.?id ?? '') : ''

@description('Address of the primary public IP created by this module - the VPN endpoint clients connect to. Empty when the caller brought its own.')
output publicIpAddress string = createPublicIps ? (publicIp.?properties.ipAddress ?? '') : ''

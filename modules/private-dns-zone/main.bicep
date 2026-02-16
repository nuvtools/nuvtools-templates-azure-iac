// ---------------------------------------------------------------------------
// Bicep Module: Private DNS Zone
// Creates a private DNS zone with optional virtual network links in Azure.
// ---------------------------------------------------------------------------

metadata name = 'Private DNS Zone'
metadata description = 'Module for creating a Private DNS Zone with Virtual Network Links following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Workload name. Used to compose the resource name when name is not provided.')
@minLength(2)
@maxLength(20)
#disable-next-line no-unused-params // Kept for interface standardization across modules
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Name of the private DNS zone. Example: \'privatelink.blob.core.windows.net\'.')
param zoneName string

@description('List of virtual network links. Each object must contain: name (link name), virtualNetworkId (VNet ID) and optionally registrationEnabled (bool, default false).')
param virtualNetworkLinks array = []

// =============================================================================
// Variables
// =============================================================================

// Private DNS zones are global resources, location must be 'global'
var dnsZoneLocation = 'global'

// =============================================================================
// Resources
// =============================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: zoneName
  location: dnsZoneLocation
  tags: tags
}

// Virtual network links (enables DNS resolution of the zone in the VNet)
resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for link in virtualNetworkLinks: {
  name: link.name
  parent: privateDnsZone
  location: dnsZoneLocation
  tags: tags
  properties: {
    virtualNetwork: {
      id: link.virtualNetworkId
    }
    registrationEnabled: link.?registrationEnabled ?? false
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created private DNS zone.')
output id string = privateDnsZone.id

@description('Name of the created private DNS zone.')
output name string = privateDnsZone.name

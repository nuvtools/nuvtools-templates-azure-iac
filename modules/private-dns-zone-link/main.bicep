// ---------------------------------------------------------------------------
// Bicep Module: Private DNS Zone Virtual Network Link
// Links a virtual network to a private DNS zone that ALREADY EXISTS and is
// owned by another deployment.
// ---------------------------------------------------------------------------

metadata name = 'Private DNS Zone Virtual Network Link'
metadata description = 'Module for linking a virtual network to an existing Private DNS Zone, without creating or modifying the zone itself.'
metadata version = '1.0.0'

// Use this instead of `private-dns-zone` when the zone belongs to someone else.
//
// A private DNS zone name is global and a virtual network accepts exactly one
// link per zone name, so a name that must resolve across an estate exists once,
// in one resource group, while the virtual networks that need it are spread
// across resource groups and subscriptions. That splits ownership: one
// deployment owns the zone, many own a link into it.
//
// `private-dns-zone` cannot serve the second role. Its zone declaration is
// unconditional, so calling it from a second deployment issues a PUT on the
// zone with that deployment's tags, and the owner's next run puts them back —
// the zone's tags flap between two pipelines forever, and both sides read a
// spurious change on every what-if. This module declares the zone `existing`
// and writes only the link.
//
// Deploy it at the scope that owns the ZONE (`scope: resourceGroup(subId, rg)`
// for a zone in another subscription), not the scope that owns the virtual
// network: the link is a child of the zone. The identity running it therefore
// needs write access on the zone's resource group, plus join on the virtual
// network it is linking.

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

@description('Name of the EXISTING private DNS zone to link into. Created and owned by another deployment; this module never writes to the zone itself. Example: \'privatelink.database.windows.net\'.')
param zoneName string

@description('Resource ID of the virtual network to link. May live in any resource group or subscription.')
param virtualNetworkId string

@description('Link name. Empty composes <virtual-network-name>-link, which is the convention a zone\'s own deployment uses for the links it writes — keeping both sides consistent when ownership of a link moves.')
param linkName string = ''

@description('Registers the virtual network\'s VM records in the zone. Off by default: a privatelink zone is a resolution zone, never a registration zone, and a zone accepts only one registration link.')
param registrationEnabled bool = false

// =============================================================================
// Variables
// =============================================================================

// Private DNS zones and their links are global resources.
var dnsZoneLocation = 'global'

var resolvedLinkName = empty(linkName) ? '${last(split(virtualNetworkId, '/'))}-link' : linkName

// =============================================================================
// Resources
// =============================================================================

// Referenced, never written. A PUT here would fight the zone's owner.
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: zoneName
}

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: resolvedLinkName
  parent: privateDnsZone
  location: dnsZoneLocation
  tags: tags
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
    registrationEnabled: registrationEnabled
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created virtual network link.')
output id string = vnetLink.id

@description('Name of the created virtual network link.')
output name string = vnetLink.name

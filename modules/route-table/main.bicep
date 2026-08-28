// ---------------------------------------------------------------------------
// Bicep Module: Route Table
// Creates a Route Table and its routes, following configurable naming
// conventions. Typically used to steer selected prefixes at a network virtual
// appliance (an Azure Firewall in a hub) rather than letting them follow the
// VNet's system routes.
// ---------------------------------------------------------------------------

metadata name = 'Route Table'
metadata description = 'Module for creating a Route Table with routes following configurable naming conventions.'
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

@description('Discriminator inserted before the resource type abbreviation, to distinguish several tables in one environment (e.g. "onsite" gives {workloadName}-onsite-rt-{environment}). Ignored when name is provided.')
param nameSuffix string = ''

@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('''Routes to create. Array of objects:
{ name, addressPrefix, nextHopType, nextHopIpAddress? }.
nextHopIpAddress is required only when nextHopType is VirtualAppliance.''')
param routes array = []

@description('''Prevents routes learned from a virtual network gateway (VPN/ExpressRoute) being
propagated into this table. Leave false unless the appliance is intended to replace those routes
entirely — disabling propagation on a subnet that still relies on a gateway will black-hole it.''')
param disableBgpRoutePropagation bool = false

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-rt-{environment}, or {workloadName}-{nameSuffix}-rt-{environment} (CAF: rt)
var autoName = empty(nameSuffix)
  ? '${workloadName}-rt-${environment}'
  : '${workloadName}-${nameSuffix}-rt-${environment}'
var routeTableName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource routeTable 'Microsoft.Network/routeTables@2025-07-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: [
      for route in routes: {
        name: route.name
        properties: {
          addressPrefix: route.addressPrefix
          nextHopType: route.nextHopType
          nextHopIpAddress: route.?nextHopIpAddress
        }
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Route Table.')
output id string = routeTable.id

@description('Name of the created Route Table.')
output name string = routeTable.name

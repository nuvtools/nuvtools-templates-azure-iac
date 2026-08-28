// ---------------------------------------------------------------------------
// Bicep Module: Public IP Address
// Creates a Public IP Address following configurable naming conventions.
// Consumed by modules that attach to an existing public IP rather than
// creating one (azure-firewall, nat-gateway, virtual-network-gateway, ...).
// ---------------------------------------------------------------------------

metadata name = 'Public IP Address'
metadata description = 'Module for creating a Public IP Address following configurable naming conventions.'
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

@description('Suffix appended to the generated name, to distinguish several addresses in one environment. Ignored when name is provided.')
param nameSuffix string = ''

@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Public IP SKU. Standard is required by Azure Firewall, NAT Gateway and zone-redundant deployments.')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

@description('Allocation method. Standard SKU supports Static only.')
@allowed([
  'Static'
  'Dynamic'
])
param allocationMethod string = 'Static'

@description('IP version.')
@allowed([
  'IPv4'
  'IPv6'
])
param addressVersion string = 'IPv4'

@description('Availability zones. Empty deploys non-zonal.')
param zones array = []

@description('Optional DNS label, forming {label}.{region}.cloudapp.azure.com. Empty assigns no DNS name.')
param domainNameLabel string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-pip-{environment}, or {workloadName}-pip-{nameSuffix}-{environment} (CAF: pip)
var autoName = empty(nameSuffix)
  ? '${workloadName}-pip-${environment}'
  : '${workloadName}-pip-${nameSuffix}-${environment}'
var publicIpName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource publicIp 'Microsoft.Network/publicIPAddresses@2025-07-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  zones: zones
  properties: {
    publicIPAllocationMethod: allocationMethod
    publicIPAddressVersion: addressVersion
    dnsSettings: empty(domainNameLabel) ? null : {
      domainNameLabel: domainNameLabel
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Public IP Address.')
output id string = publicIp.id

@description('Name of the created Public IP Address.')
output name string = publicIp.name

@description('The allocated IP address. Empty until allocation completes for a Dynamic address.')
output ipAddress string = publicIp.properties.ipAddress

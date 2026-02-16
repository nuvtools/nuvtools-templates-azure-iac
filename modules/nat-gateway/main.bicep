// ---------------------------------------------------------------------------
// Bicep Module: NAT Gateway
// Creates a NAT Gateway with a public IP prefix in Azure
// following configurable naming conventions.
// ---------------------------------------------------------------------------

metadata name = 'NAT Gateway'
metadata description = 'Module for creating a NAT Gateway with Public IP Prefix following configurable naming conventions.'
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

@description('NAT Gateway SKU.')
@allowed([
  'Standard'
])
param skuName string = 'Standard'

@description('Idle timeout in minutes for NAT Gateway connections.')
@minValue(4)
@maxValue(120)
param idleTimeoutInMinutes int = 4

@description('Public IP prefix length (number of bits). Example: 31 = 2 IPs, 30 = 4 IPs.')
@minValue(28)
@maxValue(31)
param publicIpPrefixLength int = 31

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-ng-{environment} (CAF: ng)
var autoName = '${workloadName}-ng-${environment}'
var natGatewayName = empty(name) ? autoName : name
var publicIpPrefixName = '${workloadName}-ippre-${environment}'

// =============================================================================
// Resources
// =============================================================================

// Public IP prefix used by the NAT Gateway
resource publicIpPrefix 'Microsoft.Network/publicIPPrefixes@2024-01-01' = {
  name: publicIpPrefixName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    prefixLength: publicIpPrefixLength
    publicIPAddressVersion: 'IPv4'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-01-01' = {
  name: natGatewayName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    idleTimeoutInMinutes: idleTimeoutInMinutes
    publicIpPrefixes: [
      {
        id: publicIpPrefix.id
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created NAT Gateway.')
output id string = natGateway.id

@description('Name of the created NAT Gateway.')
output name string = natGateway.name

@description('ID of the Public IP Prefix associated with the NAT Gateway.')
output publicIpPrefixId string = publicIpPrefix.id

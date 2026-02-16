// ---------------------------------------------------------------------------
// Bicep Module: Bastion Host
// Creates an Azure Bastion Host with dedicated public IP, Basic and Standard
// SKU support, conditional tunneling and optional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Bastion Host'
metadata description = 'Module for creating an Azure Bastion Host with public IP, conditional tunneling and diagnostics following configurable naming conventions.'
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

@description('Bastion Host SKU.')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

@description('AzureBastionSubnet subnet ID. The subnet must be named exactly AzureBastionSubnet.')
param subnetId string

@description('Enables native tunneling for Bastion (available only on Standard SKU).')
param enableTunneling bool = false

@description('Enables IP-based connection via Bastion (available only on Standard SKU).')
param enableIpConnect bool = false

@description('Number of scale units for the Bastion Host.')
@minValue(2)
@maxValue(50)
param scaleUnits int = 2

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-bas-{environment}
var autoName = '${workloadName}-bas-${environment}'
var bastionName = empty(name) ? autoName : name
var publicIpName = '${workloadName}-pip-bas-${environment}'

// =============================================================================
// Resources
// =============================================================================

// Public IP for the Bastion Host
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    scaleUnits: skuName == 'Standard' ? scaleUnits : 2
    enableTunneling: skuName == 'Standard' ? enableTunneling : false
    enableIpConnect: skuName == 'Standard' ? enableIpConnect : false
    enableFileCopy: skuName == 'Standard' ? true : false
    enableShareableLink: skuName == 'Standard' ? true : false
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

// Conditional diagnostic settings
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${bastionName}-diag'
  scope: bastionHost
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Bastion Host.')
output id string = bastionHost.id

@description('Name of the created Bastion Host.')
output name string = bastionHost.name

@description('DNS name of the Bastion Host.')
output dnsName string = bastionHost.properties.dnsName

// ---------------------------------------------------------------------------
// Bicep Module: API Management
// Creates an Azure API Management service with managed identity, custom
// domains, VNet configuration, auto-scaling and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'API Management'
metadata description = 'Module for creating an Azure API Management with managed identity, custom domains, VNet integration, auto-scaling and diagnostics following configurable naming conventions.'
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

@description('API Management service SKU.')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Developer'

@description('Capacity (number of units) of the API Management service.')
param skuCapacity int = 1

@description('Publisher name of the API Management service.')
param publisherName string

@description('Publisher email of the API Management service.')
param publisherEmail string

@description('Virtual network integration type.')
@allowed([
  'None'
  'External'
  'Internal'
])
param virtualNetworkType string = 'None'

@description('Subnet ID for VNet integration. Required when virtualNetworkType is not None.')
param subnetId string = ''

@description('Enables system-assigned managed identity.')
param enableSystemAssignedIdentity bool = true

@description('List of custom domains. Each object must contain: type (Proxy, Portal, DeveloperPortal, Management or Scm), hostName (string) and keyVaultSecretId (string, optional).')
param customDomains array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('Public IP address ID for VNet deployments.')
param publicIpAddressId string = ''

@description('Enables auto-scaling for the API Management service.')
param enableAutoScale bool = false

@description('Minimum capacity for auto-scaling.')
param minCapacity int = 1

@description('Maximum capacity for auto-scaling.')
param maxCapacity int = 2

@description('Availability zones for the API Management service. Applicable only to the Premium SKU.')
param zones array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-apim-{environment}
var autoName = '${workloadName}-apim-${environment}'
var apimName = empty(name) ? autoName : name

// Maps custom domains to the APIM hostnameConfigurations format
var hostnameConfigurations = [
  for domain in customDomains: {
    type: domain.type
    hostName: domain.hostName
    keyVaultId: contains(domain, 'keyVaultSecretId') && !empty(domain.keyVaultSecretId)
      ? domain.keyVaultSecretId
      : null
    negotiateClientCertificate: false
  }
]

// Determines whether VNet is enabled
var isVnetEnabled = virtualNetworkType != 'None'

// =============================================================================
// Resources
// =============================================================================

resource apiManagement 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuName == 'Consumption' ? 0 : skuCapacity
  }
  identity: enableSystemAssignedIdentity
    ? {
        type: 'SystemAssigned'
      }
    : null
  zones: skuName == 'Premium' && !empty(zones) ? zones : []
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    virtualNetworkType: isVnetEnabled ? virtualNetworkType : 'None'
    virtualNetworkConfiguration: isVnetEnabled && !empty(subnetId)
      ? {
          subnetResourceId: subnetId
        }
      : null
    publicIpAddressId: isVnetEnabled && !empty(publicIpAddressId) ? publicIpAddressId : null
    hostnameConfigurations: !empty(customDomains) ? hostnameConfigurations : null
    publicNetworkAccess: 'Enabled'
  }
}

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${apimName}-diag'
  scope: apiManagement
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

// Conditional auto-scaling configuration
resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (enableAutoScale && skuName != 'Consumption') {
  name: '${apimName}-autoscale'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: apiManagement.id
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: string(minCapacity)
          maximum: string(maxCapacity)
          default: string(skuCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Capacity'
              metricResourceUri: apiManagement.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 80
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT60M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Capacity'
              metricResourceUri: apiManagement.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 35
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT90M'
            }
          }
        ]
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created API Management service.')
output id string = apiManagement.id

@description('Name of the created API Management service.')
output name string = apiManagement.name

@description('Gateway URL of the API Management service.')
output gatewayUrl string = apiManagement.properties.gatewayUrl

@description('Developer portal URL of the API Management service.')
output portalUrl string = apiManagement.properties.portalUrl

@description('Management API URL of the API Management service.')
output managementApiUrl string = apiManagement.properties.managementApiUrl

@description('Principal ID of the API Management managed identity. Empty when identity is not enabled.')
output principalId string = enableSystemAssignedIdentity ? apiManagement.identity.principalId : ''

// ---------------------------------------------------------------------------
// Bicep Module: Service Bus
// Creates a Service Bus namespace with queues, topics and conditional
// diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Service Bus'
metadata description = 'Module for provisioning a Service Bus Namespace with queues, topics and conditional diagnostics.'
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

@description('Service Bus namespace SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('Service Bus namespace capacity. Applicable only to the Premium SKU.')
param skuCapacity int = 1

@description('Enables zone redundancy for the namespace. Applicable only to the Premium SKU.')
param zoneRedundant bool = false

@description('List of queues to be created. Each object must contain: name (string), maxSizeInMegabytes (int, default 1024), enablePartitioning (bool, default false), deadLetteringOnExpiration (bool, default true) and maxDeliveryCount (int, default 10).')
param queues array = []

@description('List of topics to be created. Each object must contain: name (string), maxSizeInMegabytes (int, default 1024) and enablePartitioning (bool, default false).')
param topics array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-sbns-{environment} (CAF: sbns)
var autoName = '${workloadName}-sbns-${environment}'
var namespaceName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

// Pinned to 2024-01-01 — the newest GA the Service Bus resource provider actually accepts
// (2025-05-01 is preview; 2026-01-01 exists in the Bicep type index but is not yet registered in ARM).
#disable-next-line use-recent-api-versions
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
    capacity: skuName == 'Premium' ? skuCapacity : 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    zoneRedundant: skuName == 'Premium' ? zoneRedundant : false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Queues - created via loop over the configuration array
#disable-next-line use-recent-api-versions
resource serviceBusQueues 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = [
  for queue in queues: {
    name: queue.name
    parent: serviceBusNamespace
    properties: {
      maxSizeInMegabytes: queue.?maxSizeInMegabytes ?? 1024
      enablePartitioning: queue.?enablePartitioning ?? false
      deadLetteringOnMessageExpiration: queue.?deadLetteringOnExpiration ?? true
      maxDeliveryCount: queue.?maxDeliveryCount ?? 10
    }
  }
]

// Topics - created via loop over the configuration array
#disable-next-line use-recent-api-versions
resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2024-01-01' = [
  for topic in topics: {
    name: topic.name
    parent: serviceBusNamespace
    properties: {
      maxSizeInMegabytes: topic.?maxSizeInMegabytes ?? 1024
      enablePartitioning: topic.?enablePartitioning ?? false
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${namespaceName}-diag'
  scope: serviceBusNamespace
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

@description('ID of the created Service Bus namespace.')
output id string = serviceBusNamespace.id

@description('Name of the created Service Bus namespace.')
output name string = serviceBusNamespace.name

@description('FQDN of the Service Bus namespace.')
output namespaceFqdn string = serviceBusNamespace.properties.serviceBusEndpoint

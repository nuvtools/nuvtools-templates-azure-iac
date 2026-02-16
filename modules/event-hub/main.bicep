// ---------------------------------------------------------------------------
// Bicep Module: Event Hub
// Creates an Event Hub namespace with individual Event Hubs, consumer groups
// and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Event Hub'
metadata description = 'Module for creating an Event Hub Namespace with Event Hubs, consumer groups and diagnostics following configurable naming conventions.'
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

@description('Event Hub namespace SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('Capacity (throughput units) of the Event Hub namespace.')
param skuCapacity int = 1

@description('Enables auto-inflate to automatically scale throughput units.')
param isAutoInflateEnabled bool = false

@description('Maximum number of throughput units when auto-inflate is enabled. Use 0 to disable.')
param maximumThroughputUnits int = 0

@description('Enables zone redundancy for the namespace.')
param zoneRedundant bool = false

@description('List of Event Hubs to be created. Each object must contain: name (string), partitionCount (int, default 2), messageRetentionInDays (int, default 1) and consumerGroups (array of strings, optional).')
param eventHubs array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-evhns-{environment}
var autoName = '${workloadName}-evhns-${environment}'
var namespaceName = empty(name) ? autoName : name

// Flattened list of consumer groups across all Event Hubs (for single-loop iteration)
var flatConsumerGroups = flatten(map(eventHubs, (hub, hubIndex) => map(hub.?consumerGroups ?? [], group => {
  hubIndex: hubIndex
  hubName: hub.name
  groupName: group
})))

// =============================================================================
// Resources
// =============================================================================

#disable-next-line use-recent-api-versions
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    isAutoInflateEnabled: skuName != 'Premium' ? isAutoInflateEnabled : false
    maximumThroughputUnits: skuName != 'Premium' && isAutoInflateEnabled ? maximumThroughputUnits : 0
    zoneRedundant: zoneRedundant
    minimumTlsVersion: '1.2'
  }
}

// Individual Event Hubs - created via loop over the configuration array
#disable-next-line use-recent-api-versions
resource eventHubInstances 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = [
  for hub in eventHubs: {
    name: hub.name
    parent: eventHubNamespace
    properties: {
      partitionCount: hub.?partitionCount ?? 2
      messageRetentionInDays: hub.?messageRetentionInDays ?? 1
      status: 'Active'
    }
  }
]

// Consumer groups - created as child resources of each Event Hub
#disable-next-line use-recent-api-versions
resource consumerGroups 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = [
  for item in flatConsumerGroups: {
    name: item.groupName
    parent: eventHubInstances[item.hubIndex]
    properties: {}
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${namespaceName}-diag'
  scope: eventHubNamespace
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

@description('ID of the created Event Hub namespace.')
output id string = eventHubNamespace.id

@description('Name of the created Event Hub namespace.')
output name string = eventHubNamespace.name

@description('FQDN of the Event Hub namespace (Service Bus endpoint).')
output namespaceFqdn string = eventHubNamespace.properties.serviceBusEndpoint

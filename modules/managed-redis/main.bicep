// ---------------------------------------------------------------------------
// Bicep Module: Azure Managed Redis
// Creates an Azure Managed Redis cluster (Microsoft.Cache/redisEnterprise) with
// its database, Microsoft Entra authentication and optional access policy
// assignments for managed identities, plus conditional diagnostics.
//
// The successor to Azure Cache for Redis (modules/redis-cache), whose Basic,
// Standard and Premium tiers can no longer be created by new customers since
// April 2026, nor by anyone from October 2026, and retire in September 2028.
// ---------------------------------------------------------------------------

metadata name = 'Azure Managed Redis'
metadata description = 'Module for provisioning Azure Managed Redis (redisEnterprise + database) with Entra authentication, access policy assignments, network access control and conditional diagnostics.'
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

@description('SKU of the cluster, which sets memory and throughput: Balanced_B0 is the smallest. See the Azure Managed Redis pricing page for the full list.')
param skuName string = 'Balanced_B0'

@description('Replicates the data set within the region. Disabled halves the cost and removes the availability SLA; suitable for non-production, or for data that can be rebuilt.')
@allowed([
  'Enabled'
  'Disabled'
])
param highAvailability string = 'Enabled'

@description('Whether the cluster answers on its public endpoint. Disabled means a private endpoint is the only way in — Azure Managed Redis has no service-endpoint option.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Minimum TLS version accepted by the cluster.')
@allowed([
  '1.2'
])
param minimumTlsVersion string = '1.2'

@description('''Clustering policy of the database. Cannot be changed after creation, except from NoCluster.
OSSCluster: the client connects to each shard directly — needs a cluster-aware client and a network path to every node.
EnterpriseCluster: one endpoint, sharding handled behind it — the simplest option behind a private endpoint; multi-key commands must stay within one hash slot.
NoCluster: a single shard, up to 25 GB.''')
@allowed([
  'OSSCluster'
  'EnterpriseCluster'
  'NoCluster'
])
param clusteringPolicy string = 'EnterpriseCluster'

@description('Eviction policy of the database when memory is full. The default evicts only keys that carry an expiry.')
@allowed([
  'AllKeysLFU'
  'AllKeysLRU'
  'AllKeysRandom'
  'NoEviction'
  'VolatileLFU'
  'VolatileLRU'
  'VolatileRandom'
  'VolatileTTL'
])
param evictionPolicy string = 'VolatileLRU'

@description('TCP port of the database endpoint. Fixed at creation; 10000 is the Azure Managed Redis convention.')
param port int = 10000

@description('Whether the database accepts its access keys. Disabled by default: Microsoft Entra ID is the only way in, so there is no key to store, rotate or leak.')
@allowed([
  'Enabled'
  'Disabled'
])
param accessKeysAuthentication string = 'Disabled'

@description('''Principals granted the "default" data access policy on the database (full data access), by object ID.
Array of objects: { name, objectId }. name is 1-60 letters and digits, unique within the database.
For a user-assigned managed identity, objectId is its principalId.''')
param accessPolicyAssignments array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-amr-{environment} (CAF: amr)
var autoName = '${workloadName}-amr-${environment}'
var clusterName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource cluster 'Microsoft.Cache/redisEnterprise@2025-07-01' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    highAvailability: highAvailability
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: publicNetworkAccess
  }
}

// A cluster serves nothing without a database, and Azure Managed Redis allows exactly one, which
// has to be called 'default'.
resource database 'Microsoft.Cache/redisEnterprise/databases@2025-07-01' = {
  name: 'default'
  parent: cluster
  properties: {
    clientProtocol: 'Encrypted'
    clusteringPolicy: clusteringPolicy
    evictionPolicy: evictionPolicy
    port: port
    accessKeysAuthentication: accessKeysAuthentication
  }
}

// Serial: assignments on one database are written through the same parent, and ARM reports a
// parallel conflict as a generic failure on the database rather than on the assignment that lost.
@batchSize(1)
resource accessPolicyAssignment 'Microsoft.Cache/redisEnterprise/databases/accessPolicyAssignments@2025-07-01' = [
  for assignment in accessPolicyAssignments: {
    name: assignment.name
    parent: database
    properties: {
      accessPolicyName: 'default'
      user: {
        objectId: assignment.objectId
      }
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${clusterName}-diag'
  scope: cluster
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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

@description('ID of the Azure Managed Redis cluster. The private endpoint connects to this, with group ID redisEnterprise.')
output id string = cluster.id

@description('Name of the Azure Managed Redis cluster.')
output name string = cluster.name

@description('Host name clients connect to, e.g. <name>.<region>.redis.azure.net.')
output hostName string = cluster.properties.hostName

@description('Port of the database endpoint.')
output port int = port

@description('Client endpoint as host:port, ready for a StackExchange.Redis configuration string.')
output endpoint string = '${cluster.properties.hostName}:${port}'

// ---------------------------------------------------------------------------
// Bicep Module: Redis Cache
// Creates an Azure Cache for Redis instance with configurable SKU,
// TLS, VNet injection (Premium) and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Redis Cache'
metadata description = 'Module for provisioning Azure Cache for Redis with configurable SKU, TLS, VNet injection for Premium and conditional diagnostics.'
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

@description('Name of the Redis Cache SKU.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('Redis Cache SKU family. C for Basic/Standard, P for Premium.')
@allowed([
  'C'
  'P'
])
param skuFamily string = 'C'

@description('Capacity (size) of the Redis Cache instance. Valid values: 0-6 for Basic/Standard, 1-5 for Premium.')
param skuCapacity int = 1

@description('Enables the non-SSL port (6379). It is recommended to keep it disabled for better security.')
param enableNonSslPort bool = false

@description('Minimum TLS version allowed for connections.')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimumTlsVersion string = '1.2'

@description('Redis version.')
@allowed([
  '4'
  '6'
])
param redisVersion string = '6'

@description('Defines whether public network access is enabled or disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Subnet ID for VNet injection. Available only for the Premium SKU.')
param subnetId string = ''

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('Additional Redis configuration as a key-value object (e.g., maxmemory-policy, maxmemory-reserved).')
param redisConfiguration object = {}

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-redis-{environment}
var autoName = '${workloadName}-redis-${environment}'
var redisCacheName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource redisCache 'Microsoft.Cache/redis@2024-11-01' = {
  name: redisCacheName
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
      family: skuFamily
      capacity: skuCapacity
    }
    enableNonSslPort: enableNonSslPort
    minimumTlsVersion: minimumTlsVersion
    redisVersion: redisVersion
    publicNetworkAccess: publicNetworkAccess
    redisConfiguration: !empty(redisConfiguration) ? redisConfiguration : {}
    subnetId: !empty(subnetId) ? subnetId : null
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Firewall rule to allow access from Azure services - enabled only when public access is enabled
resource firewallRuleAllowAzureServices 'Microsoft.Cache/redis/firewallRules@2024-11-01' = if (publicNetworkAccess == 'Enabled') {
  name: 'AllowAzureServices'
  parent: redisCache
  properties: {
    startIP: '0.0.0.0'
    endIP: '0.0.0.0'
  }
}

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${redisCacheName}-diag'
  scope: redisCache
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

@description('ID of the created Azure Cache for Redis.')
output id string = redisCache.id

@description('Name of the created Azure Cache for Redis.')
output name string = redisCache.name

@description('Host name of the Azure Cache for Redis.')
output hostName string = redisCache.properties.hostName

@description('SSL port of the Azure Cache for Redis.')
output sslPort int = redisCache.properties.sslPort

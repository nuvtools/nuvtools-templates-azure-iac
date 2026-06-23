// =============================================================================
// Parameters for the STAGING environment
// =============================================================================

using '../main.bicep'

param workloadName = 'myapp'
param environment = 'staging'
param location = 'brazilsouth'

// Layers enabled in Staging
param enableNetworking = true
param enableMonitoring = true
param enableSecurity = true
param enableData = true
param enableCompute = true
param enableMessaging = false
param enableGovernance = false

// Networking
param vnetAddressPrefixes = ['10.20.0.0/16']
param subnets = [
  {
    name: 'snet-default'
    addressPrefix: '10.20.1.0/24'
    serviceEndpoints: []
  }
  {
    name: 'snet-aks'
    addressPrefix: '10.20.2.0/23'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.KeyVault', 'Microsoft.ContainerRegistry']
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '10.20.4.0/26'
    serviceEndpoints: []
  }
]

// Monitoring
param logAnalyticsRetentionInDays = 60

// Security
param keyVaultSkuName = 'standard'

// Data
param sqlAdminLogin = 'sqladmin'
param sqlDatabaseSkuName = 'GP_S_Gen5_1'
param redisSkuName = 'Standard'
param enablePostgresql = true
param postgresqlAdminLogin = 'pgadmin'
param postgresqlSkuName = 'Standard_B1ms'
param postgresqlSkuTier = 'Burstable'
param postgresqlStorageSizeGB = 32

// Compute
param acrSkuName = 'Standard'
param aksKubernetesVersion = '1.29'

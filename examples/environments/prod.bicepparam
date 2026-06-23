// =============================================================================
// Parameters for the PROD environment
// =============================================================================

using '../main.bicep'

param workloadName = 'myapp'
param environment = 'prod'
param location = 'brazilsouth'

// All layers enabled in Production
param enableNetworking = true
param enableMonitoring = true
param enableSecurity = true
param enableData = true
param enableCompute = true
param enableMessaging = true
param enableGovernance = true

// Networking
param vnetAddressPrefixes = ['10.30.0.0/16']
param subnets = [
  {
    name: 'snet-default'
    addressPrefix: '10.30.1.0/24'
    serviceEndpoints: []
  }
  {
    name: 'snet-aks'
    addressPrefix: '10.30.2.0/23'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.KeyVault', 'Microsoft.ContainerRegistry']
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: '10.30.4.0/26'
    serviceEndpoints: []
  }
  {
    name: 'snet-apim'
    addressPrefix: '10.30.5.0/24'
    serviceEndpoints: []
  }
]
param enableNatGateway = true

// Monitoring
param logAnalyticsRetentionInDays = 90

// Security
param keyVaultSkuName = 'premium'

// Data
param sqlAdminLogin = 'sqladmin'
param sqlDatabaseSkuName = 'GP_Gen5_2'
param redisSkuName = 'Premium'
param enablePostgresql = true
param postgresqlAdminLogin = 'pgadmin'
param postgresqlVersion = '16'
param postgresqlSkuName = 'Standard_D2s_v3'
param postgresqlSkuTier = 'GeneralPurpose'
param postgresqlStorageSizeGB = 128

// Compute
param acrSkuName = 'Premium'
param aksKubernetesVersion = '1.29'
param aksDefaultNodePool = {
  vmSize: 'Standard_D8s_v3'
  count: 3
  minCount: 3
  maxCount: 10
  osDiskSizeGB: 256
  osDiskType: 'Managed'
  maxPods: 50
  availabilityZones: ['1', '2', '3']
  enableAutoScaling: true
  subnetId: ''
  nodeLabels: {}
  nodeTaints: []
}
param enableBastion = true

// Integration
param apimPublisherName = 'MyOrg'
param apimPublisherEmail = 'admin@myorg.com'
param enableEventHub = true
param enableServiceBus = true
param enableSignalR = true

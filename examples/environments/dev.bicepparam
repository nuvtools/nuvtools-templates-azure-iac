// =============================================================================
// Parameters for the DEV environment
// =============================================================================

using '../main.bicep'

param workloadName = 'myapp'
param environment = 'dev'
param location = 'brazilsouth'

// Layers enabled in DEV
param enableNetworking = true
param enableMonitoring = true
param enableSecurity = true
param enableData = false
param enableCompute = false
param enableMessaging = false
param enableGovernance = false

// Networking
param vnetAddressPrefixes = ['10.10.0.0/16']
param subnets = [
  {
    name: 'snet-default'
    addressPrefix: '10.10.1.0/24'
    serviceEndpoints: []
  }
  {
    name: 'snet-aks'
    addressPrefix: '10.10.2.0/23'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.KeyVault', 'Microsoft.ContainerRegistry']
  }
]

// Monitoring
param logAnalyticsRetentionInDays = 30

// Security
param keyVaultSkuName = 'standard'

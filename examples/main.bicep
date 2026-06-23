// =============================================================================
// Azure Bicep Templates - Main Orchestrator
// Composes all 29 modules in dependency layers with enable toggles.
// Scope: subscription (creates Resource Groups and child resources)
// =============================================================================

metadata name = 'Main Orchestrator'
metadata description = 'Main orchestrator that composes all modules in dependency layers.'
metadata version = '1.0.0'

targetScope = 'subscription'

// =============================================================================
// Global Parameters
// =============================================================================

@description('Workload name. Used to compose names for all resources.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region where the resources will be created.')
param location string = 'brazilsouth'

@description('Global tags applied to all resources.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

// =============================================================================
// Layer Enable Toggles
// =============================================================================

@description('Enables networking resources (VNet, Subnets, NSG, NAT Gateway, Private DNS).')
param enableNetworking bool = true

@description('Enables monitoring resources (Log Analytics, Application Insights).')
param enableMonitoring bool = true

@description('Enables security resources (Key Vault, certificates).')
param enableSecurity bool = true

@description('Enables data resources (SQL Server, SQL Database, Redis Cache, PostgreSQL).')
param enableData bool = false

@description('Enables compute resources (ACR, AKS, App Gateway, Bastion, Windows VM).')
param enableCompute bool = false

@description('Enables integration resources (API Management, Event Hub, Service Bus, SignalR).')
param enableMessaging bool = false

@description('Enables governance resources (Role Assignments, Policies).')
param enableGovernance bool = false

// =============================================================================
// Networking Parameters
// =============================================================================

@description('Virtual network address prefixes.')
param vnetAddressPrefixes array = ['10.0.0.0/16']

@description('Subnet configuration. Array of objects with name, addressPrefix and optional properties.')
param subnets array = [
  {
    name: 'snet-default'
    addressPrefix: '10.0.1.0/24'
    serviceEndpoints: []
  }
  {
    name: 'snet-aks'
    addressPrefix: '10.0.2.0/23'
    serviceEndpoints: ['Microsoft.Storage', 'Microsoft.KeyVault', 'Microsoft.ContainerRegistry']
  }
]

@description('NSG security rules.')
param nsgSecurityRules array = []

@description('Enables NAT Gateway.')
param enableNatGateway bool = false

@description('Private DNS zones to create. Array of objects with zoneName.')
param privateDnsZones array = []

// =============================================================================
// Monitoring Parameters
// =============================================================================

@description('Log Analytics workspace retention in days.')
param logAnalyticsRetentionInDays int = 30

@description('Application type for Application Insights.')
param appInsightsApplicationType string = 'web'

// =============================================================================
// Security Parameters
// =============================================================================

@description('Key Vault SKU.')
@allowed(['standard', 'premium'])
param keyVaultSkuName string = 'standard'

// =============================================================================
// Data Parameters
// =============================================================================

@description('SQL Server administrator login.')
param sqlAdminLogin string = 'sqladmin'

@description('SQL Server administrator password.')
@secure()
param sqlAdminPassword string = ''

@description('SQL Database SKU name.')
param sqlDatabaseSkuName string = 'GP_S_Gen5_1'

@description('Redis Cache SKU.')
@allowed(['Basic', 'Standard', 'Premium'])
param redisSkuName string = 'Standard'

@description('Enables Azure Database for PostgreSQL Flexible Server (and its database).')
param enablePostgresql bool = false

@description('PostgreSQL administrator login.')
param postgresqlAdminLogin string = 'pgadmin'

@description('PostgreSQL administrator password.')
@secure()
param postgresqlAdminPassword string = ''

@description('Major PostgreSQL engine version.')
param postgresqlVersion string = '16'

@description('PostgreSQL compute SKU name.')
param postgresqlSkuName string = 'Standard_B1ms'

@description('PostgreSQL compute SKU tier.')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param postgresqlSkuTier string = 'Burstable'

@description('PostgreSQL allocated storage size in GB.')
param postgresqlStorageSizeGB int = 32

// =============================================================================
// Compute Parameters
// =============================================================================

@description('Container Registry SKU.')
@allowed(['Basic', 'Standard', 'Premium'])
param acrSkuName string = 'Basic'

@description('Kubernetes version.')
param aksKubernetesVersion string = '1.29'

@description('SSH public key for AKS nodes.')
@secure()
param aksSshPublicKey string = ''

@description('AKS default node pool configuration.')
param aksDefaultNodePool object = {
  vmSize: 'Standard_D4s_v3'
  count: 3
  minCount: 1
  maxCount: 5
  osDiskSizeGB: 128
  osDiskType: 'Managed'
  maxPods: 30
  availabilityZones: ['1', '2', '3']
  enableAutoScaling: true
  subnetId: ''
  nodeLabels: {}
  nodeTaints: []
}

@description('Enables Bastion Host.')
param enableBastion bool = false

@description('Enables Windows VM (jumpbox).')
param enableWindowsVm bool = false

@description('Windows VM administrator username.')
param vmAdminUsername string = 'azureadmin'

@description('Windows VM administrator password.')
@secure()
param vmAdminPassword string = ''

// =============================================================================
// Integration Parameters
// =============================================================================

@description('API Management publisher name.')
param apimPublisherName string = ''

@description('API Management publisher email.')
param apimPublisherEmail string = ''

@description('Enables Event Hub.')
param enableEventHub bool = false

@description('Enables Service Bus.')
param enableServiceBus bool = false

@description('Enables SignalR.')
param enableSignalR bool = false

// =============================================================================
// Governance Parameters
// =============================================================================

@description('Role assignments. Array of objects with principalId, roleDefinitionId, principalType.')
param roleAssignments array = []

@description('Policy assignments. Array of objects with policyDefinitionId, displayName, description.')
param policyAssignments array = []

// =============================================================================
// Variables
// =============================================================================

// Computed RG name (must match the resource-group module's naming convention).
// Required because scope: needs a compile-time value (BCP120).
var resourceGroupName = '${workloadName}-rg-${environment}'

// =============================================================================
// Layer 0: Resource Group
// =============================================================================

module rg '../modules/resource-group/main.bicep' = {
  name: 'deploy-resource-group'
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
  }
}

// =============================================================================
// Layer 1: Networking
// =============================================================================

module virtualNetwork '../modules/virtual-network/main.bicep' = if (enableNetworking) {
  name: 'deploy-virtual-network'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    addressPrefixes: vnetAddressPrefixes
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

@batchSize(1)
module subnet '../modules/subnet/main.bicep' = [for (snet, i) in subnets: if (enableNetworking) {
  name: 'deploy-subnet-${i}'
  scope: resourceGroup(resourceGroupName)
  params: {
    virtualNetworkName: virtualNetwork!.outputs.name
    subnetName: snet.name
    addressPrefix: snet.addressPrefix
    serviceEndpoints: snet.?serviceEndpoints ?? []
    delegations: snet.?delegations ?? []
    networkSecurityGroupId: nsg!.outputs.id
  }
}]

module nsg '../modules/nsg/main.bicep' = if (enableNetworking) {
  name: 'deploy-nsg'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    securityRules: nsgSecurityRules
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module natGateway '../modules/nat-gateway/main.bicep' = if (enableNetworking && enableNatGateway) {
  name: 'deploy-nat-gateway'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

module privateDnsZone '../modules/private-dns-zone/main.bicep' = [for (zone, i) in privateDnsZones: if (enableNetworking) {
  name: 'deploy-private-dns-zone-${i}'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    zoneName: zone.zoneName
    virtualNetworkLinks: zone.?virtualNetworkLinks ?? [
      {
        name: 'link-to-vnet'
        virtualNetworkId: enableNetworking ? virtualNetwork!.outputs.id : ''
        registrationEnabled: false
      }
    ]
  }
}]

// =============================================================================
// Layer 2: Monitoring + Storage
// =============================================================================

module logAnalytics '../modules/log-analytics/main.bicep' = if (enableMonitoring) {
  name: 'deploy-log-analytics'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    retentionInDays: logAnalyticsRetentionInDays
  }
  dependsOn: [
    rg
  ]
}

module appInsights '../modules/app-insights/main.bicep' = if (enableMonitoring) {
  name: 'deploy-app-insights'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    applicationType: appInsightsApplicationType
    logAnalyticsWorkspaceId: logAnalytics!.outputs.id
  }
}

module storageAccount '../modules/storage-account/main.bicep' = if (enableMonitoring) {
  name: 'deploy-storage-account'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
  }
  dependsOn: [
    rg
  ]
}

// =============================================================================
// Layer 3: Security
// =============================================================================

module keyVault '../modules/key-vault/main.bicep' = if (enableSecurity) {
  name: 'deploy-key-vault'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    skuName: keyVaultSkuName
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

// =============================================================================
// Layer 4: Data
// =============================================================================

module sqlServer '../modules/sql-server/main.bicep' = if (enableData) {
  name: 'deploy-sql-server'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    administratorLogin: sqlAdminLogin
    administratorPassword: sqlAdminPassword
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module sqlDatabase '../modules/sql-database/main.bicep' = if (enableData) {
  name: 'deploy-sql-database'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    sqlServerName: sqlServer!.outputs.name
    skuName: sqlDatabaseSkuName
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
}

module redisCache '../modules/redis-cache/main.bicep' = if (enableData) {
  name: 'deploy-redis-cache'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    skuName: redisSkuName
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module postgresqlServer '../modules/postgresql-flexible-server/main.bicep' = if (enableData && enablePostgresql) {
  name: 'deploy-postgresql-server'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    administratorLogin: postgresqlAdminLogin
    administratorPassword: postgresqlAdminPassword
    postgresqlVersion: postgresqlVersion
    skuName: postgresqlSkuName
    skuTier: postgresqlSkuTier
    storageSizeGB: postgresqlStorageSizeGB
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module postgresqlDatabase '../modules/postgresql-database/main.bicep' = if (enableData && enablePostgresql) {
  name: 'deploy-postgresql-database'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    postgresqlServerName: postgresqlServer!.outputs.name
  }
}

// =============================================================================
// Layer 5: Compute
// =============================================================================

module containerRegistry '../modules/container-registry/main.bicep' = if (enableCompute) {
  name: 'deploy-container-registry'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    skuName: acrSkuName
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module aksCluster '../modules/kubernetes-cluster/main.bicep' = if (enableCompute && enableNetworking) {
  name: 'deploy-kubernetes-cluster'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    kubernetesVersion: aksKubernetesVersion
    sshPublicKey: aksSshPublicKey
    defaultNodePool: union(aksDefaultNodePool, {
      subnetId: subnet[1]!.outputs.id
    })
    enableOmsAgent: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
    enableKeyVaultSecretsProvider: enableSecurity
  }
}

module bastion '../modules/bastion/main.bicep' = if (enableCompute && enableBastion && enableNetworking) {
  name: 'deploy-bastion'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    subnetId: subnet[0]!.outputs.id
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
}

module windowsVm '../modules/virtual-machine-windows/main.bicep' = if (enableCompute && enableWindowsVm && enableNetworking) {
  name: 'deploy-windows-vm'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    subnetId: subnet[0]!.outputs.id
  }
}

// =============================================================================
// Layer 6: Integration
// =============================================================================

module apiManagement '../modules/api-management/main.bicep' = if (enableMessaging && apimPublisherName != '' && apimPublisherEmail != '') {
  name: 'deploy-api-management'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    publisherName: apimPublisherName
    publisherEmail: apimPublisherEmail
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module eventHub '../modules/event-hub/main.bicep' = if (enableMessaging && enableEventHub) {
  name: 'deploy-event-hub'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module serviceBus '../modules/service-bus/main.bicep' = if (enableMessaging && enableServiceBus) {
  name: 'deploy-service-bus'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

module signalr '../modules/signalr/main.bicep' = if (enableMessaging && enableSignalR) {
  name: 'deploy-signalr'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    tags: tags
    enableDiagnostics: enableMonitoring
    logAnalyticsWorkspaceId: enableMonitoring ? logAnalytics!.outputs.id : ''
  }
  dependsOn: [
    rg
  ]
}

// =============================================================================
// Layer 7: Governance
// =============================================================================

module roleAssignment '../modules/role-assignment/main.bicep' = [for (assignment, i) in roleAssignments: if (enableGovernance) {
  name: 'deploy-role-assignment-${i}'
  scope: resourceGroup(resourceGroupName)
  params: {
    workloadName: workloadName
    environment: environment
    principalId: assignment.principalId
    roleDefinitionId: assignment.roleDefinitionId
    principalType: assignment.?principalType ?? 'ServicePrincipal'
  }
}]

module policyAssignment '../modules/policy/main.bicep' = [for (policy, i) in policyAssignments: if (enableGovernance) {
  name: 'deploy-policy-assignment-${i}'
  params: {
    workloadName: workloadName
    environment: environment
    location: location
    policyDefinitionId: policy.policyDefinitionId
    displayName: policy.displayName
    identity: false
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('Name of the created Resource Group.')
output resourceGroupName string = rg.outputs.name

@description('ID of the created Resource Group.')
output resourceGroupId string = rg.outputs.id

@description('Virtual network ID (when enabled).')
output virtualNetworkId string = enableNetworking ? virtualNetwork!.outputs.id : ''

@description('Log Analytics workspace ID (when enabled).')
output logAnalyticsWorkspaceId string = enableMonitoring ? logAnalytics!.outputs.id : ''

@description('Key Vault ID (when enabled).')
output keyVaultId string = enableSecurity ? keyVault!.outputs.id : ''

@description('PostgreSQL Flexible Server FQDN (when enabled).')
output postgresqlServerFqdn string = enableData && enablePostgresql ? postgresqlServer!.outputs.fullyQualifiedDomainName : ''

@description('AKS cluster ID (when enabled).')
output aksClusterId string = enableCompute && enableNetworking ? aksCluster!.outputs.id : ''

@description('AKS cluster FQDN (when enabled).')
output aksClusterFqdn string = enableCompute && enableNetworking ? aksCluster!.outputs.fqdn : ''

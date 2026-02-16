// ---------------------------------------------------------------------------
// Bicep Module: Kubernetes Node Pool
// Creates an additional node pool in an existing AKS cluster, with support
// for auto scaling, Spot VMs, labels, taints and availability zones.
// ---------------------------------------------------------------------------

metadata name = 'Kubernetes Node Pool'
metadata description = 'Module for creating an additional node pool in an existing AKS cluster following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Workload name. Used to compose the resource name.')
@minLength(2)
@maxLength(20)
#disable-next-line no-unused-params // Kept for interface standardization across modules
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region where the resource will be created.')
#disable-next-line no-unused-params // Kept for interface standardization across modules
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Name of the existing AKS cluster where the node pool will be created.')
param clusterName string

@description('Name of the node pool. Must be at most 12 characters (AKS limitation).')
@maxLength(12)
param nodePoolName string

@description('VM size for the pool nodes.')
param vmSize string = 'Standard_D4s_v3'

@description('Initial number of nodes in the pool.')
param count int = 3

@description('Minimum number of nodes when auto scaling is enabled.')
param minCount int = 1

@description('Maximum number of nodes when auto scaling is enabled.')
param maxCount int = 5

@description('Enables auto scaling for the node pool.')
param enableAutoScaling bool = true

@description('OS disk size in GB.')
param osDiskSizeGB int = 128

@description('OS disk type.')
@allowed([
  'Managed'
  'Ephemeral'
])
param osDiskType string = 'Managed'

@description('Maximum number of pods per node.')
param maxPods int = 30

@description('Availability zones for the pool nodes.')
param availabilityZones array = [
  '1'
  '2'
  '3'
]

@description('Subnet ID where the pool nodes will be deployed.')
param subnetId string

@description('Node pool mode.')
@allowed([
  'System'
  'User'
])
param mode string = 'User'

@description('OS type for the pool nodes.')
@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'

@description('Labels to apply to the pool nodes.')
param nodeLabels object = {}

@description('Taints to apply to the pool nodes.')
param nodeTaints array = []

@description('Scale set priority for the node pool.')
@allowed([
  'Regular'
  'Spot'
])
param scaleSetPriority string = 'Regular'

// =============================================================================
// Variables
// =============================================================================

// For Spot VMs, availability zones are not applicable
var resolvedAvailabilityZones = scaleSetPriority == 'Spot' ? [] : availabilityZones

// For Spot VMs, configure the eviction policy and max price
var resolvedEvictionPolicy = scaleSetPriority == 'Spot' ? 'Delete' : null
var resolvedSpotMaxPrice = scaleSetPriority == 'Spot' ? json('-1') : null

// =============================================================================
// Resources
// =============================================================================

// Reference to the existing AKS cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' existing = {
  name: clusterName
}

resource nodePool 'Microsoft.ContainerService/managedClusters/agentPools@2024-09-01' = {
  name: nodePoolName
  parent: aksCluster
  properties: {
    vmSize: vmSize
    count: count
    minCount: enableAutoScaling ? minCount : null
    maxCount: enableAutoScaling ? maxCount : null
    enableAutoScaling: enableAutoScaling
    osDiskSizeGB: osDiskSizeGB
    osDiskType: osDiskType
    maxPods: maxPods
    type: 'VirtualMachineScaleSets'
    availabilityZones: resolvedAvailabilityZones
    vnetSubnetID: subnetId
    mode: mode
    osType: osType
    nodeLabels: scaleSetPriority == 'Spot' ? {} : nodeLabels
    nodeTaints: nodeTaints
    scaleSetPriority: scaleSetPriority
    scaleSetEvictionPolicy: resolvedEvictionPolicy
    spotMaxPrice: resolvedSpotMaxPrice
    upgradeSettings: scaleSetPriority != 'Spot' ? {
      maxSurge: '50%'
    } : null
    tags: tags
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created node pool.')
output id string = nodePool.id

@description('Name of the created node pool.')
output name string = nodePool.name

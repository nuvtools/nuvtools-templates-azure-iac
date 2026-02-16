// ---------------------------------------------------------------------------
// Bicep Module: Kubernetes Cluster (AKS)
// Creates an Azure Kubernetes Service with advanced network configuration,
// default node pool, managed identity, conditional addons, and integration
// with Application Gateway, OMS Agent, Defender, Key Vault, and OIDC.
// ---------------------------------------------------------------------------

metadata name = 'Kubernetes Cluster'
metadata description = 'Module for provisioning an Azure Kubernetes Service (AKS) with advanced networking, conditional addons, and managed identity following configurable naming conventions.'
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

@description('Kubernetes version to be used in the cluster.')
param kubernetesVersion string = '1.29'

@description('DNS prefix for the cluster. If not provided, it will be generated based on the resource name.')
param dnsPrefix string = ''

@description('Configuration for the default node pool of the cluster.')
param defaultNodePool object = {
  vmSize: 'Standard_D4s_v3'
  count: 3
  minCount: 1
  maxCount: 5
  osDiskSizeGB: 128
  osDiskType: 'Managed'
  maxPods: 30
  availabilityZones: [
    '1'
    '2'
    '3'
  ]
  enableAutoScaling: true
  subnetId: ''
  nodeLabels: {}
  nodeTaints: []
}

@description('Network plugin for the cluster.')
@allowed([
  'azure'
  'kubenet'
  'none'
])
param networkPlugin string = 'azure'

@description('Network policy for the cluster.')
@allowed([
  'azure'
  'calico'
])
param networkPolicy string = 'azure'

@description('Service CIDR for the cluster network.')
param serviceCidr string = '10.0.0.0/16'

@description('DNS service IP for the cluster.')
param dnsServiceIp string = '10.0.0.10'

@description('Load balancer SKU for the cluster.')
@allowed([
  'basic'
  'standard'
])
param loadBalancerSku string = 'standard'

@description('Enables Azure Policy for the cluster.')
param enableAzurePolicy bool = true

@description('Enables the OMS agent (Container Insights) for cluster monitoring.')
param enableOmsAgent bool = false

@description('ID of the Log Analytics workspace for OMS Agent and Defender. Required when enableOmsAgent or enableDefender is true.')
param logAnalyticsWorkspaceId string = ''

@description('Enables Microsoft Defender for the cluster.')
param enableDefender bool = false

@description('Enables the Key Vault secrets provider (CSI Driver) on the cluster.')
param enableKeyVaultSecretsProvider bool = false

@description('Enables Workload Identity on the cluster.')
param enableWorkloadIdentity bool = true

@description('Enables the OIDC issuer on the cluster.')
param enableOidcIssuer bool = true

@description('SSH public key for accessing cluster nodes. Must be generated externally.')
@secure()
param sshPublicKey string

@description('Admin username for SSH access to cluster nodes.')
param adminUsername string = 'azureuser'

@description('Enables private cluster mode (API Server accessible only via private network).')
param enablePrivateCluster bool = false

@description('List of authorized IP ranges to access the cluster API Server.')
param authorizedIpRanges array = []

@description('SKU tier of the AKS cluster.')
@allowed([
  'Free'
  'Standard'
  'Premium'
])
param skuTier string = 'Free'

@description('Enables the Ingress Application Gateway (AGIC) integration on the cluster.')
param enableIngressApplicationGateway bool = false

@description('ID of the existing Application Gateway for AGIC integration. Required when enableIngressApplicationGateway is true.')
param appGatewayId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-aks-{environment}
var autoName = '${workloadName}-aks-${environment}'
var aksName = empty(name) ? autoName : name
var resolvedDnsPrefix = !empty(dnsPrefix) ? dnsPrefix : aksName

// Conditional OMS agent profile
var omsAgentProfile = enableOmsAgent && !empty(logAnalyticsWorkspaceId) ? {
  enabled: true
  logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
} : {
  enabled: false
}

// Conditional Microsoft Defender profile
var defenderProfile = enableDefender && !empty(logAnalyticsWorkspaceId) ? {
  logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
  securityMonitoring: {
    enabled: true
  }
} : null

// Conditional Key Vault secrets provider profile
var keyVaultSecretsProviderProfile = enableKeyVaultSecretsProvider ? {
  enabled: true
  config: {
    enableSecretRotation: 'true'
    rotationPollInterval: '2m'
  }
} : {
  enabled: false
}

// Conditional Ingress Application Gateway profile
var ingressApplicationGatewayProfile = enableIngressApplicationGateway && !empty(appGatewayId) ? {
  enabled: true
  config: {
    applicationGatewayId: appGatewayId
  }
} : {
  enabled: false
}

// =============================================================================
// Resources
// =============================================================================

resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-09-01' = {
  name: aksName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: skuTier
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: resolvedDnsPrefix
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'system'
        count: defaultNodePool.count
        vmSize: defaultNodePool.vmSize
        osDiskSizeGB: defaultNodePool.osDiskSizeGB
        osDiskType: defaultNodePool.osDiskType
        maxPods: defaultNodePool.maxPods
        type: 'VirtualMachineScaleSets'
        availabilityZones: defaultNodePool.availabilityZones
        enableAutoScaling: defaultNodePool.enableAutoScaling
        minCount: defaultNodePool.enableAutoScaling ? defaultNodePool.minCount : null
        maxCount: defaultNodePool.enableAutoScaling ? defaultNodePool.maxCount : null
        vnetSubnetID: defaultNodePool.subnetId
        osType: 'Linux'
        mode: 'System'
        nodeLabels: defaultNodePool.?nodeLabels ?? {}
        nodeTaints: defaultNodePool.?nodeTaints ?? []
        upgradeSettings: {
          maxSurge: '50%'
        }
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIp
      loadBalancerSku: loadBalancerSku
    }
    linuxProfile: {
      adminUsername: adminUsername
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
    addonProfiles: {
      #disable-next-line BCP037
      omsagent: omsAgentProfile
      azurepolicy: {
        enabled: enableAzurePolicy
      }
      azureKeyvaultSecretsProvider: keyVaultSecretsProviderProfile
      ingressApplicationGateway: ingressApplicationGatewayProfile
    }
    securityProfile: union(
      {
        workloadIdentity: {
          enabled: enableWorkloadIdentity
        }
      },
      enableDefender && defenderProfile != null ? {
        defender: defenderProfile
      } : {}
    )
    oidcIssuerProfile: {
      enabled: enableOidcIssuer
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
      authorizedIPRanges: !enablePrivateCluster && !empty(authorizedIpRanges) ? authorizedIpRanges : []
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created AKS cluster.')
output id string = aksCluster.id

@description('Name of the created AKS cluster.')
output name string = aksCluster.name

@description('FQDN of the AKS cluster.')
output fqdn string = aksCluster.properties.fqdn

@description('Object ID of the cluster kubelet identity, used for RBAC assignments (e.g., AcrPull).')
output kubeletIdentityObjectId string = aksCluster.properties.identityProfile.kubeletidentity.objectId

@description('OIDC issuer URL of the cluster, used for Workload Identity configuration.')
output oidcIssuerUrl string = enableOidcIssuer ? aksCluster.properties.oidcIssuerProfile.issuerURL : ''

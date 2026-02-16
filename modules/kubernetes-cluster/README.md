# Kubernetes Cluster

Bicep module for provisioning an Azure Kubernetes Service (AKS) cluster with advanced networking, conditional addons, and managed identity following a configurable naming convention (`{workloadName}-aks-{environment}`). The `name` parameter allows you to completely override the automatic name. Supports default node pool configuration, network plugins (Azure CNI / Kubenet), Application Gateway integration (AGIC), OMS Agent, Microsoft Defender, Key Vault CSI Driver, Workload Identity, and OIDC.

## Usage

```bicep
// Generates: myapp-aks-dev
module aks 'modules/kubernetes-cluster/main.bicep' = {
  name: 'deploy-kubernetes-cluster'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    kubernetesVersion: '1.29'
    sshPublicKey: '<ssh-public-key>'
    defaultNodePool: {
      vmSize: 'Standard_D4s_v3'
      count: 3
      minCount: 1
      maxCount: 5
      osDiskSizeGB: 128
      osDiskType: 'Managed'
      maxPods: 30
      availabilityZones: [ '1', '2', '3' ]
      enableAutoScaling: true
      subnetId: subnet.outputs.id
      nodeLabels: {}
      nodeTaints: []
    }
    networkPlugin: 'azure'
    networkPolicy: 'azure'
    serviceCidr: '10.0.0.0/16'
    dnsServiceIp: '10.0.0.10'
  }
}

// Usage with a fully custom name
module aks2 'modules/kubernetes-cluster/main.bicep' = {
  name: 'deploy-kubernetes-cluster-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-aks'
    workloadName: 'myapp'
    environment: 'dev'
    kubernetesVersion: '1.29'
    sshPublicKey: '<ssh-public-key>'
    networkPlugin: 'azure'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `kubernetesVersion` | `string` | `'1.29'` | Kubernetes version to be used in the cluster. |
| `dnsPrefix` | `string` | `''` | DNS prefix for the cluster. If not provided, it will be generated based on the resource name. |
| `defaultNodePool` | `object` | *(see below)* | Default node pool configuration for the cluster. |
| `networkPlugin` | `string` | `'azure'` | Cluster network plugin. Allowed values: `azure`, `kubenet`, `none`. |
| `networkPolicy` | `string` | `'azure'` | Cluster network policy. Allowed values: `azure`, `calico`. |
| `serviceCidr` | `string` | `'10.0.0.0/16'` | Cluster network service CIDR. |
| `dnsServiceIp` | `string` | `'10.0.0.10'` | Cluster DNS service IP. |
| `loadBalancerSku` | `string` | `'standard'` | Cluster load balancer SKU. Allowed values: `basic`, `standard`. |
| `enableAzurePolicy` | `bool` | `true` | Enables Azure Policy for the cluster. |
| `enableOmsAgent` | `bool` | `false` | Enables the OMS Agent (Container Insights) for monitoring. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for OMS Agent and Defender. Required when `enableOmsAgent` or `enableDefender` is `true`. |
| `enableDefender` | `bool` | `false` | Enables Microsoft Defender for the cluster. |
| `enableKeyVaultSecretsProvider` | `bool` | `false` | Enables the Key Vault secrets provider (CSI Driver). |
| `enableWorkloadIdentity` | `bool` | `true` | Enables Workload Identity on the cluster. |
| `enableOidcIssuer` | `bool` | `true` | Enables the OIDC issuer on the cluster. |
| `sshPublicKey` | `string` | *(required, secure)* | SSH public key for accessing the cluster nodes. |
| `adminUsername` | `string` | `'azureuser'` | Administrator username for SSH access to the nodes. |
| `enablePrivateCluster` | `bool` | `false` | Enables private cluster mode (API Server accessible only via private network). |
| `authorizedIpRanges` | `array` | `[]` | List of authorized IP ranges to access the API Server. |
| `skuTier` | `string` | `'Free'` | AKS cluster SKU tier. Allowed values: `Free`, `Standard`, `Premium`. |
| `enableIngressApplicationGateway` | `bool` | `false` | Enables the Ingress Application Gateway integration (AGIC). |
| `appGatewayId` | `string` | `''` | ID of the existing Application Gateway for AGIC integration. Required when `enableIngressApplicationGateway` is `true`. |

### Default Node Pool (default object)

```bicep
{
  vmSize: 'Standard_D4s_v3'
  count: 3
  minCount: 1
  maxCount: 5
  osDiskSizeGB: 128
  osDiskType: 'Managed'
  maxPods: 30
  availabilityZones: [ '1', '2', '3' ]
  enableAutoScaling: true
  subnetId: ''
  nodeLabels: {}
  nodeTaints: []
}
```

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created AKS cluster. |
| `name` | `string` | Name of the created AKS cluster. |
| `fqdn` | `string` | FQDN of the AKS cluster. |
| `kubeletIdentityObjectId` | `string` | Object ID of the cluster's kubelet identity, used for RBAC assignments (e.g., AcrPull). |
| `oidcIssuerUrl` | `string` | OIDC issuer URL of the cluster, used for Workload Identity configuration. |

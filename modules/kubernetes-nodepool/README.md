# Kubernetes Node Pool

Bicep module for provisioning an additional node pool on an existing AKS cluster. The node pool name is provided directly by the user via the `nodePoolName` parameter (maximum 12 characters, AKS limitation). Supports auto scaling, Spot VMs, labels, taints, and availability zones. When configured with Spot VMs, availability zones are automatically disabled and the eviction policy is set to `Delete`.

## Usage

```bicep
module nodePool 'modules/kubernetes-nodepool/main.bicep' = {
  name: 'deploy-kubernetes-nodepool'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    clusterName: aksCluster.outputs.name
    nodePoolName: 'userpool'
    vmSize: 'Standard_D4s_v3'
    subnetId: subnet.outputs.id
    count: 3
    minCount: 1
    maxCount: 10
    enableAutoScaling: true
    nodeLabels: {
      workload: 'api'
    }
  }
}
```

> **Note:** This module does not use automatic naming. The node pool name is defined directly by the `nodePoolName` parameter. The `workloadName` and `environment` parameters are kept for interface standardization across modules and tag composition.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Kept for interface standardization across modules. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `clusterName` | `string` | *(required)* | Name of the existing AKS cluster where the node pool will be created. |
| `nodePoolName` | `string` | *(required)* | Node pool name (maximum 12 characters, AKS limitation). |
| `vmSize` | `string` | `'Standard_D4s_v3'` | VM size for the pool nodes. |
| `count` | `int` | `3` | Initial number of nodes in the pool. |
| `minCount` | `int` | `1` | Minimum number of nodes when auto scaling is enabled. |
| `maxCount` | `int` | `5` | Maximum number of nodes when auto scaling is enabled. |
| `enableAutoScaling` | `bool` | `true` | Enables auto scaling for the node pool. |
| `osDiskSizeGB` | `int` | `128` | OS disk size in GB. |
| `osDiskType` | `string` | `'Managed'` | OS disk type. Allowed values: `Managed`, `Ephemeral`. |
| `maxPods` | `int` | `30` | Maximum number of pods per node. |
| `availabilityZones` | `array` | `[ '1', '2', '3' ]` | Availability zones for the pool nodes. |
| `subnetId` | `string` | *(required)* | ID of the subnet where the pool nodes will be deployed. |
| `mode` | `string` | `'User'` | Node pool mode. Allowed values: `System`, `User`. |
| `osType` | `string` | `'Linux'` | Node operating system type. Allowed values: `Linux`, `Windows`. |
| `nodeLabels` | `object` | `{}` | Labels to be applied to the pool nodes. |
| `nodeTaints` | `array` | `[]` | Taints to be applied to the pool nodes. |
| `scaleSetPriority` | `string` | `'Regular'` | Scale set priority. Allowed values: `Regular`, `Spot`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created node pool. |
| `name` | `string` | Name of the created node pool. |

# NuvTools - Private Endpoint

Bicep Module for provisioning a Private Endpoint with optional DNS Zone Group integration following the NuvTools naming convention (`{prefix}-{workloadName}-pep-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-pep-{environment}`. The `name` parameter allows you to completely override the automatic name. Allows connecting Azure resources via private link, with automatic DNS registration when a private DNS zone is provided.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-pep-dev)
module privateEndpoint 'modules/private-endpoint/main.bicep' = {
  name: 'deploy-private-endpoint'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    subnetId: subnet.outputs.id
    privateConnectionResourceId: storageAccount.outputs.id
    groupIds: [
      'blob'
    ]
    privateDnsZoneId: privateDnsZone.outputs.id
  }
}

// Usage with a custom full name
module privateEndpoint2 'modules/private-endpoint/main.bicep' = {
  name: 'deploy-private-endpoint-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'meu-pep-customizado'
    workloadName: 'myapp'
    environment: 'dev'
    subnetId: subnet.outputs.id
    privateConnectionResourceId: storageAccount.outputs.id
    groupIds: [
      'blob'
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is ignored. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `subnetId` | `string` | *(required)* | ID of the subnet where the Private Endpoint will be created. |
| `privateConnectionResourceId` | `string` | *(required)* | ID of the target resource to which the Private Endpoint will be connected. |
| `groupIds` | `array` | *(required)* | List of group IDs of the target resource. Example: `['blob']`, `['sqlServer']`. |
| `privateDnsZoneId` | `string` | `''` | ID of the private DNS zone for automatic DNS record integration. Leave empty to skip DNS Zone Group creation. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Private Endpoint. |
| `name` | `string` | Name of the created Private Endpoint. |
| `networkInterfaceId` | `string` | ID of the Private Endpoint's network interface. |

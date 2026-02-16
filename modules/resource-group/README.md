# Resource Group

Bicep Module for provisioning a Resource Group following a configurable naming convention (`{prefix}-{workloadName}-rg-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-rg-{environment}`. The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-rg-dev)
module resourceGroup 'modules/resource-group/main.bicep' = {
  name: 'deploy-resource-group'
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    tags: {
      ManagedBy: 'Bicep'
    }
  }
}

// Usage without prefix (generates: myapp-rg-dev)
module resourceGroup2 'modules/resource-group/main.bicep' = {
  name: 'deploy-resource-group-2'
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
  }
}

// Usage with a custom full name
module resourceGroup3 'modules/resource-group/main.bicep' = {
  name: 'deploy-resource-group-3'
  params: {
    name: 'meu-rg-customizado'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
  }
}
```

> **Note:** This module uses `targetScope = 'subscription'`, therefore it must be deployed at the subscription scope.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is ignored. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{}` | Tags to be applied to the resource. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Resource Group. |
| `name` | `string` | Name of the created Resource Group. |
| `location` | `string` | Location of the created Resource Group. |

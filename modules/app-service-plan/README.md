# App Service Plan

Bicep Module for provisioning an App Service Plan (Linux or Windows) that hosts one or more web apps / function apps, following a configurable naming convention (`{workloadName}-asp-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-asp-dev (Linux, B3)
module plan 'modules/app-service-plan/main.bicep' = {
  name: 'deploy-app-service-plan'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    skuName: 'B3'
    capacity: 1
    linux: true
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'B1'` | App Service Plan SKU name (e.g., `B1`, `B2`, `B3`, `S1`, `P1v3`, `P2v3`). |
| `capacity` | `int` | `1` | Number of instances (workers) for the plan. |
| `linux` | `bool` | `true` | Hosts Linux containers when `true`; Windows when `false`. |
| `zoneRedundant` | `bool` | `false` | Enables zone redundancy. Requires a Premium SKU and a region with availability zones. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created App Service Plan. |
| `name` | `string` | Name of the created App Service Plan. |

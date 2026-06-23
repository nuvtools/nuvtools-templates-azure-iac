# User-Assigned Managed Identity

Bicep Module for provisioning a standalone user-assigned managed identity that can be shared by multiple resources (web apps, containers, etc.), following a configurable naming convention (`{workloadName}-id-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-id-dev
module identity 'modules/managed-identity/main.bicep' = {
  name: 'deploy-identity'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
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

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created user-assigned managed identity. |
| `name` | `string` | Name of the created user-assigned managed identity. |
| `principalId` | `string` | Principal (object) ID of the identity, used for role assignments. |
| `clientId` | `string` | Client ID of the identity, used by applications to authenticate. |

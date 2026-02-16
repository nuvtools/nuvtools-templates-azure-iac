# Role Assignment

Generic Bicep Module for creating an Azure role assignment (RBAC). The assignment name is generated deterministically (GUID) based on the `workloadName`, `environment`, `principalId`, and `roleDefinitionId` parameters, ensuring idempotency across deployments. This module does not follow the `{workloadName}-{abbr}-{environment}` naming convention because role assignments use GUIDs as names.

## Usage

```bicep
module roleAssignment 'modules/role-assignment/main.bicep' = {
  name: 'deploy-role-assignment'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    principalId: '00000000-0000-0000-0000-000000000000'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalType: 'ServicePrincipal'
    description: 'Contributor permission for the application service principal.'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workloadName` | `string` | *(required)* | Workload name. Used to generate a unique name (GUID) for the role assignment. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region. Not used directly by the resource, but kept for standardization across modules. |
| `tags` | `object` | `{}` | Default tags. Not applicable to role assignments, but kept for standardization across modules. |
| `principalId` | `string` | *(required)* | ID of the security principal (user, group, or service principal) that will receive the role. |
| `roleDefinitionId` | `string` | *(required)* | Role definition ID. Can be the GUID of a built-in role or the full resource ID of a custom definition. |
| `principalType` | `string` | *(required)* | Type of the security principal that will receive the role. Allowed values: `ServicePrincipal`, `Group`, `User`. |
| `description` | `string` | `''` | Optional description for the role assignment. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created role assignment. |
| `name` | `string` | Name (GUID) of the created role assignment. |

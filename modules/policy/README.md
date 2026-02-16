# Policy Assignment

Bicep Module for creating an Azure Policy assignment at the subscription scope, with support for conditional managed identity (required for policies with DeployIfNotExists or Modify effect), customizable parameters, and configurable enforcement mode, following a configurable naming convention (`{workloadName}-policy-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
targetScope = 'subscription'

// Generates: security-policy-prod
module policyAssignment 'modules/policy/main.bicep' = {
  name: 'deploy-policy-assignment'
  params: {
    workloadName: 'security'
    environment: 'prod'
    location: 'brazilsouth'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000'
    displayName: 'Require tags on resources'
    policyDescription: 'Policy that requires mandatory tags on all resources.'
    enforcementMode: 'Default'
    identity: true
    parameters: {
      tagName: {
        value: 'Environment'
      }
    }
  }
}

// Usage with fully custom name
module policyAssignment2 'modules/policy/main.bicep' = {
  name: 'deploy-policy-assignment-2'
  params: {
    name: 'my-custom-policy'
    workloadName: 'security'
    environment: 'prod'
    location: 'brazilsouth'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000000'
    displayName: 'Custom policy'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name. Used to compose the policy assignment name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region. Required when managed identity is enabled. |
| `tags` | `object` | `{}` | Tags to be applied to the resource. |
| `policyDefinitionId` | `string` | *(required)* | ID of the policy definition to be assigned. |
| `displayName` | `string` | *(required)* | Display name of the policy assignment. |
| `policyDescription` | `string` | `''` | Optional description for the policy assignment. |
| `parameters` | `object` | `{}` | Optional parameters to be passed to the policy definition. |
| `enforcementMode` | `string` | `'Default'` | Policy enforcement mode. Allowed values: `Default`, `DoNotEnforce`. |
| `identity` | `bool` | `false` | Enables the system-assigned managed identity for the policy assignment. Required for policies with DeployIfNotExists or Modify effect. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created policy assignment. |
| `name` | `string` | Name of the created policy assignment. |

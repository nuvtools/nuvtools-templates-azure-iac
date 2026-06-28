# Container Apps Job

Bicep module for provisioning an Azure Container Apps job on an existing managed environment following a configurable naming convention (`{workloadName}-caj-{environment}`). The `name` parameter allows you to completely override the automatic name. Defaults to a schedule (cron) trigger for batch workloads; supports manual and event triggers. The job uses a user-assigned managed identity for registry pull and Key Vault secret resolution, and applies the same application-settings translation as the Container App module (plain values become env vars, `@Microsoft.KeyVault(...)` references become Key Vault-backed secrets).

## Usage

```bicep
// Generates: myapp-caj-dev — runs daily at 02:00 UTC
module nightlyJob 'modules/container-apps-job/main.bicep' = {
  name: 'deploy-nightly-job'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    managedEnvironmentId: env.outputs.id
    userAssignedIdentityId: identity.outputs.id
    containerRegistryLoginServer: acr.outputs.loginServer
    image: 'myappcrdev.azurecr.io/myapp-batch:abc123'
    triggerType: 'Schedule'
    cronExpression: '0 2 * * *'
    appSettings: [
      { name: 'ConnectionStrings__Database', value: '@Microsoft.KeyVault(VaultName=myapp-kv-dev;SecretName=myapp-database)' }
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment (e.g., `dev`, `uat`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `managedEnvironmentId` | `string` | *(required)* | Resource ID of the Container Apps managed environment. |
| `userAssignedIdentityId` | `string` | *(required)* | Resource ID of the user-assigned managed identity (registry pull + Key Vault). |
| `containerRegistryLoginServer` | `string` | *(required)* | Login server of the container registry. |
| `image` | `string` | *(required)* | Container image reference, including tag or digest. |
| `workloadProfileName` | `string` | `'Consumption'` | Workload profile that runs the job. Must exist on the environment. |
| `appSettings` | `array` | `[]` | Settings as `{ name, value }`. Values starting with `@Microsoft.KeyVault(...)` become Key Vault-backed secrets. |
| `triggerType` | `string` | `'Schedule'` | Job trigger: `Schedule`, `Manual`, `Event`. |
| `cronExpression` | `string` | `'0 2 * * *'` | Cron expression (UTC) for the schedule trigger. |
| `parallelism` | `int` | `1` | Replicas to run in parallel per execution. |
| `replicaCompletionCount` | `int` | `1` | Successful replica completions required for an execution to succeed. |
| `replicaTimeout` | `int` | `1800` | Maximum seconds a replica may run before termination. |
| `replicaRetryLimit` | `int` | `1` | Times a failed replica is retried. |
| `cpu` | `string` | `'0.5'` | vCPU allocated to the container. |
| `memory` | `string` | `'1Gi'` | Memory allocated to the container. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Container Apps job. |
| `name` | `string` | Name of the created Container Apps job. |

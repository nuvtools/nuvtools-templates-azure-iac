# Container App

Bicep module for provisioning an Azure Container App on an existing managed environment following a configurable naming convention (`{workloadName}-ca-{environment}`). The `name` parameter allows you to completely override the automatic name. The app uses a user-assigned managed identity for registry pull and Key Vault secret resolution, supports optional ingress, and accepts KEDA scale rules.

## Application settings translation

`appSettings` is supplied in the same `{ name, value }` shape as App Service. The module splits it automatically:

- **Plain values** become container environment variables (`{ name, value }`).
- **Key Vault references** of the form `@Microsoft.KeyVault(VaultName=<vault>;SecretName=<secret>)` become a deduplicated Key Vault-backed `secrets[]` entry (versionless URL, resolved by the user-assigned identity) plus an env var that references it (`{ name, secretRef }`). The env var name is preserved exactly, so application code is unchanged.

## Usage

```bicep
// HTTP app with internal ingress
module apiApp 'modules/container-app/main.bicep' = {
  name: 'deploy-api-app'
  scope: resourceGroup('my-rg')
  params: {
    name: 'myapp-api-app-dev'
    workloadName: 'myapp'
    environment: 'dev'
    managedEnvironmentId: env.outputs.id
    userAssignedIdentityId: identity.outputs.id
    containerRegistryLoginServer: acr.outputs.loginServer
    image: 'myappcrdev.azurecr.io/myapp-api:abc123'
    ingressEnabled: true
    ingressExternal: false
    targetPort: 8080
    minReplicas: 1
    appSettings: [
      { name: 'Some__Plain', value: 'value' }
      { name: 'ConnectionStrings__Database', value: '@Microsoft.KeyVault(VaultName=myapp-kv-dev;SecretName=myapp-database)' }
    ]
  }
}

// Queue worker (no ingress, scales to zero on Service Bus backlog)
module workerApp 'modules/container-app/main.bicep' = {
  name: 'deploy-worker-app'
  scope: resourceGroup('my-rg')
  params: {
    name: 'myapp-worker-app-dev'
    workloadName: 'myapp'
    environment: 'dev'
    managedEnvironmentId: env.outputs.id
    userAssignedIdentityId: identity.outputs.id
    containerRegistryLoginServer: acr.outputs.loginServer
    image: 'myappcrdev.azurecr.io/myapp-worker:abc123'
    ingressEnabled: false
    minReplicas: 0
    maxReplicas: 5
    scaleRules: [
      {
        name: 'my-queue'
        custom: {
          type: 'azure-servicebus'
          identity: identity.outputs.id
          metadata: { queueName: 'my-queue', messageCount: '5', namespace: 'myapp-sbns-dev' }
        }
      }
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
| `workloadProfileName` | `string` | `'Consumption'` | Workload profile that runs the app. Must exist on the environment. |
| `appSettings` | `array` | `[]` | Settings as `{ name, value }`. Values starting with `@Microsoft.KeyVault(...)` become Key Vault-backed secrets. |
| `ingressEnabled` | `bool` | `true` | Creates an ingress when true. Set false for background workers. |
| `ingressExternal` | `bool` | `false` | Exposes the app outside the environment when true. |
| `targetPort` | `int` | `8080` | Port the container listens on for ingress traffic. |
| `transport` | `string` | `'auto'` | Ingress transport: `auto`, `http`, `http2`, `tcp`. |
| `allowInsecure` | `bool` | `false` | Allows insecure (HTTP) ingress connections when true. |
| `minReplicas` | `int` | `1` | Minimum replicas. Use 0 to allow scale-to-zero for queue workers. |
| `maxReplicas` | `int` | `3` | Maximum replicas. |
| `cpu` | `string` | `'0.5'` | vCPU allocated to the container. |
| `memory` | `string` | `'1Gi'` | Memory allocated to the container. |
| `scaleRules` | `array` | `[]` | KEDA scale rules passed through to `template.scale.rules`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Container App. |
| `name` | `string` | Name of the created Container App. |
| `fqdn` | `string` | Ingress FQDN of the Container App. Empty when ingress is disabled. |

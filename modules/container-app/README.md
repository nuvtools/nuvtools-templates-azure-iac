# Container App

Bicep module for provisioning an Azure Container App on an existing managed environment following a configurable naming convention (`{workloadName}-ca-{environment}`). The `name` parameter allows you to completely override the automatic name. The app uses a user-assigned managed identity for registry pull and Key Vault secret resolution, supports optional ingress, and accepts KEDA scale rules.

## Core resource resolution: names vs. IDs

The managed environment, user-assigned identity and container registry can each be supplied in one of two ways — provide **exactly one** per pair (deployment fails otherwise):

- **By name** (`managedEnvironmentName`, `userAssignedIdentityName`, `containerRegistryName`): the module resolves the resource via an `existing` lookup in the deployment resource group. Preferred when the core resources live in the same resource group — consumers stop hardcoding API versions and resource IDs, so future API-version bumps happen only in this module.
- **By ID/login server** (`managedEnvironmentId`, `userAssignedIdentityId`, `containerRegistryLoginServer`): use when the resource lives outside the deployment resource group.

Two flags depend on the identity being resolvable by the module:

- `scaleRulesUseAppIdentity: true` injects the app user-assigned identity as the default `identity` of every `custom` KEDA scale rule, so rules don't repeat the resource ID. A rule that sets its own `identity` wins.
- `setAzureClientIdAppSetting: true` appends an `AZURE_CLIENT_ID` env var with the identity's client ID so `DefaultAzureCredential` selects it. Requires `userAssignedIdentityName`; do not also pass `AZURE_CLIENT_ID` in `appSettings` (duplicate env var names are rejected by Container Apps).

## Application settings translation

`appSettings` is supplied in the same `{ name, value }` shape as App Service. The module splits it automatically:

- **Plain values** become container environment variables (`{ name, value }`).
- **Key Vault references** of the form `@Microsoft.KeyVault(VaultName=<vault>;SecretName=<secret>)` become a deduplicated Key Vault-backed `secrets[]` entry (versionless URL, resolved by the user-assigned identity) plus an env var that references it (`{ name, secretRef }`). The env var name is preserved exactly, so application code is unchanged.

## First deployment: identity race

Creating a Container App with a user-assigned identity **and** `@Microsoft.KeyVault(...)` secret references in a single operation can fail because Container Apps may evaluate secret resolution before the identity is attached to the resource (`No managed service identities are associated with resource ...` / `IdentityDoesNotExist`). It only affects the very first create — once the app exists with its identity, later updates are safe.

Set `bootstrapIdentity: true` for that first deployment. The module then pre-creates the app (via `bootstrap.bicep`) with only the identity attached — a public placeholder image, scaled to zero, no ingress, no registries, no secrets — and the real configuration is applied as a second step that `dependsOn` it. Revert to `false` afterwards; it has no steady-state effect once the app exists.

## Usage

```bicep
// HTTP app with internal ingress, core resources resolved by name (same resource group)
module apiApp 'modules/container-app/main.bicep' = {
  name: 'deploy-api-app'
  scope: resourceGroup('my-rg')
  params: {
    name: 'myapp-api-app-dev'
    workloadName: 'myapp'
    environment: 'dev'
    managedEnvironmentName: 'myapp-cae-dev'
    userAssignedIdentityName: 'myapp-id-dev'
    containerRegistryName: 'myappcrdev'
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

// Queue worker (no ingress, scales to zero on Service Bus backlog); the app
// identity is injected into the KEDA rules by scaleRulesUseAppIdentity
module workerApp 'modules/container-app/main.bicep' = {
  name: 'deploy-worker-app'
  scope: resourceGroup('my-rg')
  params: {
    name: 'myapp-worker-app-dev'
    workloadName: 'myapp'
    environment: 'dev'
    managedEnvironmentName: 'myapp-cae-dev'
    userAssignedIdentityName: 'myapp-id-dev'
    containerRegistryName: 'myappcrdev'
    image: 'myappcrdev.azurecr.io/myapp-worker:abc123'
    ingressEnabled: false
    minReplicas: 0
    maxReplicas: 5
    scaleRulesUseAppIdentity: true
    scaleRules: [
      {
        name: 'my-queue'
        custom: {
          type: 'azure-servicebus'
          metadata: { queueName: 'my-queue', messageCount: '5', namespace: 'myapp-sbns-dev' }
        }
      }
    ]
  }
}

// Core resources in another resource group: pass IDs instead of names
module externalApp 'modules/container-app/main.bicep' = {
  name: 'deploy-external-app'
  scope: resourceGroup('my-rg')
  params: {
    name: 'myapp-ext-app-dev'
    workloadName: 'myapp'
    environment: 'dev'
    managedEnvironmentId: env.outputs.id
    userAssignedIdentityId: identity.outputs.id
    containerRegistryLoginServer: acr.outputs.loginServer
    image: 'myappcrdev.azurecr.io/myapp-ext:abc123'
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
| `managedEnvironmentName` | `string` | `''` | Name of the managed environment in the deployment resource group. Provide exactly one of this or `managedEnvironmentId`. |
| `managedEnvironmentId` | `string` | `''` | Resource ID of the Container Apps managed environment. Use for environments outside the deployment resource group. |
| `userAssignedIdentityName` | `string` | `''` | Name of the user-assigned managed identity in the deployment resource group. Provide exactly one of this or `userAssignedIdentityId`. |
| `userAssignedIdentityId` | `string` | `''` | Resource ID of the user-assigned managed identity (registry pull + Key Vault). |
| `containerRegistryName` | `string` | `''` | Name of the container registry in the deployment resource group. Provide exactly one of this or `containerRegistryLoginServer`. |
| `containerRegistryLoginServer` | `string` | `''` | Login server of the container registry. |
| `image` | `string` | *(required)* | Container image reference, including tag or digest. |
| `workloadProfileName` | `string` | `'Consumption'` | Workload profile that runs the app. Must exist on the environment. |
| `appSettings` | `array` | `[]` | Settings as `{ name, value }`. Values starting with `@Microsoft.KeyVault(...)` become Key Vault-backed secrets. |
| `setAzureClientIdAppSetting` | `bool` | `false` | Appends an `AZURE_CLIENT_ID` env var with the identity's client ID. Requires `userAssignedIdentityName`. |
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
| `scaleRulesUseAppIdentity` | `bool` | `false` | Injects the app identity as the default `identity` of every `custom` scale rule. Explicit per-rule identities win. |
| `runtime` | `object` | `{}` | Runtime stack passed to `configuration.runtime`. Empty omits the block. |
| `bootstrapIdentity` | `bool` | `false` | Pre-create the app with only its identity attached before secrets are added (first-deploy identity-race guard). See [First deployment](#first-deployment-identity-race). |
| `bootstrapImage` | `string` | `'mcr.microsoft.com/k8se/quickstart:latest'` | Public placeholder image for the bootstrap pass. Only used when `bootstrapIdentity` is true. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Container App. |
| `name` | `string` | Name of the created Container App. |
| `fqdn` | `string` | Ingress FQDN of the Container App. Empty when ingress is disabled. |

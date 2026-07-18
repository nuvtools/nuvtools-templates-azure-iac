// ---------------------------------------------------------------------------
// Bicep Module: Container App
// Creates an Azure Container App on an existing managed environment with a
// user-assigned identity, registry access, optional ingress and KEDA scale
// rules. Application settings are supplied in the same { name, value } shape as
// App Service: plain values become container env vars, and
// @Microsoft.KeyVault(...) references are translated into Key Vault-backed
// secrets resolved by the user-assigned identity.
// ---------------------------------------------------------------------------

metadata name = 'Container App'
metadata description = 'Module for creating a Container App with managed-identity registry access, Key Vault-backed secrets and KEDA scale rules following configurable naming conventions.'
metadata version = '1.3.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Full resource name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the resource name when name is not provided.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Name of the Container Apps managed environment in the deployment resource group. Takes precedence over managedEnvironmentId; provide exactly one of the two.')
param managedEnvironmentName string = ''

@description('Resource ID of the Container Apps managed environment that hosts the app. Use for environments outside the deployment resource group; provide exactly one of this or managedEnvironmentName.')
param managedEnvironmentId string = ''

@description('Name of the user-assigned managed identity in the deployment resource group. Takes precedence over userAssignedIdentityId; provide exactly one of the two.')
param userAssignedIdentityName string = ''

@description('Resource ID of the user-assigned managed identity used for registry pull and Key Vault secret resolution. Provide exactly one of this or userAssignedIdentityName.')
param userAssignedIdentityId string = ''

@description('Name of the container registry in the deployment resource group. Takes precedence over containerRegistryLoginServer; provide exactly one of the two.')
param containerRegistryName string = ''

@description('Login server of the container registry (e.g., myregistry.azurecr.io). Provide exactly one of this or containerRegistryName.')
param containerRegistryLoginServer string = ''

@description('Container image reference, including tag or digest.')
param image string

@description('Workload profile that runs the app. Must exist on the managed environment.')
param workloadProfileName string = 'Consumption'

@description('Application settings as an array of objects: { name: string, value: string }. Values starting with @Microsoft.KeyVault(...) become Key Vault-backed secrets.')
param appSettings array = []

@description('When true, appends an AZURE_CLIENT_ID env var with the client ID of the user-assigned identity so DefaultAzureCredential selects it. Requires userAssignedIdentityName.')
param setAzureClientIdAppSetting bool = false

@description('Creates an ingress when true. Set false for background workers with no inbound traffic.')
param ingressEnabled bool = true

@description('Exposes the app outside the environment when true. Inside an internal environment, false keeps it reachable only within the VNet.')
param ingressExternal bool = false

@description('Port the container listens on for ingress traffic.')
param targetPort int = 8080

@description('Ingress transport protocol.')
@allowed([
  'auto'
  'http'
  'http2'
  'tcp'
])
param transport string = 'auto'

@description('Allows insecure (HTTP) ingress connections when true.')
param allowInsecure bool = false

@description('Minimum number of replicas. Use 0 to allow scale-to-zero for queue workers.')
@minValue(0)
param minReplicas int = 1

@description('Maximum number of replicas.')
@minValue(1)
param maxReplicas int = 3

@description('vCPU allocated to the container (e.g., 0.5, 1.0). Must be valid for the workload profile.')
param cpu string = '0.5'

@description('Memory allocated to the container (e.g., 1Gi). Must pair with cpu for the workload profile.')
param memory string = '1Gi'

@description('KEDA scale rules passed through to template.scale.rules (e.g., azure-servicebus). Empty applies replica-count scaling only.')
param scaleRules array = []

@description('When true, injects the app user-assigned identity as the default identity of every custom KEDA scale rule that does not set one (identity-based scaler auth without repeating the resource ID per rule).')
param scaleRulesUseAppIdentity bool = false

@description('App runtime stack passed to configuration.runtime (e.g., { dotnet: { autoConfigureDataProtection: true } } or { java: { enableMetrics: true } }). Empty omits the runtime block.')
param runtime object = {}

@description('When true, pre-creates the app with only its user-assigned identity attached (placeholder image, no secrets) before applying the real configuration, avoiding the Container Apps create-time race where Key Vault secret resolution runs before the identity exists on the resource. Set true only for the first deployment of a new app/environment; it has no steady-state effect once the app exists.')
param bootstrapIdentity bool = false

@description('Public placeholder image used by the identity bootstrap pass (must pull without registry auth). Only used when bootstrapIdentity is true.')
param bootstrapImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

// =============================================================================
// Existing resources (name-based lookups)
// =============================================================================

resource managedEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' existing = if (!empty(managedEnvironmentName)) {
  name: managedEnvironmentName
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = if (!empty(userAssignedIdentityName)) {
  name: userAssignedIdentityName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = if (!empty(containerRegistryName)) {
  name: containerRegistryName
}

// =============================================================================
// Variables
// =============================================================================

// Exactly one of each name/ID pair must be provided. The checks are threaded
// through containerAppName because ARM inlines variables lazily and never
// evaluates a standalone fail().
var validEnvironmentInput = empty(managedEnvironmentName) != empty(managedEnvironmentId)
  ? true
  : fail('Provide exactly one of managedEnvironmentName or managedEnvironmentId.')
var validIdentityInput = empty(userAssignedIdentityName) != empty(userAssignedIdentityId)
  ? true
  : fail('Provide exactly one of userAssignedIdentityName or userAssignedIdentityId.')
var validRegistryInput = empty(containerRegistryName) != empty(containerRegistryLoginServer)
  ? true
  : fail('Provide exactly one of containerRegistryName or containerRegistryLoginServer.')
var validClientIdInput = !setAzureClientIdAppSetting || !empty(userAssignedIdentityName)
  ? true
  : fail('setAzureClientIdAppSetting requires userAssignedIdentityName.')
var inputsValid = validEnvironmentInput && validIdentityInput && validRegistryInput && validClientIdInput

var resolvedManagedEnvironmentId = empty(managedEnvironmentName) ? managedEnvironmentId : managedEnvironment.id
var resolvedIdentityId = empty(userAssignedIdentityName) ? userAssignedIdentityId : userAssignedIdentity.id
var resolvedLoginServer = empty(containerRegistryName)
  ? containerRegistryLoginServer
  : containerRegistry!.properties.loginServer

// Pattern: {workloadName}-ca-{environment} (CAF: ca)
var autoName = '${workloadName}-ca-${environment}'
var containerAppName = inputsValid ? (empty(name) ? autoName : name) : ''

// --- Application settings translation -------------------------------------
// A Key Vault reference looks like:
//   @Microsoft.KeyVault(VaultName=<vault>;SecretName=<secret>)
// Parse the vault and secret out of each reference and split the settings into
// plain env vars and Key Vault-backed secrets.
var kvPrefix = '@Microsoft.KeyVault('

var enrichedSettings = [
  for setting in appSettings: {
    name: setting.name
    rawValue: setting.value
    isKeyVaultRef: startsWith(setting.value, kvPrefix)
    // "VaultName=<vault>;SecretName=<secret>" once the prefix and trailing ')' are stripped.
    vaultName: startsWith(setting.value, kvPrefix)
      ? split(split(replace(replace(setting.value, kvPrefix, ''), ')', ''), ';')[0], '=')[1]
      : ''
    secretName: startsWith(setting.value, kvPrefix)
      ? split(split(replace(replace(setting.value, kvPrefix, ''), ')', ''), ';')[1], '=')[1]
      : ''
  }
]

var keyVaultRefs = [
  for setting in filter(enrichedSettings, setting => setting.isKeyVaultRef): {
    envName: setting.name
    // KV secret names are RFC1123-valid, which also satisfies ACA secret naming.
    secretRef: toLower(setting.secretName)
    keyVaultUrl: 'https://${setting.vaultName}${az.environment().suffixes.keyvaultDns}/secrets/${setting.secretName}'
  }
]

// Plain (non-secret) settings become env vars verbatim.
var plainEnv = [
  for setting in filter(enrichedSettings, setting => !setting.isKeyVaultRef): {
    name: setting.name
    value: setting.rawValue
  }
]

// Key Vault-backed settings become env vars that reference a container secret.
var secretEnv = [
  for ref in keyVaultRefs: {
    name: ref.envName
    secretRef: ref.secretRef
  }
]

// Multiple settings may point at the same Key Vault secret; ACA rejects
// duplicate secret names, so deduplicate by secretRef.
var distinctSecretRefs = union(map(keyVaultRefs, ref => ref.secretRef), [])
var secrets = [
  for secretRef in distinctSecretRefs: {
    name: secretRef
    keyVaultUrl: filter(keyVaultRefs, ref => ref.secretRef == secretRef)[0].keyVaultUrl
    identity: resolvedIdentityId
  }
]

var azureClientIdEnv = setAzureClientIdAppSetting
  ? [
      {
        name: 'AZURE_CLIENT_ID'
        value: userAssignedIdentity!.properties.clientId
      }
    ]
  : []

var containerEnv = concat(plainEnv, secretEnv, azureClientIdEnv)

// The app identity is injected as a default so explicit per-rule identities win.
var effectiveScaleRules = [
  for rule in scaleRules: scaleRulesUseAppIdentity && contains(rule, 'custom')
    ? union(rule, { custom: union({ identity: resolvedIdentityId }, rule.custom) })
    : rule
]

// =============================================================================
// Resources
// =============================================================================

// First-deploy identity guard: attach the user-assigned identity to the app
// before any @Microsoft.KeyVault secret is added, so ACA cannot evaluate secret
// resolution before the identity exists on the resource. See bootstrap.bicep.
module identityBootstrap 'bootstrap.bicep' = if (bootstrapIdentity) {
  name: 'bootstrap-identity-${containerAppName}'
  params: {
    name: containerAppName
    location: location
    tags: tags
    managedEnvironmentId: resolvedManagedEnvironmentId
    userAssignedIdentityId: resolvedIdentityId
    workloadProfileName: workloadProfileName
    image: bootstrapImage
  }
}

// API version must be a preview that exposes configuration.runtime.dotnet
// (RuntimeDotnet exists only in preview versions; every stable version removes it).
#disable-next-line use-recent-api-versions
resource containerApp 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resolvedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: resolvedManagedEnvironmentId
    workloadProfileName: workloadProfileName
    configuration: {
      activeRevisionsMode: 'Single'
      runtime: empty(runtime) ? null : runtime
      ingress: ingressEnabled
        ? {
            external: ingressExternal
            targetPort: targetPort
            transport: transport
            allowInsecure: allowInsecure
          }
        : null
      registries: [
        {
          server: resolvedLoginServer
          identity: resolvedIdentityId
        }
      ]
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: containerEnv
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: empty(scaleRules) ? null : effectiveScaleRules
      }
    }
  }
  dependsOn: bootstrapIdentity ? [identityBootstrap] : []
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Container App.')
output id string = containerApp.id

@description('Name of the created Container App.')
output name string = containerApp.name

@description('Ingress FQDN of the Container App. Empty when ingress is disabled.')
output fqdn string = ingressEnabled ? (containerApp.properties.configuration.ingress.?fqdn ?? '') : ''

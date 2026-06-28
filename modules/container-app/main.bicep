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
metadata version = '1.1.0'

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

@description('Resource ID of the Container Apps managed environment that hosts the app.')
param managedEnvironmentId string

@description('Resource ID of the user-assigned managed identity used for registry pull and Key Vault secret resolution.')
param userAssignedIdentityId string

@description('Login server of the container registry (e.g., myregistry.azurecr.io).')
param containerRegistryLoginServer string

@description('Container image reference, including tag or digest.')
param image string

@description('Workload profile that runs the app. Must exist on the managed environment.')
param workloadProfileName string = 'Consumption'

@description('Application settings as an array of objects: { name: string, value: string }. Values starting with @Microsoft.KeyVault(...) become Key Vault-backed secrets.')
param appSettings array = []

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

@description('App runtime stack passed to configuration.runtime (e.g., { dotnet: { autoConfigureDataProtection: true } } or { java: { enableMetrics: true } }). Empty omits the runtime block.')
param runtime object = {}

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-ca-{environment} (CAF: ca)
var autoName = '${workloadName}-ca-${environment}'
var containerAppName = empty(name) ? autoName : name

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
    identity: userAssignedIdentityId
  }
]

var containerEnv = concat(plainEnv, secretEnv)

// =============================================================================
// Resources
// =============================================================================

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
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
          server: containerRegistryLoginServer
          identity: userAssignedIdentityId
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
        rules: empty(scaleRules) ? null : scaleRules
      }
    }
  }
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

// ---------------------------------------------------------------------------
// Bicep Module: Container Apps Job
// Creates an Azure Container Apps job on an existing managed environment with a
// user-assigned identity and registry access. Defaults to a schedule (cron)
// trigger for batch workloads. Application settings follow the same translation
// as the Container App module: plain values become env vars and
// @Microsoft.KeyVault(...) references become Key Vault-backed secrets.
// ---------------------------------------------------------------------------

metadata name = 'Container Apps Job'
metadata description = 'Module for creating a Container Apps job (schedule/manual/event trigger) with managed-identity registry access and Key Vault-backed secrets following configurable naming conventions.'
metadata version = '1.0.0'

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

@description('Resource ID of the Container Apps managed environment that hosts the job.')
param managedEnvironmentId string

@description('Resource ID of the user-assigned managed identity used for registry pull and Key Vault secret resolution.')
param userAssignedIdentityId string

@description('Login server of the container registry (e.g., myregistry.azurecr.io).')
param containerRegistryLoginServer string

@description('Container image reference, including tag or digest.')
param image string

@description('Workload profile that runs the job. Must exist on the managed environment.')
param workloadProfileName string = 'Consumption'

@description('Application settings as an array of objects: { name: string, value: string }. Values starting with @Microsoft.KeyVault(...) become Key Vault-backed secrets.')
param appSettings array = []

@description('Job trigger type.')
@allowed([
  'Schedule'
  'Manual'
  'Event'
])
param triggerType string = 'Schedule'

@description('Cron expression for the schedule trigger (UTC). Used only when triggerType is Schedule.')
param cronExpression string = '0 2 * * *'

@description('Number of replicas to run in parallel per execution.')
@minValue(1)
param parallelism int = 1

@description('Number of successful replica completions required for an execution to succeed.')
@minValue(1)
param replicaCompletionCount int = 1

@description('Maximum duration in seconds a replica may run before it is terminated.')
param replicaTimeout int = 1800

@description('Number of times a failed replica is retried.')
@minValue(0)
param replicaRetryLimit int = 1

@description('vCPU allocated to the container (e.g., 0.5, 1.0). Must be valid for the workload profile.')
param cpu string = '0.5'

@description('Memory allocated to the container (e.g., 1Gi). Must pair with cpu for the workload profile.')
param memory string = '1Gi'

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-caj-{environment} (CAF: caj)
var autoName = '${workloadName}-caj-${environment}'
var jobName = empty(name) ? autoName : name

// --- Application settings translation (same rules as the Container App module) ---
var kvPrefix = '@Microsoft.KeyVault('

var enrichedSettings = [
  for setting in appSettings: {
    name: setting.name
    rawValue: setting.value
    isKeyVaultRef: startsWith(setting.value, kvPrefix)
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
    secretRef: toLower(setting.secretName)
    keyVaultUrl: 'https://${setting.vaultName}${az.environment().suffixes.keyvaultDns}/secrets/${setting.secretName}'
  }
]

var plainEnv = [
  for setting in filter(enrichedSettings, setting => !setting.isKeyVaultRef): {
    name: setting.name
    value: setting.rawValue
  }
]

var secretEnv = [
  for ref in keyVaultRefs: {
    name: ref.envName
    secretRef: ref.secretRef
  }
]

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

resource job 'Microsoft.App/jobs@2025-01-01' = {
  name: jobName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    environmentId: managedEnvironmentId
    workloadProfileName: workloadProfileName
    configuration: {
      triggerType: triggerType
      replicaTimeout: replicaTimeout
      replicaRetryLimit: replicaRetryLimit
      scheduleTriggerConfig: triggerType == 'Schedule'
        ? {
            cronExpression: cronExpression
            parallelism: parallelism
            replicaCompletionCount: replicaCompletionCount
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
          name: jobName
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: containerEnv
        }
      ]
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Container Apps job.')
output id string = job.id

@description('Name of the created Container Apps job.')
output name string = job.name

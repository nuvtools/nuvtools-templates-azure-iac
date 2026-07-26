// ---------------------------------------------------------------------------
// Bicep Module: Key Vault
// Creates an Azure Key Vault with RBAC authorization, soft delete, purge
// protection, network rules and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Key Vault'
metadata description = 'Module for creating a Key Vault with RBAC, soft delete, network rules and diagnostics following configurable naming conventions.'
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

@description('Key Vault SKU.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Enables RBAC-based authorization instead of access policies.')
param enableRbacAuthorization bool = true

@description('Enables soft delete for protection against accidental deletion.')
param enableSoftDelete bool = true

@description('Soft delete retention period in days.')
param softDeleteRetentionInDays int = 90

@description('Enables purge protection. Prevents permanent deletion during the retention period.')
param enablePurgeProtection bool = true

@description('Default action for network rules (Allow or Deny).')
@allowed([
  'Allow'
  'Deny'
])
param networkDefaultAction string = 'Deny'

@description('List of allowed subnet IDs for Key Vault access via service endpoints.')
param allowedSubnetIds array = []

@description('List of allowed IP ranges for Key Vault access (CIDR format or single IP).')
param allowedIpRanges array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('List of principal IDs that will receive the Key Vault Secrets User role on the Key Vault. Requires enableRbacAuthorization.')
param secretsUserPrincipalIds array = []

@description('List of principal IDs that will receive the Key Vault Certificate User role on the Key Vault. Requires enableRbacAuthorization.')
param certificateUserPrincipalIds array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-kv-{environment}
var autoName = '${workloadName}-kv-${environment}'
var keyVaultName = empty(name) ? autoName : name

// Builds virtual network rules only if subnets are provided
var virtualNetworkRules = [
  for subnetId in allowedSubnetIds: {
    id: subnetId
    ignoreMissingVnetServiceEndpoint: false
  }
]

// Builds IP rules only if IP ranges are provided
var ipRules = [
  for ipRange in allowedIpRanges: {
    value: ipRange
  }
]

// Built-in data plane read roles
var keyVaultSecretsUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
var keyVaultCertificateUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba')

// =============================================================================
// Resources
// =============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
    networkAcls: {
      defaultAction: networkDefaultAction
      bypass: 'AzureServices'
      virtualNetworkRules: virtualNetworkRules
      ipRules: ipRules
    }
  }
}

// Conditional role assignments for reading secrets
resource secretsUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in secretsUserPrincipalIds: {
    name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleDefinitionId)
    scope: keyVault
    properties: {
      roleDefinitionId: keyVaultSecretsUserRoleDefinitionId
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Conditional role assignments for reading certificates
resource certificateUserRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for principalId in certificateUserPrincipalIds: {
    name: guid(keyVault.id, principalId, keyVaultCertificateUserRoleDefinitionId)
    scope: keyVault
    properties: {
      roleDefinitionId: keyVaultCertificateUserRoleDefinitionId
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${keyVaultName}-diag'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Key Vault.')
output id string = keyVault.id

@description('Name of the created Key Vault.')
output name string = keyVault.name

@description('Key Vault URI for accessing secrets, keys and certificates.')
output vaultUri string = keyVault.properties.vaultUri

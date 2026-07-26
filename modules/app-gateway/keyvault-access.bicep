// ---------------------------------------------------------------------------
// Bicep Module: Application Gateway — Key Vault access
// Grants the gateway's user-assigned identity the built-in "Key Vault Secrets
// User" role on the vault holding the TLS certificate.
//
// This lives in its own module because a role assignment must be deployed at
// the scope of its target: when the vault sits in a different resource group
// (or subscription) than the gateway, the assignment cannot be declared inline.
// See main.bicep.
// ---------------------------------------------------------------------------

metadata name = 'Application Gateway Key Vault Access'
metadata description = 'Grants Key Vault Secrets User on the certificate vault to the Application Gateway identity.'
metadata version = '1.0.0'

targetScope = 'resourceGroup'

// =============================================================================
// Parameters
// =============================================================================

@description('Name of the existing Key Vault holding the TLS certificate.')
param keyVaultName string

@description('Principal ID of the identity that will read the certificate secret.')
param principalId string

// =============================================================================
// Variables
// =============================================================================

// Built-in role: Key Vault Secrets User.
var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

// =============================================================================
// Resources
// =============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource keyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the role assignment granting certificate read access.')
output id string = keyVaultAccess.id

@description('Name of the role assignment granting certificate read access.')
output name string = keyVaultAccess.name

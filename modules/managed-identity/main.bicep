// ---------------------------------------------------------------------------
// Bicep Module: User-Assigned Managed Identity
// Creates a standalone user-assigned managed identity that can be shared by
// multiple resources (web apps, containers, etc.).
// ---------------------------------------------------------------------------

metadata name = 'User-Assigned Managed Identity'
metadata description = 'Module for creating a user-assigned managed identity following configurable naming conventions.'
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

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-id-{environment} (CAF: id)
var autoName = '${workloadName}-id-${environment}'
var identityName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created user-assigned managed identity.')
output id string = managedIdentity.id

@description('Name of the created user-assigned managed identity.')
output name string = managedIdentity.name

@description('Principal (object) ID of the managed identity, used for role assignments.')
output principalId string = managedIdentity.properties.principalId

@description('Client ID of the managed identity, used by applications to authenticate.')
output clientId string = managedIdentity.properties.clientId

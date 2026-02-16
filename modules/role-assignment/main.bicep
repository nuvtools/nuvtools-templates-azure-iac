// ---------------------------------------------------------------------------
// Bicep Module: Role Assignment
// Creates a generic Azure role assignment (RBAC).
// ---------------------------------------------------------------------------

metadata name = 'Role Assignment'
metadata description = 'Generic module for creating an Azure role assignment (RBAC).'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Workload name. Used to generate a unique name for the role assignment.')
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region. Not used directly by the resource, but kept for standardization across modules.')
#disable-next-line no-unused-params
param location string = 'brazilsouth'

@description('Default tags. Not applicable to role assignments, but kept for standardization across modules.')
#disable-next-line no-unused-params
param tags object = {}

@description('ID of the security principal (user, group or service principal) that will receive the role.')
param principalId string

@description('Role definition ID. Can be the GUID of a built-in role or the full resource ID of a custom definition.')
param roleDefinitionId string

@description('Type of the security principal that will receive the role.')
@allowed([
  'ServicePrincipal'
  'Group'
  'User'
])
param principalType string

@description('Optional description for the role assignment.')
param description string = ''

// =============================================================================
// Variables
// =============================================================================

// Generates a deterministic GUID based on parameters to ensure idempotency
var roleAssignmentName = guid(workloadName, environment, principalId, roleDefinitionId)

// =============================================================================
// Resources
// =============================================================================

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
    description: !empty(description) ? description : null
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created role assignment.')
output id string = roleAssignment.id

@description('Name (GUID) of the created role assignment.')
output name string = roleAssignment.name

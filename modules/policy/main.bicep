// ---------------------------------------------------------------------------
// Bicep Module: Policy Assignment
// Creates an Azure policy assignment at the subscription scope.
// ---------------------------------------------------------------------------

metadata name = 'Policy Assignment'
metadata description = 'Module for creating an Azure Policy assignment at the subscription scope.'
metadata version = '1.0.0'

targetScope = 'subscription'

// =============================================================================
// Parameters
// =============================================================================

@description('Full resource name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the policy assignment name.')
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Azure region. Required when managed identity is enabled.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {}

@description('ID of the policy definition to be assigned.')
param policyDefinitionId string

@description('Display name of the policy assignment.')
param displayName string

@description('Optional description of the policy assignment.')
param policyDescription string = ''

@description('Optional parameters to pass to the policy definition.')
param parameters object = {}

@description('Policy enforcement mode.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Enables system-assigned managed identity for the policy assignment. Required for policies with DeployIfNotExists or Modify effect.')
param identity bool = false

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-policy-{environment}
var autoName = '${workloadName}-policy-${environment}'
var policyAssignmentName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: policyAssignmentName
  location: identity ? location : null
  #disable-next-line BCP187
  tags: tags
  identity: identity
    ? {
        type: 'SystemAssigned'
      }
    : null
  properties: {
    policyDefinitionId: policyDefinitionId
    displayName: displayName
    description: !empty(policyDescription) ? policyDescription : null
    parameters: !empty(parameters) ? parameters : null
    enforcementMode: enforcementMode
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created policy assignment.')
output id string = policyAssignment.id

@description('Name of the created policy assignment.')
output name string = policyAssignment.name

// ---------------------------------------------------------------------------
// Bicep Module: Resource Group
// Creates a Resource Group in Azure following configurable naming conventions.
// ---------------------------------------------------------------------------

metadata name = 'Resource Group'
metadata description = 'Module for creating a Resource Group following configurable naming conventions.'
metadata version = '1.0.0'

targetScope = 'subscription'

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
param tags object = {}

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-rg-{environment}
var autoName = '${workloadName}-rg-${environment}'
var resourceGroupName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Resource Group.')
output id string = resourceGroup.id

@description('Name of the created Resource Group.')
output name string = resourceGroup.name

@description('Location of the created Resource Group.')
output location string = resourceGroup.location

// ---------------------------------------------------------------------------
// Bicep Module: App Service Plan
// Creates an App Service Plan (Linux or Windows) that hosts one or more
// web apps / function apps.
// ---------------------------------------------------------------------------

metadata name = 'App Service Plan'
metadata description = 'Module for creating an App Service Plan (Linux or Windows) following configurable naming conventions.'
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

@description('App Service Plan SKU name (e.g., B1, B2, B3, S1, P1v3, P2v3).')
param skuName string = 'B1'

@description('Number of instances (workers) for the plan.')
param capacity int = 1

@description('Hosts Linux containers when true; Windows when false.')
param linux bool = true

@description('Enables zone redundancy. Requires a Premium SKU and a region with availability zones.')
param zoneRedundant bool = false

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-asp-{environment} (CAF: asp)
var autoName = '${workloadName}-asp-${environment}'
var planName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  tags: tags
  kind: linux ? 'linux' : 'app'
  sku: {
    name: skuName
    capacity: capacity
  }
  properties: {
    reserved: linux
    zoneRedundant: zoneRedundant
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created App Service Plan.')
output id string = appServicePlan.id

@description('Name of the created App Service Plan.')
output name string = appServicePlan.name

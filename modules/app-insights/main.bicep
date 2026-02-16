// ---------------------------------------------------------------------------
// Bicep Module: Application Insights
// Creates a workspace-based Application Insights resource
// with sampling and retention configuration.
// ---------------------------------------------------------------------------

metadata name = 'Application Insights'
metadata description = 'Module for creating Application Insights (workspace-based) with configurable sampling and retention following configurable naming conventions.'
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

@description('Application type monitored by Application Insights.')
param applicationType string = 'web'

@description('Log Analytics workspace ID to which Application Insights will be linked. Required for workspace-based Application Insights.')
param logAnalyticsWorkspaceId string

@description('Disables IP address masking in telemetry data.')
param disableIpMasking bool = false

@description('Data retention period in days.')
param retentionInDays int = 90

@description('Ingestion sampling percentage (0 to 100). A value of 100 means no sampling.')
param samplingPercentage int = 100

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-appi-{environment}
var autoName = '${workloadName}-appi-${environment}'
var appInsightsName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: logAnalyticsWorkspaceId
    DisableIpMasking: disableIpMasking
    SamplingPercentage: samplingPercentage
    #disable-next-line BCP073
    RetentionInDays: retentionInDays
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Application Insights.')
output id string = appInsights.id

@description('Name of the created Application Insights.')
output name string = appInsights.name

// Note: The instrumentationKey and connectionString are read-only properties.
// Although they are not marked as @secure in outputs, it is recommended to store
// them securely (e.g., in Key Vault) when using them in other deployments.

@description('Application Insights instrumentation key. Should be stored securely.')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights connection string. Should be stored securely.')
output connectionString string = appInsights.properties.ConnectionString

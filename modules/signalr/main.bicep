// ---------------------------------------------------------------------------
// Bicep Module: SignalR Service
// Creates an Azure SignalR Service with configurable service mode, allowed
// origins (CORS), live trace and conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'SignalR Service'
metadata description = 'Module for creating an Azure SignalR Service with service mode, CORS, live trace and diagnostics following configurable naming conventions.'
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

@description('SignalR service SKU.')
param skuName string = 'Standard_S1'

@description('Capacity (number of units) of the SignalR service.')
param skuCapacity int = 1

@description('SignalR service operation mode.')
@allowed([
  'Default'
  'Serverless'
  'Classic'
])
param serviceMode string = 'Default'

@description('Enables connectivity logs in the live trace.')
param enableConnectivityLogs bool = true

@description('Enables messaging logs in the live trace.')
param enableMessagingLogs bool = false

@description('Enables live trace for real-time monitoring.')
param enableLiveTrace bool = false

@description('List of allowed origins for CORS. Use [\'*\'] to allow all origins.')
param allowedOrigins array = ['*']

@description('Defines whether public network access is enabled or disabled.')
param publicNetworkAccess string = 'Enabled'

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-sigr-{environment}
var autoName = '${workloadName}-sigr-${environment}'
var signalRName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource signalRService 'Microsoft.SignalRService/signalR@2024-08-01-preview' = {
  name: signalRName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  kind: 'SignalR'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    features: [
      {
        flag: 'ServiceMode'
        value: serviceMode
      }
      {
        flag: 'EnableConnectivityLogs'
        value: string(enableConnectivityLogs)
      }
      {
        flag: 'EnableMessagingLogs'
        value: string(enableMessagingLogs)
      }
      {
        flag: 'EnableLiveTrace'
        value: string(enableLiveTrace)
      }
    ]
    cors: {
      allowedOrigins: allowedOrigins
    }
    publicNetworkAccess: publicNetworkAccess
    tls: {
      clientCertEnabled: false
    }
    liveTraceConfiguration: enableLiveTrace
      ? {
          enabled: 'true'
          categories: [
            {
              name: 'ConnectivityLogs'
              enabled: enableConnectivityLogs ? 'true' : 'false'
            }
            {
              name: 'MessagingLogs'
              enabled: enableMessagingLogs ? 'true' : 'false'
            }
            {
              name: 'HttpRequestLogs'
              enabled: 'true'
            }
          ]
        }
      : null
  }
}

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${signalRName}-diag'
  scope: signalRService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
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

@description('ID of the created SignalR service.')
output id string = signalRService.id

@description('Name of the created SignalR service.')
output name string = signalRService.name

@description('Host name of the SignalR service.')
output hostName string = signalRService.properties.hostName

@description('Public port of the SignalR service.')
output publicPort int = signalRService.properties.publicPort

// ---------------------------------------------------------------------------
// Bicep Module: Azure AI Foundry (AIServices)
// Creates a Microsoft.CognitiveServices/accounts resource of kind 'AIServices'
// (the Foundry multi-service account that also exposes the OpenAI endpoint at
// {customSubDomain}.openai.azure.com), with optional model deployments and
// conditional diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Azure AI Foundry (AIServices)'
metadata description = 'Module for creating an Azure AI Foundry (AIServices) account with model deployments and diagnostics following configurable naming conventions.'
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

@description('Azure region where the resource will be created. Must offer the requested models.')
param location string = 'eastus2'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('SKU of the AIServices account.')
param skuName string = 'S0'

@description('Custom subdomain label (required for AAD/token auth and the .openai.azure.com endpoint). Empty uses the account name.')
param customSubDomainName string = ''

@description('Defines whether public network access is enabled or disabled.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Disables local (API key) authentication when true, forcing Entra ID only.')
param disableLocalAuth bool = false

@description('''Model deployments to create. Array of objects:
{ name: <deployment name>, modelName: <model>, modelVersion: <version?>, skuName: <GlobalStandard|Standard|...?>, capacity: <int?> }.''')
param modelDeployments array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-oai-{environment}
var autoName = '${workloadName}-oai-${environment}'
var accountName = empty(name) ? autoName : name
var subDomain = empty(customSubDomainName) ? accountName : customSubDomainName

// =============================================================================
// Resources
// =============================================================================

resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: skuName
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: subDomain
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
  }
}

// Model deployments — created one at a time (the account serializes deployment writes).
@batchSize(1)
resource deployments 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [
  for deployment in modelDeployments: {
    parent: account
    name: deployment.name
    sku: {
      name: deployment.?skuName ?? 'GlobalStandard'
      capacity: deployment.?capacity ?? 10
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: deployment.modelName
        version: deployment.?modelVersion
      }
    }
  }
]

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${accountName}-diag'
  scope: account
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

@description('ID of the created AIServices account.')
output id string = account.id

@description('Name of the created AIServices account.')
output name string = account.name

@description('Primary (Cognitive Services) endpoint of the account.')
output endpoint string = account.properties.endpoint

@description('OpenAI endpoint of the account (https://{subdomain}.openai.azure.com/).')
output openAiEndpoint string = 'https://${subDomain}.openai.azure.com/'

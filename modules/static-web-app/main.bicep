// ---------------------------------------------------------------------------
// Bicep Module: Static Web App
// Creates an Azure Static Web App with no linked repository: content is
// uploaded by a pipeline (Azure/static-web-apps-deploy with the deployment
// token), so the build stays in the consumer's workflow.
// ---------------------------------------------------------------------------

metadata name = 'Static Web App'
metadata description = 'Module for creating an Azure Static Web App, optionally with custom domains, following configurable naming conventions.'
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

@description('Azure region for the app\'s management plane; content is served from a global edge. Static Web Apps exists only in a few regions: westus2, centralus, eastus2, westeurope, eastasia.')
@allowed([
  'westus2'
  'centralus'
  'eastus2'
  'westeurope'
  'eastasia'
])
param location string = 'eastus2'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Pricing tier. Free has no SLA and allows two custom domains; Standard adds the SLA, more domains, private endpoints and bring-your-own functions.')
@allowed([
  'Free'
  'Standard'
])
param skuName string = 'Free'

@description('Whether pull requests get their own preview environment.')
@allowed([
  'Enabled'
  'Disabled'
])
param stagingEnvironmentPolicy string = 'Enabled'

@description('Whether staticwebapp.config.json may change the app\'s configuration on deploy.')
param allowConfigFileUpdates bool = true

@description('Subdomains to bind with CNAME validation (e.g. \'www.example.com\'). The CNAME to the app\'s default host name must already resolve publicly, or the deployment waits and fails. An apex domain needs TXT validation and cannot be declared here.')
param customDomains array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-stapp-{environment} (CAF: stapp)
var autoName = '${workloadName}-stapp-${environment}'
var staticSiteName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

resource staticSite 'Microsoft.Web/staticSites@2025-03-01' = {
  name: staticSiteName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    stagingEnvironmentPolicy: stagingEnvironmentPolicy
    allowConfigFileUpdates: allowConfigFileUpdates
  }
}

@batchSize(1) // the service validates one domain at a time
resource domains 'Microsoft.Web/staticSites/customDomains@2025-03-01' = [for domain in customDomains: {
  name: domain
  parent: staticSite
  properties: {
    validationMethod: 'cname-delegation'
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created static web app.')
output id string = staticSite.id

@description('Name of the created static web app.')
output name string = staticSite.name

@description('Default host name (e.g. \'<random>.azurestaticapps.net\'), the target for CNAME records.')
output defaultHostname string = staticSite.properties.defaultHostname

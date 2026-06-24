// ---------------------------------------------------------------------------
// Bicep Module: Web App (App Service)
// Creates a Linux/Windows Web App on an existing App Service Plan with
// regional VNet integration, system and/or user-assigned identity and
// application settings (which may include Key Vault references).
// ---------------------------------------------------------------------------

metadata name = 'Web App'
metadata description = 'Module for creating a Web App (App Service) with VNet integration, managed identity and application settings following configurable naming conventions.'
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

@description('Resource ID of the App Service Plan that will host the web app.')
param appServicePlanId string

@description('Hosts a Linux container when true; Windows when false.')
param linux bool = true

@description('Runtime stack for Linux apps (e.g., DOTNETCORE|10.0). Ignored for Windows apps.')
param linuxFxVersion string = ''

@description('Redirects all HTTP traffic to HTTPS when true.')
param httpsOnly bool = true

@description('Keeps the app warm (recommended for production and background workers).')
param alwaysOn bool = true

@description('Routes all outbound traffic through the integrated VNet when true.')
param vnetRouteAllEnabled bool = true

@description('Resource ID of the subnet used for regional VNet integration. Empty disables integration.')
param virtualNetworkSubnetId string = ''

@description('Resource ID of a user-assigned managed identity to attach. Empty attaches none.')
param userAssignedIdentityId string = ''

@description('Enables the system-assigned managed identity.')
param enableSystemAssignedIdentity bool = true

@description('Resource ID of the identity used to resolve Key Vault references. Empty uses the system-assigned identity.')
param keyVaultReferenceIdentityId string = ''

@description('Application settings as an array of objects: { name: string, value: string }. Values may be Key Vault references.')
param appSettings array = []

@description('Relative health-check path (e.g., /health). Empty disables the health check.')
param healthCheckPath string = ''

@description('Explicit startup command (e.g., dotnet MyApp.dll). Empty lets the platform auto-detect the entry point.')
param appCommandLine string = ''

@description('Minimum TLS version accepted by the app.')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minTlsVersion string = '1.2'

@description('FTP/FTPS publishing state.')
@allowed([
  'AllAllowed'
  'FtpsOnly'
  'Disabled'
])
param ftpsState string = 'Disabled'

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-app-{environment} (CAF: app)
var autoName = '${workloadName}-app-${environment}'
var siteName = empty(name) ? autoName : name

var hasUserIdentity = !empty(userAssignedIdentityId)

var identityType = enableSystemAssignedIdentity && hasUserIdentity
  ? 'SystemAssigned, UserAssigned'
  : enableSystemAssignedIdentity
      ? 'SystemAssigned'
      : hasUserIdentity ? 'UserAssigned' : 'None'

// =============================================================================
// Resources
// =============================================================================

resource webApp 'Microsoft.Web/sites@2024-11-01' = {
  name: siteName
  location: location
  tags: tags
  kind: linux ? 'app,linux' : 'app'
  identity: {
    type: identityType
    userAssignedIdentities: hasUserIdentity
      ? {
          '${userAssignedIdentityId}': {}
        }
      : null
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    keyVaultReferenceIdentity: empty(keyVaultReferenceIdentityId) ? null : keyVaultReferenceIdentityId
    virtualNetworkSubnetId: empty(virtualNetworkSubnetId) ? null : virtualNetworkSubnetId
    siteConfig: {
      linuxFxVersion: linux && !empty(linuxFxVersion) ? linuxFxVersion : null
      appCommandLine: empty(appCommandLine) ? null : appCommandLine
      alwaysOn: alwaysOn
      vnetRouteAllEnabled: empty(virtualNetworkSubnetId) ? false : vnetRouteAllEnabled
      ftpsState: ftpsState
      minTlsVersion: minTlsVersion
      healthCheckPath: empty(healthCheckPath) ? null : healthCheckPath
      appSettings: appSettings
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Web App.')
output id string = webApp.id

@description('Name of the created Web App.')
output name string = webApp.name

@description('Default host name of the Web App.')
output defaultHostName string = webApp.properties.defaultHostName

@description('Principal (object) ID of the system-assigned identity. Empty when disabled.')
output principalId string = enableSystemAssignedIdentity ? webApp.identity.principalId : ''

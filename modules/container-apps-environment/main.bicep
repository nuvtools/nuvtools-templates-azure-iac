// ---------------------------------------------------------------------------
// Bicep Module: Container Apps Environment
// Creates a VNet-injected Azure Container Apps managed environment (workload
// profiles) with Log Analytics app logging. An internal environment exposes a
// single private static IP inside the VNet (no public endpoint), which makes it
// the network isolation boundary for every app it hosts.
// ---------------------------------------------------------------------------

metadata name = 'Container Apps Environment'
metadata description = 'Module for creating a VNet-injected Container Apps managed environment (workload profiles) with Log Analytics logging following configurable naming conventions.'
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

@description('Resource ID of the infrastructure subnet. For workload-profile environments the subnet must be undelegated and at least /27.')
param infrastructureSubnetId string

@description('Name of the Log Analytics workspace (same resource group) that receives container app logs.')
param logAnalyticsWorkspaceName string

@description('Restricts the environment to a private static IP inside the VNet (no public endpoint) when true.')
param internal bool = true

@description('Spreads replicas across availability zones when true (requires a zone-redundant infrastructure subnet).')
param zoneRedundant bool = false

@description('Workload profiles available in the environment. Defaults to a single Consumption profile.')
param workloadProfiles array = [
  {
    name: 'Consumption'
    workloadProfileType: 'Consumption'
  }
]

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-cae-{environment} (CAF: cae)
var autoName = '${workloadName}-cae-${environment}'
var environmentName = empty(name) ? autoName : name

// =============================================================================
// Resources
// =============================================================================

// The Log Analytics module does not export the shared key (forbidden by the
// outputs-should-not-contain-secrets rule), so it is read here via listKeys.
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: internal
    }
    workloadProfiles: workloadProfiles
    zoneRedundant: zoneRedundant
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Container Apps environment.')
output id string = managedEnvironment.id

@description('Name of the created Container Apps environment.')
output name string = managedEnvironment.name

@description('Default domain of the environment. Container app FQDNs are <app>.<defaultDomain>.')
output defaultDomain string = managedEnvironment.properties.defaultDomain

@description('Static IP of the environment. For an internal environment this is the private VIP inside the VNet.')
output staticIp string = managedEnvironment.properties.staticIp

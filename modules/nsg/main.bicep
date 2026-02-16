// ---------------------------------------------------------------------------
// Bicep Module: Network Security Group
// Creates a Network Security Group in Azure following configurable naming conventions.
// ---------------------------------------------------------------------------

metadata name = 'Network Security Group'
metadata description = 'Module for creating a Network Security Group following configurable naming conventions.'
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

@description('List of NSG security rules. Each rule must contain: name, priority, direction, access, protocol, sourcePortRange, destinationPortRange, sourceAddressPrefix, destinationAddressPrefix.')
param securityRules array = []

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('ID of the Log Analytics workspace for diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-nsg-{environment}
var autoName = '${workloadName}-nsg-${environment}'
var networkSecurityGroupName = empty(name) ? autoName : name

// Formats the rules in the structure expected by Azure
var formattedSecurityRules = [for rule in securityRules: {
  name: rule.name
  properties: {
    priority: rule.priority
    direction: rule.direction
    access: rule.access
    protocol: rule.protocol
    sourcePortRange: rule.sourcePortRange
    destinationPortRange: rule.destinationPortRange
    sourceAddressPrefix: rule.sourceAddressPrefix
    destinationAddressPrefix: rule.destinationAddressPrefix
  }
}]

// =============================================================================
// Resources
// =============================================================================

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: networkSecurityGroupName
  location: location
  tags: tags
  properties: {
    securityRules: formattedSecurityRules
  }
}

#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && logAnalyticsWorkspaceId != '') {
  name: '${networkSecurityGroupName}-diag'
  scope: networkSecurityGroup
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Network Security Group.')
output id string = networkSecurityGroup.id

@description('Name of the created Network Security Group.')
output name string = networkSecurityGroup.name

// ---------------------------------------------------------------------------
// Bicep Module: Azure Firewall
// Creates an Azure Firewall with a Firewall Policy and a network rule
// collection group, associating an existing public IP. Suited to centralized
// hub egress (SNAT to a fixed public IP) in a hub-spoke topology.
// ---------------------------------------------------------------------------

metadata name = 'Azure Firewall'
metadata description = 'Module for creating an Azure Firewall + Firewall Policy with a network rule collection group, reusing an existing public IP, following configurable naming conventions.'
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

@description('Firewall SKU tier.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuTier string = 'Standard'

@description('Resource ID of the AzureFirewallSubnet.')
param subnetId string

@description('Resource ID of an existing public IP to associate with the firewall.')
param publicIpId string

@description('''Egress network rules. Array of objects:
{ name, sourceAddresses[], destinationAddresses[], destinationPorts[], protocols[] }.''')
param networkRules array = []

@description('Priority of the network rule collection group and its collection (100-65000).')
@minValue(100)
@maxValue(65000)
param networkRuleCollectionPriority int = 200

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-afw-{environment} (CAF: afw)
var autoName = '${workloadName}-afw-${environment}'
var firewallName = empty(name) ? autoName : name
var firewallPolicyName = '${workloadName}-afwp-${environment}'

// =============================================================================
// Resources
// =============================================================================

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2025-07-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: skuTier
    }
  }
}

resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2025-07-01' = {
  name: 'DefaultNetworkRuleCollectionGroup'
  parent: firewallPolicy
  properties: {
    priority: networkRuleCollectionPriority
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'egress-network-rules'
        priority: networkRuleCollectionPriority
        action: {
          type: 'Allow'
        }
        rules: [
          for rule in networkRules: {
            ruleType: 'NetworkRule'
            name: rule.name
            sourceAddresses: rule.sourceAddresses
            destinationAddresses: rule.destinationAddresses
            destinationPorts: rule.destinationPorts
            ipProtocols: rule.protocols
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2025-07-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: skuTier
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  dependsOn: [
    ruleCollectionGroup
  ]
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created Azure Firewall.')
output id string = firewall.id

@description('Name of the created Azure Firewall.')
output name string = firewall.name

@description('Private IP address of the firewall (use as next hop for spoke UDRs).')
output privateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

// ---------------------------------------------------------------------------
// Bicep Module: VPN Connection (Site-to-Site)
// Creates an IPsec Site-to-Site connection between an existing Virtual Network
// Gateway (Azure side) and a Local Network Gateway (peer side), with optional
// custom IPsec/IKE policy and NAT rule associations.
// ---------------------------------------------------------------------------

metadata name = 'VPN Connection'
metadata description = 'Module for creating an IPsec Site-to-Site VPN connection with optional custom IPsec/IKE policy and NAT rules.'
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

@description('Resource ID of the Virtual Network Gateway (Azure side).')
param virtualNetworkGatewayId string

@description('Resource ID of the Local Network Gateway (peer side).')
param localNetworkGatewayId string

@description('Pre-shared key for the IPsec tunnel.')
@secure()
param sharedKey string

@description('IKE protocol version.')
@allowed([
  'IKEv1'
  'IKEv2'
])
param connectionProtocol string = 'IKEv2'

@description('Use policy-based (narrow) traffic selectors. Must be false when NAT rules are used.')
param usePolicyBasedTrafficSelectors bool = false

@description('Custom IPsec/IKE policies. Empty array = Azure default negotiation.')
param ipsecPolicies array = []

@description('Resource IDs of EgressSNAT rules to apply to this connection.')
param egressNatRuleIds array = []

@description('Resource IDs of IngressSNAT rules to apply to this connection.')
param ingressNatRuleIds array = []

@description('Enable BGP over this connection.')
param enableBgp bool = false

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-con-{environment} (CAF: con)
var autoName = '${workloadName}-con-${environment}'
var connectionName = empty(name) ? autoName : name

// =============================================================================
// Resource
// =============================================================================

resource connection 'Microsoft.Network/connections@2025-07-01' = {
  name: connectionName
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    connectionProtocol: connectionProtocol
    // The connection only consumes the gateway/LNG resource ID; Bicep's type for
    // these fields is the full resource, hence the BCP035 type-inaccuracy suppression.
    #disable-next-line BCP035
    virtualNetworkGateway1: {
      id: virtualNetworkGatewayId
    }
    #disable-next-line BCP035
    localNetworkGateway2: {
      id: localNetworkGatewayId
    }
    sharedKey: sharedKey
    usePolicyBasedTrafficSelectors: usePolicyBasedTrafficSelectors
    ipsecPolicies: ipsecPolicies
    enableBgp: enableBgp
    egressNatRules: [for ruleId in egressNatRuleIds: { id: ruleId }]
    ingressNatRules: [for ruleId in ingressNatRuleIds: { id: ruleId }]
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created connection.')
output id string = connection.id

@description('Name of the created connection.')
output name string = connection.name

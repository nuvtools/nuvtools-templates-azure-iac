// ---------------------------------------------------------------------------
// Bicep Module: Application Gateway
// Creates an Azure Application Gateway with public IP, user-assigned managed
// identity for Key Vault access, conditional WAF Policy and optional
// diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Application Gateway'
metadata description = 'Module for creating an Application Gateway with WAF, managed identity, SSL certificates and diagnostics following configurable naming conventions.'
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

@description('Application Gateway SKU name.')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuName string = 'WAF_v2'

@description('Application Gateway SKU tier.')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param skuTier string = 'WAF_v2'

@description('Fixed capacity of the Application Gateway (number of instances). Used when enableAutoScale is false.')
param capacity int = 2

@description('Subnet ID dedicated to the Application Gateway.')
param subnetId string

@description('Enables auto scaling for the Application Gateway.')
param enableAutoScale bool = false

@description('Minimum capacity when auto scaling is enabled.')
param minCapacity int = 1

@description('Maximum capacity when auto scaling is enabled.')
param maxCapacity int = 10

@description('Enables WAF policy on the Application Gateway.')
param enableWafPolicy bool = true

@description('WAF operation mode.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('Key Vault ID for SSL certificate access. When provided, creates a user-assigned managed identity with access.')
param keyVaultId string = ''

@description('List of SSL certificates from Key Vault for the Application Gateway. Each object must contain name and keyVaultSecretId.')
param sslCertificates array = []

@description('List of HTTP listeners for the Application Gateway. If empty, a default listener on port 80 will be created.')
param httpListeners array = []

@description('List of backend address pools. If empty, a default empty pool will be created.')
param backendAddressPools array = []

@description('List of backend HTTP settings. If empty, a default configuration on port 80 will be created.')
param backendHttpSettings array = []

@description('List of request routing rules. If empty, a default rule will be created.')
param requestRoutingRules array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-agw-{environment}
var autoName = '${workloadName}-agw-${environment}'
var appGatewayName = empty(name) ? autoName : name
var publicIpName = '${workloadName}-pip-agw-${environment}'
var identityName = '${workloadName}-id-agw-${environment}'
var wafPolicyName = '${workloadName}-waf-${environment}'

// Internal component names of the Application Gateway
var frontendIpConfigName = 'appGwPublicFrontendIP'
var frontendPortHttpName = 'frontend-http-80'
var gatewayIpConfigName = 'appGwGatewayIpConfig'

// Default settings when no customization is provided
var defaultBackendAddressPools = [
  {
    name: 'defaultBackendPool'
    properties: {
      backendAddresses: []
    }
  }
]

var defaultBackendHttpSettings = [
  {
    name: 'defaultHttpSettings'
    properties: {
      port: 80
      protocol: 'Http'
      cookieBasedAffinity: 'Disabled'
      requestTimeout: 60
      pickHostNameFromBackendAddress: false
    }
  }
]

var defaultHttpListeners = [
  {
    name: 'defaultHttpListener'
    properties: {
      frontendIPConfiguration: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, frontendIpConfigName)
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortHttpName)
      }
      protocol: 'Http'
    }
  }
]

var defaultRequestRoutingRules = [
  {
    name: 'defaultRoutingRule'
    properties: {
      ruleType: 'Basic'
      priority: 100
      httpListener: {
        id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'defaultHttpListener')
      }
      backendAddressPool: {
        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'defaultBackendPool')
      }
      backendHttpSettings: {
        id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'defaultHttpSettings')
      }
    }
  }
]

// Resolution: uses custom values or defaults
var resolvedBackendAddressPools = !empty(backendAddressPools) ? backendAddressPools : defaultBackendAddressPools
var resolvedBackendHttpSettings = !empty(backendHttpSettings) ? backendHttpSettings : defaultBackendHttpSettings
var resolvedHttpListeners = !empty(httpListeners) ? httpListeners : defaultHttpListeners
var resolvedRequestRoutingRules = !empty(requestRoutingRules) ? requestRoutingRules : defaultRequestRoutingRules

// SKU configuration with or without auto scaling
var skuProperties = enableAutoScale ? {
  name: skuName
  tier: skuTier
} : {
  name: skuName
  tier: skuTier
  capacity: capacity
}

var autoScaleConfig = enableAutoScale ? {
  minCapacity: minCapacity
  maxCapacity: maxCapacity
} : null

// Checks whether to create the managed identity for Key Vault access
var createIdentity = !empty(keyVaultId)

// Builds the SSL certificates formatted for the Application Gateway
var resolvedSslCertificates = [
  for cert in sslCertificates: {
    name: cert.name
    properties: {
      keyVaultSecretId: cert.keyVaultSecretId
    }
  }
]

// =============================================================================
// Resources
// =============================================================================

// Public IP for the Application Gateway frontend
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// User-assigned managed identity for Key Vault access (conditional)
resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = if (createIdentity) {
  name: identityName
  location: location
  tags: tags
}

// Conditional WAF policy
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-05-01' = if (enableWafPolicy && skuName == 'WAF_v2') {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: wafMode
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

// Application Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2024-05-01' = {
  name: appGatewayName
  location: location
  tags: tags
  identity: createIdentity ? {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentity.id}': {}
    }
  } : null
  properties: {
    sku: skuProperties
    autoscaleConfiguration: autoScaleConfig
    gatewayIPConfigurations: [
      {
        name: gatewayIpConfigName
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIpConfigName
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortHttpName
        properties: {
          port: 80
        }
      }
    ]
    sslCertificates: !empty(sslCertificates) ? resolvedSslCertificates : []
    backendAddressPools: resolvedBackendAddressPools
    backendHttpSettingsCollection: resolvedBackendHttpSettings
    httpListeners: resolvedHttpListeners
    requestRoutingRules: resolvedRequestRoutingRules
    firewallPolicy: enableWafPolicy && skuName == 'WAF_v2' ? {
      id: wafPolicy.id
    } : null
  }
}

// Conditional diagnostic settings
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: '${appGatewayName}-diag'
  scope: applicationGateway
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

@description('ID of the created Application Gateway.')
output id string = applicationGateway.id

@description('Name of the created Application Gateway.')
output name string = applicationGateway.name

@description('Public IP address of the Application Gateway.')
output publicIpAddress string = publicIp.properties.ipAddress

@description('Principal ID of the user-assigned managed identity, used for Key Vault access.')
output identityPrincipalId string = createIdentity ? userIdentity!.properties.principalId : ''

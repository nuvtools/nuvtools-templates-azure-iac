// ---------------------------------------------------------------------------
// Bicep Module: Application Gateway
// Creates an Azure Application Gateway with public IP, optional private
// frontend, user-assigned managed identity for Key Vault certificate access,
// conditional WAF Policy and optional diagnostics.
//
// Routing can be declared two ways:
//   * high level — the `sites` array expands into listeners, backend pools,
//     URL path maps and routing rules (HTTPS, one entry per fronted host);
//   * low level  — the httpListeners / backendAddressPools / backendHttpSettings
//     / requestRoutingRules / urlPathMaps arrays are passed through verbatim.
// Low level wins when both are supplied. With neither, a plain HTTP listener on
// port 80 is created.
// ---------------------------------------------------------------------------

metadata name = 'Application Gateway'
metadata description = 'Module for creating an Application Gateway with WAF, managed identity, Key Vault TLS certificates, host- and path-based routing and diagnostics following configurable naming conventions.'
metadata version = '2.0.0'

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

@description('Minimum capacity when auto scaling is enabled. Accepts 0 to scale down to no reserved instances.')
param minCapacity int = 1

@description('Maximum capacity when auto scaling is enabled.')
param maxCapacity int = 10

@description('Availability zones for the gateway and its public IP. Leave empty for a non-zonal deployment.')
param zones array = []

@description('Enables HTTP/2 on the Application Gateway frontend.')
param enableHttp2 bool = true

@description('Static private frontend IP address. Must fall inside the gateway subnet. Leave empty for a public-only gateway.')
param privateFrontendIpAddress string = ''

@description('Enables WAF policy on the Application Gateway.')
param enableWafPolicy bool = true

@description('WAF operation mode.')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('Managed rule sets applied by the WAF policy. Each object must contain ruleSetType and ruleSetVersion.')
param wafRuleSets array = [
  {
    ruleSetType: 'OWASP'
    ruleSetVersion: '3.2'
  }
  {
    ruleSetType: 'Microsoft_BotManagerRuleSet'
    ruleSetVersion: '0.1'
  }
]

@description('Enables sending diagnostics to Log Analytics.')
param enableDiagnostics bool = false

@description('Log Analytics workspace ID for sending diagnostics. Required when enableDiagnostics is true.')
param logAnalyticsWorkspaceId string = ''

@description('Resource ID of an existing Key Vault holding the TLS certificate. When provided, the gateway gets a user-assigned managed identity granted Key Vault Secrets User on the vault. The vault may live in any resource group or subscription.')
param keyVaultId string = ''

@description('Resource ID of an existing user-assigned managed identity to attach to the gateway. When empty, the module creates its own ({workloadName}-id-agw-{environment}). Reuse a shared platform identity to grant vault access once instead of per gateway.')
param identityId string = ''

@description('Grants the gateway identity Key Vault Secrets User on the vault. Disable when the deploying identity cannot write role assignments on the vault, and grant the access separately.')
param grantKeyVaultAccess bool = true

@description('Name of the Key Vault secret holding the TLS certificate. Referenced without a version so certificate rotation is picked up automatically.')
param certificateSecretName string = ''

@description('Internal name of the SSL certificate inside the Application Gateway. Referenced by the listeners generated from sites.')
param certificateName string = 'tls-cert'

@description('''Routed sites. One entry per fronted host, expanded into an HTTPS
listener, backend pools, an optional URL path map and a routing rule. Shape:
{ key, hostName, priority, defaultFqdn, usePrivateFrontend?, pathRules?: [{ name, paths, fqdn, stripPath? }] }.
A site without pathRules produces a Basic rule straight to its default pool.''')
param sites array = []

@description('Request timeout, in seconds, of the backend settings generated from sites.')
param backendRequestTimeout int = 60

@description('List of SSL certificates from Key Vault. Each object must contain name and keyVaultSecretId. Appended to the certificate generated from certificateSecretName.')
param sslCertificates array = []

@description('List of HTTP listeners. Overrides the listeners generated from sites. If both are empty, a default listener on port 80 will be created.')
param httpListeners array = []

@description('List of backend address pools. Overrides the pools generated from sites. If both are empty, a default empty pool will be created.')
param backendAddressPools array = []

@description('List of backend HTTP settings. Overrides the settings generated from sites. If both are empty, a default configuration on port 80 will be created.')
param backendHttpSettings array = []

@description('List of request routing rules. Overrides the rules generated from sites. If both are empty, a default rule will be created.')
param requestRoutingRules array = []

@description('List of URL path maps. Overrides the path maps generated from sites.')
param urlPathMaps array = []

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-agw-{environment}
var autoName = '${workloadName}-agw-${environment}'
var appGatewayName = empty(name) ? autoName : name
var publicIpName = '${workloadName}-pip-agw-${environment}'
var identityName = '${workloadName}-id-agw-${environment}'
var wafPolicyName = '${workloadName}-waf-${environment}'

// The vault may live outside the gateway's own resource group / subscription,
// so subscription, resource group and name are taken apart from its resource ID:
// /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}
// The placeholder keeps the indices valid when no vault is configured.
var keyVaultIdSegments = split(
  empty(keyVaultId) ? '/subscriptions//resourceGroups//providers/Microsoft.KeyVault/vaults/' : keyVaultId,
  '/'
)
var keyVaultSubscription = keyVaultIdSegments[2]
var keyVaultResourceGroup = keyVaultIdSegments[4]
var keyVaultName = last(keyVaultIdSegments)

// Internal component names of the Application Gateway
var publicFrontendName = 'appGwPublicFrontendIP'
var privateFrontendName = 'appGwPrivateFrontendIP'
var frontendPortHttpName = 'port_80'
var frontendPortHttpsName = 'port_443'
var gatewayIpConfigName = 'appGwGatewayIpConfig'
var backendSettingsName = 'bst-default'
var backendSettingsPathName = 'bst-path'

// Identity: reuse the one supplied, otherwise create a dedicated one whenever a
// vault is configured. The gateway is given an identity in both cases.
var useExistingIdentity = !empty(identityId)
var createIdentity = !empty(keyVaultId) && !useExistingIdentity
var identityEnabled = createIdentity || useExistingIdentity

// Same decomposition as the vault: the identity may live anywhere.
var identityIdSegments = split(
  empty(identityId)
    ? '/subscriptions//resourceGroups//providers/Microsoft.ManagedIdentity/userAssignedIdentities/'
    : identityId,
  '/'
)

var resolvedIdentityId = useExistingIdentity ? identityId : (createIdentity ? userIdentity!.id : '')
var resolvedPrincipalId = useExistingIdentity
  ? existingIdentity!.properties.principalId
  : (createIdentity ? userIdentity!.properties.principalId : '')
var usePrivateFrontend = !empty(privateFrontendIpAddress)
var useSites = !empty(sites)

// --- Frontend ---------------------------------------------------------------

var publicFrontendConfig = {
  name: publicFrontendName
  properties: {
    publicIPAddress: {
      id: publicIp.id
    }
  }
}

var privateFrontendConfig = {
  name: privateFrontendName
  properties: {
    privateIPAddress: privateFrontendIpAddress
    privateIPAllocationMethod: 'Static'
    subnet: {
      id: subnetId
    }
  }
}

var frontendIpConfigurations = usePrivateFrontend
  ? concat([publicFrontendConfig], [privateFrontendConfig])
  : [publicFrontendConfig]

// Both ports are always declared so an HTTPS listener can be wired without
// having to reshape the gateway later.
var frontendPorts = [
  {
    name: frontendPortHttpName
    properties: {
      port: 80
    }
  }
  {
    name: frontendPortHttpsName
    properties: {
      port: 443
    }
  }
]

// --- Collections generated from `sites` -------------------------------------

// One pool for the site itself, plus one per path rule.
var siteDefaultPools = [
  for site in sites: {
    name: 'pool-${site.key}'
    properties: {
      backendAddresses: [
        {
          fqdn: site.defaultFqdn
        }
      ]
    }
  }
]

// map() rather than a nested for-expression: Bicep only allows for-expressions
// as the direct value of a declaration or resource property.
var sitePathPools = [
  for site in sites: map(site.?pathRules ?? [], rule => {
    name: 'pool-${site.key}-${rule.name}'
    properties: {
      backendAddresses: [
        {
          fqdn: rule.fqdn
        }
      ]
    }
  })
]

var generatedBackendAddressPools = concat(siteDefaultPools, flatten(sitePathPools))

// Backends are HTTPS with the host taken from the backend address, which is what
// Container Apps and App Service expect. The `-path` variant rewrites the path to
// root, so a listener prefix such as /api is not forwarded to the backend.
var generatedBackendHttpSettings = [
  {
    name: backendSettingsName
    properties: {
      port: 443
      protocol: 'Https'
      cookieBasedAffinity: 'Disabled'
      pickHostNameFromBackendAddress: true
      requestTimeout: backendRequestTimeout
    }
  }
  {
    name: backendSettingsPathName
    properties: {
      port: 443
      protocol: 'Https'
      cookieBasedAffinity: 'Disabled'
      pickHostNameFromBackendAddress: true
      path: '/'
      requestTimeout: backendRequestTimeout
    }
  }
]

var generatedHttpListeners = [
  for site in sites: {
    name: 'lst-${site.key}'
    properties: {
      frontendIPConfiguration: {
        id: resourceId(
          'Microsoft.Network/applicationGateways/frontendIPConfigurations',
          appGatewayName,
          (site.?usePrivateFrontend ?? false) ? privateFrontendName : publicFrontendName
        )
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, frontendPortHttpsName)
      }
      protocol: 'Https'
      hostName: site.hostName
      requireServerNameIndication: true
      sslCertificate: {
        id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, certificateName)
      }
    }
  }
]

// A URL path map with an empty pathRules collection is rejected by ARM, so only
// sites that actually declare path rules get one.
var sitesWithPathRules = filter(sites, site => !empty(site.?pathRules ?? []))

var generatedUrlPathMaps = [
  for site in sitesWithPathRules: {
    name: 'map-${site.key}'
    properties: {
      defaultBackendAddressPool: {
        id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'pool-${site.key}')
      }
      defaultBackendHttpSettings: {
        id: resourceId(
          'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
          appGatewayName,
          backendSettingsName
        )
      }
      pathRules: map(site.pathRules, rule => {
        name: rule.name
        properties: {
          paths: rule.paths
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendAddressPools',
              appGatewayName,
              'pool-${site.key}-${rule.name}'
            )
          }
          backendHttpSettings: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
              appGatewayName,
              (rule.?stripPath ?? true) ? backendSettingsPathName : backendSettingsName
            )
          }
        }
      })
    }
  }
]

var generatedRequestRoutingRules = [
  for site in sites: empty(site.?pathRules ?? [])
    ? {
        name: 'rule-${site.key}'
        properties: {
          ruleType: 'Basic'
          priority: site.priority
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'lst-${site.key}')
          }
          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendAddressPools',
              appGatewayName,
              'pool-${site.key}'
            )
          }
          backendHttpSettings: {
            id: resourceId(
              'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
              appGatewayName,
              backendSettingsName
            )
          }
        }
      }
    : {
        name: 'rule-${site.key}'
        properties: {
          ruleType: 'PathBasedRouting'
          priority: site.priority
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'lst-${site.key}')
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps', appGatewayName, 'map-${site.key}')
          }
        }
      }
]

// --- Fallback collections (no sites and no explicit arrays) ------------------

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
        id: resourceId(
          'Microsoft.Network/applicationGateways/frontendIPConfigurations',
          appGatewayName,
          publicFrontendName
        )
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
        id: resourceId(
          'Microsoft.Network/applicationGateways/backendAddressPools',
          appGatewayName,
          'defaultBackendPool'
        )
      }
      backendHttpSettings: {
        id: resourceId(
          'Microsoft.Network/applicationGateways/backendHttpSettingsCollection',
          appGatewayName,
          'defaultHttpSettings'
        )
      }
    }
  }
]

// Resolution: explicit arrays win, then the sites expansion, then the defaults.
var resolvedBackendAddressPools = !empty(backendAddressPools)
  ? backendAddressPools
  : (useSites ? generatedBackendAddressPools : defaultBackendAddressPools)

var resolvedBackendHttpSettings = !empty(backendHttpSettings)
  ? backendHttpSettings
  : (useSites ? generatedBackendHttpSettings : defaultBackendHttpSettings)

var resolvedHttpListeners = !empty(httpListeners)
  ? httpListeners
  : (useSites ? generatedHttpListeners : defaultHttpListeners)

var resolvedRequestRoutingRules = !empty(requestRoutingRules)
  ? requestRoutingRules
  : (useSites ? generatedRequestRoutingRules : defaultRequestRoutingRules)

var resolvedUrlPathMaps = !empty(urlPathMaps) ? urlPathMaps : (useSites ? generatedUrlPathMaps : [])

// --- SKU --------------------------------------------------------------------

var skuProperties = enableAutoScale
  ? {
      name: skuName
      tier: skuTier
      family: 'Generation_2'
    }
  : {
      name: skuName
      tier: skuTier
      family: 'Generation_2'
      capacity: capacity
    }

var autoScaleConfig = enableAutoScale
  ? {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
  : null

// --- TLS certificates -------------------------------------------------------

// Versionless secret URI so certificate rotation in Key Vault is picked up.
var keyVaultCertificates = !empty(keyVaultId) && !empty(certificateSecretName)
  ? [
      {
        name: certificateName
        properties: {
          keyVaultSecretId: '${keyVault!.properties.vaultUri}secrets/${certificateSecretName}'
        }
      }
    ]
  : []

var explicitCertificates = [
  for cert in sslCertificates: {
    name: cert.name
    properties: {
      keyVaultSecretId: cert.keyVaultSecretId
    }
  }
]

var resolvedSslCertificates = concat(keyVaultCertificates, explicitCertificates)

// =============================================================================
// Existing resources (name-based lookups)
// =============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = if (!empty(keyVaultId)) {
  name: keyVaultName
  scope: resourceGroup(keyVaultSubscription, keyVaultResourceGroup)
}

resource existingIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = if (useExistingIdentity) {
  name: last(identityIdSegments)
  scope: resourceGroup(identityIdSegments[2], identityIdSegments[4])
}

// =============================================================================
// Resources
// =============================================================================

// Public IP for the Application Gateway frontend
resource publicIp 'Microsoft.Network/publicIPAddresses@2025-07-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  zones: !empty(zones) ? zones : null
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

// Certificate read access on the vault. This is the piece the portal flow leaves
// out on an RBAC-enabled Key Vault, and without it the gateway PUT fails.
// A separate module because a role assignment must be deployed at the scope of
// its target, and the vault may sit in another resource group or subscription.
module keyVaultAccess 'keyvault-access.bicep' = if (identityEnabled && !empty(keyVaultId) && grantKeyVaultAccess) {
  name: 'grant-kv-access-${appGatewayName}'
  scope: resourceGroup(keyVaultSubscription, keyVaultResourceGroup)
  params: {
    keyVaultName: keyVaultName
    principalId: resolvedPrincipalId
  }
}

// Conditional WAF policy
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2025-07-01' = if (enableWafPolicy && skuName == 'WAF_v2') {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      requestBodyCheck: true
      requestBodyEnforcement: true
      requestBodyInspectLimitInKB: 128
      maxRequestBodySizeInKb: 128
      fileUploadEnforcement: true
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: wafMode
    }
    managedRules: {
      managedRuleSets: wafRuleSets
    }
  }
}

// Application Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2025-07-01' = {
  name: appGatewayName
  location: location
  tags: tags
  zones: !empty(zones) ? zones : null
  identity: identityEnabled
    ? {
        type: 'UserAssigned'
        userAssignedIdentities: {
          '${resolvedIdentityId}': {}
        }
      }
    : null
  properties: {
    sku: skuProperties
    autoscaleConfiguration: autoScaleConfig
    enableHttp2: enableHttp2
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
    frontendIPConfigurations: frontendIpConfigurations
    frontendPorts: frontendPorts
    sslCertificates: resolvedSslCertificates
    backendAddressPools: resolvedBackendAddressPools
    backendHttpSettingsCollection: resolvedBackendHttpSettings
    httpListeners: resolvedHttpListeners
    urlPathMaps: resolvedUrlPathMaps
    requestRoutingRules: resolvedRequestRoutingRules
    firewallPolicy: enableWafPolicy && skuName == 'WAF_v2'
      ? {
          id: wafPolicy.id
        }
      : null
  }
  dependsOn: identityEnabled && !empty(keyVaultId) && grantKeyVaultAccess ? [keyVaultAccess] : []
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

@description('Private frontend IP address of the Application Gateway, when configured.')
output privateIpAddress string = privateFrontendIpAddress

@description('Resource ID of the managed identity attached to the gateway, created or reused.')
output identityId string = resolvedIdentityId

@description('Principal ID of the managed identity attached to the gateway, used for Key Vault access.')
output identityPrincipalId string = resolvedPrincipalId

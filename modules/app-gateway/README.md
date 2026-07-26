# Application Gateway

Bicep module for provisioning an Application Gateway with WAF, managed identity, Key Vault TLS certificates, host- and path-based routing, and diagnostics following a configurable naming convention (`{workloadName}-agw-{environment}`). Automatically creates a public IP (`{workloadName}-pip-agw-{environment}`), a user-assigned managed identity for Key Vault access (`{workloadName}-id-agw-{environment}`), and a conditional WAF policy (`{workloadName}-waf-{environment}`).

Frontend ports 80 and 443 are always declared, so an HTTPS listener can be wired without reshaping the gateway later.

## Naming Convention

Resource names are automatically generated based on the `workloadName` and `environment` parameters:

| Resource | Pattern |
|---|---|
| Application Gateway | `{workloadName}-agw-{environment}` |
| Public IP | `{workloadName}-pip-agw-{environment}` |
| Managed Identity | `{workloadName}-id-agw-{environment}` |
| WAF Policy | `{workloadName}-waf-{environment}` |

Override: use the `name` parameter to define a fully custom name for the Application Gateway, ignoring the automatic convention. Secondary resources (IP, identity, WAF) continue using the automatic convention.

## Routing

Routing can be declared at two levels:

- **High level** — the `sites` array expands into an HTTPS listener, backend pools, an optional URL path map and a routing rule per fronted host. A site without `pathRules` produces a `Basic` rule straight to its default pool; a site with them produces a `PathBasedRouting` rule.
- **Low level** — `httpListeners`, `backendAddressPools`, `backendHttpSettings`, `requestRoutingRules` and `urlPathMaps` are passed through verbatim and take precedence over `sites`.

With neither, a plain HTTP listener on port 80 is created.

The backend settings generated from `sites` target HTTPS/443 with the host taken from the backend address. Path rules default to `stripPath: true`, which rewrites the backend path to root so a listener prefix such as `/api` is not forwarded downstream — set it to `false` to preserve the full path.

## Usage

```bicep
// Simple HTTP gateway (no TLS, default listener on port 80)
module appGateway 'modules/app-gateway/main.bicep' = {
  name: 'deploy-app-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    subnetId: subnetAppGw.outputs.id
    skuName: 'Standard_v2'
    skuTier: 'Standard_v2'
    enableWafPolicy: false
  }
}

// HTTPS gateway with a Key Vault certificate and path-based routing
module appGatewayHttps 'modules/app-gateway/main.bicep' = {
  name: 'deploy-app-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'prod'
    location: 'brazilsouth'
    subnetId: subnetAppGw.outputs.id
    zones: ['1', '2', '3']
    enableAutoScale: true
    minCapacity: 0
    maxCapacity: 2
    wafMode: 'Detection'
    keyVaultId: keyVault.outputs.id
    certificateSecretName: 'wildcard-mycompany'
    privateFrontendIpAddress: '10.0.2.20'
    sites: [
      {
        key: 'prod'
        hostName: 'app.mycompany.com'
        priority: 1
        defaultFqdn: 'web-prod.internal.example.brazilsouth.azurecontainerapps.io'
        pathRules: [
          {
            name: 'api'
            paths: ['/api*']
            fqdn: 'api-prod.internal.example.brazilsouth.azurecontainerapps.io'
          }
        ]
      }
    ]
  }
}
```

> **Note.** The module grants the generated identity the built-in **Key Vault Secrets User** role on the vault and makes the gateway depend on the assignment — this is the step the portal flow omits on an RBAC-enabled vault, and without it the gateway deployment fails. The vault's subscription and resource group are taken from `keyVaultId`, so it may live anywhere; the assignment is emitted as a nested deployment at the vault's own scope (`keyvault-access.bicep`). The certificate must be stored as an exportable secret, and the vault firewall must permit the gateway. The secret is referenced **without a version**, so rotation in Key Vault is picked up automatically.
>
> Creating the assignment requires `Microsoft.Authorization/roleAssignments/write`, which **Contributor does not have**. Either give the deploying identity a role that can write assignments on the vault's scope, or set `grantKeyVaultAccess: false` and grant the access out of band.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention for the Application Gateway. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'WAF_v2'` | Application Gateway SKU name. Allowed values: `Standard_v2`, `WAF_v2`. |
| `skuTier` | `string` | `'WAF_v2'` | Application Gateway SKU tier. Allowed values: `Standard_v2`, `WAF_v2`. |
| `capacity` | `int` | `2` | Fixed capacity (number of instances). Used when `enableAutoScale` is `false`. |
| `subnetId` | `string` | *(required)* | ID of the subnet dedicated to the Application Gateway. |
| `enableAutoScale` | `bool` | `false` | Enables auto scaling for the Application Gateway. |
| `minCapacity` | `int` | `1` | Minimum capacity when auto scaling is enabled. Accepts `0` to scale down to no reserved instances. |
| `maxCapacity` | `int` | `10` | Maximum capacity when auto scaling is enabled. |
| `zones` | `array` | `[]` | Availability zones for the gateway and its public IP. Leave empty for a non-zonal deployment. |
| `enableHttp2` | `bool` | `true` | Enables HTTP/2 on the Application Gateway frontend. |
| `privateFrontendIpAddress` | `string` | `''` | Static private frontend IP address. Must fall inside the gateway subnet. Leave empty for a public-only gateway. |
| `enableWafPolicy` | `bool` | `true` | Enables the WAF policy on the Application Gateway. Applied only when `skuName` is `WAF_v2`. |
| `wafMode` | `string` | `'Prevention'` | WAF operating mode. Allowed values: `Detection`, `Prevention`. |
| `wafRuleSets` | `array` | OWASP `3.2` + `Microsoft_BotManagerRuleSet` `0.1` | Managed rule sets applied by the WAF policy. Each object must contain `ruleSetType` and `ruleSetVersion`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for diagnostics. Required when `enableDiagnostics` is `true`. |
| `keyVaultId` | `string` | `''` | Resource ID of an existing Key Vault holding the TLS certificate. When provided, creates a user-assigned managed identity and grants it Key Vault Secrets User on the vault. The vault may live in any resource group or subscription. |
| `grantKeyVaultAccess` | `bool` | `true` | Grants the gateway identity Key Vault Secrets User on the vault. Disable when the deploying identity cannot write role assignments, and grant the access separately. |
| `certificateSecretName` | `string` | `''` | Name of the Key Vault secret holding the TLS certificate. Referenced without a version so rotation is picked up automatically. |
| `certificateName` | `string` | `'tls-cert'` | Internal name of the SSL certificate inside the gateway. Referenced by the listeners generated from `sites`. |
| `sites` | `array` | `[]` | Routed sites. Each object: `{ key, hostName, priority, defaultFqdn, usePrivateFrontend?, pathRules?: [{ name, paths, fqdn, stripPath? }] }`. |
| `backendRequestTimeout` | `int` | `60` | Request timeout, in seconds, of the backend settings generated from `sites`. |
| `sslCertificates` | `array` | `[]` | List of SSL certificates from Key Vault. Each object must contain `name` and `keyVaultSecretId`. Appended to the certificate generated from `certificateSecretName`. |
| `httpListeners` | `array` | `[]` | List of HTTP listeners. Overrides the listeners generated from `sites`. If both are empty, a default listener on port 80 will be created. |
| `backendAddressPools` | `array` | `[]` | List of backend address pools. Overrides the pools generated from `sites`. If both are empty, a default empty pool will be created. |
| `backendHttpSettings` | `array` | `[]` | List of backend HTTP settings. Overrides the settings generated from `sites`. If both are empty, a default setting on port 80 will be created. |
| `requestRoutingRules` | `array` | `[]` | List of request routing rules. Overrides the rules generated from `sites`. If both are empty, a default rule will be created. |
| `urlPathMaps` | `array` | `[]` | List of URL path maps. Overrides the path maps generated from `sites`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Application Gateway. |
| `name` | `string` | Name of the created Application Gateway. |
| `publicIpAddress` | `string` | Public IP address of the Application Gateway. |
| `privateIpAddress` | `string` | Private frontend IP address of the Application Gateway, when configured. |
| `identityPrincipalId` | `string` | Principal ID of the user-assigned managed identity, used for Key Vault access. |

## Changes in 2.0.0

The parameter surface is backwards compatible — nothing was removed — but the deployed shape changes:

- Frontend port **443** is now always declared, alongside 80. This is what makes an HTTPS listener possible.
- The SKU sets `family: 'Generation_2'` and `enableHttp2` defaults to `true`.
- `keyVaultId` now also drives a **Key Vault Secrets User** role assignment for the generated identity; previously it only created the identity.
- The default `wafRuleSets` adds `Microsoft_BotManagerRuleSet` `0.1` to OWASP `3.2`, and the WAF policy sets the newer enforcement properties. Pass `wafRuleSets` explicitly to keep the previous rule set.

Existing deployments are updated in place.

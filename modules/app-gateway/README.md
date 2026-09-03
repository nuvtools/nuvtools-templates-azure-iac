# Application Gateway

Bicep module for provisioning an Application Gateway with WAF, managed identity, Key Vault TLS certificates, host- and path-based routing, and diagnostics following a configurable naming convention (`{workloadName}-agw-{environment}`). Automatically creates a public IP (`{workloadName}-agw-pip-{environment}`), a user-assigned managed identity for Key Vault access (`{workloadName}-agw-id-{environment}`), and a conditional WAF policy (`{workloadName}-agw-waf-{environment}`).

Frontend ports 80 and 443 are always declared, so an HTTPS listener can be wired without reshaping the gateway later.

## Naming Convention

Resource names are automatically generated based on the `workloadName` and `environment` parameters:

| Resource | Pattern |
|---|---|
| Application Gateway | `{workloadName}-agw-{environment}` |
| Public IP | `{workloadName}-agw-pip-{environment}` |
| Managed Identity | `{workloadName}-agw-id-{environment}` (only when `identityId` is empty) |
| WAF Policy | `{workloadName}-agw-waf-{environment}` |

Override: use the `name` parameter to define a fully custom name for the Application Gateway, ignoring the automatic convention. Secondary resources (IP, identity, WAF) continue using the automatic convention.

## Routing

Routing can be declared at two levels:

- **High level** — the `sites` array expands into an HTTPS listener, backend pools, an optional URL path map and a routing rule per fronted host. A site without `pathRules` produces a `Basic` rule straight to its default pool; a site with them produces a `PathBasedRouting` rule.
- **Low level** — `httpListeners`, `backendAddressPools`, `backendHttpSettings`, `requestRoutingRules`, `urlPathMaps` and `probes` are passed through verbatim and take precedence over `sites`.

With neither, a plain HTTP listener on port 80 is created.

The backend settings generated from `sites` target HTTPS/443 with the host taken from the backend address. Path rules default to `stripPath: true`, which rewrites the backend path to root so a listener prefix such as `/api` is not forwarded downstream — set it to `false` to preserve the full path.

## Health probes

`sites` also generates a health probe per generated backend setting (`probe-default`, `probe-path`), because the implicit probe Application Gateway falls back on is not usable against a modern PaaS backend: it sends `Host: 127.0.0.1`, which Container Apps and App Service ingress do not recognise, so every backend answers **404** and the pool is reported *Unhealthy* even though it is serving traffic normally.

The generated probes set `pickHostNameFromBackendHttpSettings`, which chains onto the `pickHostNameFromBackendAddress` of the settings, so each probe is sent with the Host header and SNI of the pool member it is checking. They request `healthProbePath` (default `/`) and accept `healthProbeMatchStatusCodes` (default `200-399`).

`healthProbePath` applies to every generated backend, so it has to be a path all of them answer. Backends that need different health paths must be declared with the low-level `backendHttpSettings` + `probes` arrays instead — supplying `backendHttpSettings` drops the generated probes rather than leaving them unreferenced.

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
| `publicIpDomainNameLabel` | `string` | `''` | DNS name label on the gateway's public IP, giving it a stable `<label>.<region>.cloudapp.azure.com` FQDN. Set it whenever a public DNS record CNAMEs to the gateway: the label is a property of the public IP, so leaving this empty strips a label applied out of band on the next deploy and the CNAME chain resolves to NXDOMAIN. Must be unique within the region. |
| `privateFrontendIpAddress` | `string` | `''` | Static private frontend IP address. Must fall inside the gateway subnet. Leave empty for a public-only gateway. |
| `enableWafPolicy` | `bool` | `true` | Enables the WAF policy on the Application Gateway. Applied only when `skuName` is `WAF_v2`. |
| `wafMode` | `string` | `'Prevention'` | WAF operating mode. Allowed values: `Detection`, `Prevention`. |
| `wafRuleSets` | `array` | OWASP `3.2` + `Microsoft_BotManagerRuleSet` `0.1` | Managed rule sets applied by the WAF policy. Each object must contain `ruleSetType` and `ruleSetVersion`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for diagnostics. Required when `enableDiagnostics` is `true`. |
| `keyVaultId` | `string` | `''` | Resource ID of an existing Key Vault holding the TLS certificate. When provided, the gateway gets an identity granted Key Vault Secrets User on the vault. The vault may live in any resource group or subscription. |
| `identityId` | `string` | `''` | Resource ID of an existing user-assigned managed identity to attach. When empty, the module creates its own. Reuse a shared platform identity to grant vault access once instead of per gateway. |
| `grantKeyVaultAccess` | `bool` | `true` | Grants the gateway identity Key Vault Secrets User on the vault. Disable when the deploying identity cannot write role assignments, and grant the access separately. |
| `certificateSecretName` | `string` | `''` | Name of the Key Vault secret holding the TLS certificate. Referenced without a version so rotation is picked up automatically. |
| `certificateName` | `string` | `'tls-cert'` | Internal name of the SSL certificate inside the gateway. Referenced by the listeners generated from `sites`. |
| `sites` | `array` | `[]` | Routed sites. Each object: `{ key, hostName, priority, defaultFqdn, usePrivateFrontend?, pathRules?: [{ name, paths, fqdn, stripPath? }] }`. |
| `backendRequestTimeout` | `int` | `60` | Request timeout, in seconds, of the backend settings generated from `sites`. |
| `healthProbePath` | `string` | `'/'` | Path requested by the health probes generated from `sites`. Applies to every generated backend. |
| `healthProbeMatchStatusCodes` | `array` | `['200-399']` | Status codes the generated health probes accept as healthy. |
| `sslCertificates` | `array` | `[]` | List of SSL certificates from Key Vault. Each object must contain `name` and `keyVaultSecretId`. Appended to the certificate generated from `certificateSecretName`. |
| `httpListeners` | `array` | `[]` | List of HTTP listeners. Overrides the listeners generated from `sites`. If both are empty, a default listener on port 80 will be created. |
| `backendAddressPools` | `array` | `[]` | List of backend address pools. Overrides the pools generated from `sites`. If both are empty, a default empty pool will be created. |
| `backendHttpSettings` | `array` | `[]` | List of backend HTTP settings. Overrides the settings generated from `sites`. If both are empty, a default setting on port 80 will be created. |
| `requestRoutingRules` | `array` | `[]` | List of request routing rules. Overrides the rules generated from `sites`. If both are empty, a default rule will be created. |
| `urlPathMaps` | `array` | `[]` | List of URL path maps. Overrides the path maps generated from `sites`. |
| `probes` | `array` | `[]` | List of health probes. Overrides the probes generated from `sites`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Application Gateway. |
| `name` | `string` | Name of the created Application Gateway. |
| `publicIpAddress` | `string` | Public IP address of the Application Gateway. |
| `privateIpAddress` | `string` | Private frontend IP address of the Application Gateway, when configured. |
| `identityId` | `string` | Resource ID of the managed identity attached to the gateway, created or reused. |
| `identityPrincipalId` | `string` | Principal ID of the managed identity attached to the gateway, used for Key Vault access. |

## Changes in 2.1.0

- `sites` now also generates health probes (`probe-default`, `probe-path`) and attaches them to the generated backend settings. Without them the gateway falls back to its implicit probe, which sends `Host: 127.0.0.1` and is answered with a 404 by Container Apps and App Service ingress — see [Health probes](#health-probes).
- New `healthProbePath`, `healthProbeMatchStatusCodes` and low-level `probes` parameters.

Existing deployments are updated in place: the probes are added and the two generated backend settings start referencing them.

## Changes in 2.0.0

The parameter surface is backwards compatible — nothing was removed — but the deployed shape changes:

- Frontend port **443** is now always declared, alongside 80. This is what makes an HTTPS listener possible.
- The SKU sets `family: 'Generation_2'` and `enableHttp2` defaults to `true`.
- `keyVaultId` now also drives a **Key Vault Secrets User** role assignment for the gateway identity; previously it only created the identity.
- New `identityId` lets the gateway reuse an existing identity instead of creating one. Note that granting the vault role to a *shared* identity gives every resource attached to it the same read access — use a dedicated identity when that matters.
- The default `wafRuleSets` adds `Microsoft_BotManagerRuleSet` `0.1` to OWASP `3.2`, and the WAF policy sets the newer enforcement properties. Pass `wafRuleSets` explicitly to keep the previous rule set.

Existing deployments are updated in place.

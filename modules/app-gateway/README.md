# NuvTools - Application Gateway

Bicep module for provisioning an Application Gateway with WAF, managed identity, SSL certificates, and diagnostics following the NuvTools naming convention (`{prefix}-{workloadName}-agw-{environment}`). Automatically creates a public IP (`{prefix}-{workloadName}-pip-agw-{environment}`), a user-assigned managed identity for Key Vault access (`{prefix}-{workloadName}-id-agw-{environment}`), and a conditional WAF policy (`{prefix}-{workloadName}-waf-{environment}`).

## Naming Convention

Resource names are automatically generated based on the `prefix`, `workloadName`, and `environment` parameters:

| Resource | With prefix | Without prefix |
|---|---|---|
| Application Gateway | `{prefix}-{workloadName}-agw-{environment}` | `{workloadName}-agw-{environment}` |
| Public IP | `{prefix}-{workloadName}-pip-agw-{environment}` | `{workloadName}-pip-agw-{environment}` |
| Managed Identity | `{prefix}-{workloadName}-id-agw-{environment}` | `{workloadName}-id-agw-{environment}` |
| WAF Policy | `{prefix}-{workloadName}-waf-{environment}` | `{workloadName}-waf-{environment}` |

Override: use the `name` parameter to define a fully custom name for the Application Gateway, ignoring the automatic convention. Secondary resources (IP, identity, WAF) continue using the automatic convention.

## Usage

```bicep
module appGateway 'modules/app-gateway/main.bicep' = {
  name: 'deploy-app-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    subnetId: subnetAppGw.outputs.id
    skuName: 'WAF_v2'
    skuTier: 'WAF_v2'
    enableWafPolicy: true
    wafMode: 'Prevention'
    keyVaultId: keyVault.outputs.id
    sslCertificates: [
      {
        name: 'wildcard-cert'
        keyVaultSecretId: certificate.outputs.secretId
      }
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention for the Application Gateway. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'WAF_v2'` | Application Gateway SKU name. Allowed values: `Standard_v2`, `WAF_v2`. |
| `skuTier` | `string` | `'WAF_v2'` | Application Gateway SKU tier. Allowed values: `Standard_v2`, `WAF_v2`. |
| `capacity` | `int` | `2` | Fixed capacity (number of instances). Used when `enableAutoScale` is `false`. |
| `subnetId` | `string` | *(required)* | ID of the subnet dedicated to the Application Gateway. |
| `enableAutoScale` | `bool` | `false` | Enables auto scaling for the Application Gateway. |
| `minCapacity` | `int` | `1` | Minimum capacity when auto scaling is enabled. |
| `maxCapacity` | `int` | `10` | Maximum capacity when auto scaling is enabled. |
| `enableWafPolicy` | `bool` | `true` | Enables the WAF policy on the Application Gateway. |
| `wafMode` | `string` | `'Prevention'` | WAF operating mode. Allowed values: `Detection`, `Prevention`. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for diagnostics. Required when `enableDiagnostics` is `true`. |
| `keyVaultId` | `string` | `''` | Key Vault ID for SSL certificate access. When provided, creates a user-assigned managed identity with access. |
| `sslCertificates` | `array` | `[]` | List of SSL certificates from Key Vault. Each object must contain `name` and `keyVaultSecretId`. |
| `httpListeners` | `array` | `[]` | List of HTTP listeners. If empty, a default listener on port 80 will be created. |
| `backendAddressPools` | `array` | `[]` | List of backend address pools. If empty, a default empty pool will be created. |
| `backendHttpSettings` | `array` | `[]` | List of backend HTTP settings. If empty, a default setting on port 80 will be created. |
| `requestRoutingRules` | `array` | `[]` | List of request routing rules. If empty, a default rule will be created. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Application Gateway. |
| `name` | `string` | Name of the created Application Gateway. |
| `publicIpAddress` | `string` | Public IP address of the Application Gateway. |
| `identityPrincipalId` | `string` | Principal ID of the user-assigned managed identity, used for Key Vault access. |

# NuvTools - Key Vault

Bicep module for provisioning a Key Vault with RBAC, soft delete, network rules, and diagnostics following the NuvTools naming convention (`{prefix}-{workloadName}-kv-{environment}`). Supports RBAC-based authorization, purge protection, subnet and IP range access rules, and sending diagnostics to Log Analytics.

## Naming Convention

The resource name is automatically generated based on the `prefix`, `workloadName`, and `environment` parameters:

- With prefix: `{prefix}-{workloadName}-kv-{environment}` (e.g., `nvt-myapp-kv-dev`)
- Without prefix: `{workloadName}-kv-{environment}` (e.g., `myapp-kv-dev`)
- Override: use the `name` parameter to define a fully custom name, ignoring the automatic convention.

## Usage

```bicep
module keyVault 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    skuName: 'standard'
    networkDefaultAction: 'Deny'
    allowedSubnetIds: [
      subnet.outputs.id
    ]
    allowedIpRanges: [
      '203.0.113.0/24'
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'standard'` | Key Vault SKU. Allowed values: `standard`, `premium`. |
| `enableRbacAuthorization` | `bool` | `true` | Enables RBAC-based authorization instead of access policies. |
| `enableSoftDelete` | `bool` | `true` | Enables soft delete for protection against accidental deletion. |
| `softDeleteRetentionInDays` | `int` | `90` | Soft delete retention period in days. |
| `enablePurgeProtection` | `bool` | `true` | Enables purge protection. Prevents permanent deletion during the retention period. |
| `networkDefaultAction` | `string` | `'Deny'` | Default network rule action. Allowed values: `Allow`, `Deny`. |
| `allowedSubnetIds` | `array` | `[]` | List of allowed subnet IDs for Key Vault access via service endpoints. |
| `allowedIpRanges` | `array` | `[]` | List of allowed IP ranges for Key Vault access (CIDR format or single IP). |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Key Vault. |
| `name` | `string` | Name of the created Key Vault. |
| `vaultUri` | `string` | Key Vault URI for accessing secrets, keys, and certificates. |

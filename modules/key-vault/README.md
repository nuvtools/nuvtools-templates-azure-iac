# Key Vault

Bicep module for provisioning a Key Vault with RBAC, soft delete, network rules, and diagnostics following a configurable naming convention (`{workloadName}-kv-{environment}`). Supports RBAC-based authorization, purge protection, subnet and IP range access rules, data plane read role assignments scoped to the vault, and sending diagnostics to Log Analytics.

## Naming Convention

The resource name is automatically generated based on the `workloadName` and `environment` parameters:

- Pattern: `{workloadName}-kv-{environment}` (e.g., `myapp-kv-dev`)
- Override: use the `name` parameter to define a fully custom name, ignoring the automatic convention.

## Usage

```bicep
module keyVault 'modules/key-vault/main.bicep' = {
  name: 'deploy-key-vault'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    skuName: 'standard'
    networkDefaultAction: 'Deny'
    allowedSubnetIds: [
      subnet.outputs.id
    ]
    allowedIpRanges: [
      '203.0.113.0/24'
    ]
    secretsUserPrincipalIds: [
      managedIdentity.outputs.principalId
    ]
    certificateUserPrincipalIds: [
      managedIdentity.outputs.principalId
    ]
  }
}
```

## Role Assignments

`secretsUserPrincipalIds` and `certificateUserPrincipalIds` grant the built-in **Key Vault Secrets User** (`4633458b-17de-408a-b874-0445c86b69e6`) and **Key Vault Certificate User** (`db79e9a7-68ee-4b58-9aeb-b90e7c24fcba`) roles, scoped to the vault itself rather than to the resource group. Both are read-only data plane roles and only take effect while `enableRbacAuthorization` is `true`.

Writing role assignments requires `Microsoft.Authorization/roleAssignments/write`, which **Contributor does not have** — the deploying principal needs a role such as *Role Based Access Control Administrator* on the target scope.

The Secrets User assignment name matches the one produced by `modules/app-gateway/keyvault-access.bicep`, so granting the same principal from both modules is idempotent.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
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
| `secretsUserPrincipalIds` | `array` | `[]` | Principal IDs that receive the Key Vault Secrets User role on the vault. |
| `certificateUserPrincipalIds` | `array` | `[]` | Principal IDs that receive the Key Vault Certificate User role on the vault. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Key Vault. |
| `name` | `string` | Name of the created Key Vault. |
| `vaultUri` | `string` | Key Vault URI for accessing secrets, keys, and certificates. |

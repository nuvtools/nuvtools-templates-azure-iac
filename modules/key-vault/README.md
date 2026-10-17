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

## Purge Protection

Key Vault rejects an **explicit** `enablePurgeProtection: false` — including on creation —
with `BadRequest: The property "enablePurgeProtection" cannot be set to false. Enabling the
purge protection for a vault is an irreversible action.` The API accepts only `true` or the
property being absent.

The module therefore emits `enablePurgeProtection ? true : null`, and ARM drops the null, so
`enablePurgeProtection: false` means "leave purge protection off" rather than failing the
deployment. Going from `false` to `true` works; the reverse never does.

## Role Assignments

`secretsUserPrincipalIds` and `certificateUserPrincipalIds` grant the built-in **Key Vault Secrets User** (`4633458b-17de-408a-b874-0445c86b69e6`) and **Key Vault Certificate User** (`db79e9a7-68ee-4b58-9aeb-b90e7c24fcba`) roles, scoped to the vault itself rather than to the resource group. Both are read-only data plane roles and only take effect while `enableRbacAuthorization` is `true`.

Writing role assignments requires `Microsoft.Authorization/roleAssignments/write`, which **Contributor does not have** — the deploying principal needs a role such as *Role Based Access Control Administrator* on the target scope.

The Secrets User assignment name matches the one produced by `modules/app-gateway/keyvault-access.bicep`, so granting the same principal from both modules is idempotent.

## Keys

`keys` declares key material the vault is created holding, so the key an application signs with is
part of the same deployment as the identity allowed to use it — the two are useless apart, and a key
created by hand is one nothing records the existence of.

```bicep
keys: [
  {
    name: 'gateway-backend-signing'
    kty: 'EC'
    curveName: 'P-256'
    keyOps: ['sign', 'verify']
  }
]
```

The private half never leaves the vault: an application is granted **Key Vault Crypto User** and asks
the vault to sign, rather than being handed material it would then have to protect.

ARM creates a key it does not find and never makes a new version of one it finds, so a redeploy
cannot rotate a key and invalidate the signatures already issued with it. It is not a silent no-op:
when a declared parameter differs from the key's **current version**, the deploy fails with
`KeyCreationParametersDidNotMatchExistingKey`. Declare only what a key keeps for its whole life —
`kty`, `keySize`, `curveName`, `keyOps` — and never an expiry: a rotated key's current version has a
new one every time.

A key can also be created with a **rotation policy**, so the vault makes new versions on its own, each
with the expiry the policy gives it. A token signing key that rotates every 90 days and keeps each
version for 180 (the action types in the casing the vault stores):

```bicep
keys: [
  {
    name: 'token-signing'
    kty: 'RSA'
    keySize: 2048
    keyOps: ['sign', 'verify']
    rotationPolicy: {
      lifetimeActions: [ { trigger: { timeAfterCreate: 'P90D' }, action: { type: 'Rotate' } } ]
      attributes: { expiryTime: 'P180D' }
    }
  }
]
```

The first version has no expiry: disable it in the vault once the first rotation has happened. To
change the policy of an existing key, change it in the vault (`az keyvault key rotation-policy
update`) and here alike.

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
| `enablePurgeProtection` | `bool` | `false` | Prevents permanent deletion during the retention period. **Irreversible** — the API rejects an explicit `false` even on an existing vault, so when `false` the property is omitted rather than sent. Its practical cost: deleting the vault reserves its **name** for the whole retention window, so it cannot be recreated under the same name in another region or subscription. |
| `networkDefaultAction` | `string` | `'Deny'` | Default network rule action. Allowed values: `Allow`, `Deny`. |
| `allowedSubnetIds` | `array` | `[]` | List of allowed subnet IDs for Key Vault access via service endpoints. |
| `allowedIpRanges` | `array` | `[]` | List of allowed IP ranges for Key Vault access (CIDR format or single IP). |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for diagnostics. Required when `enableDiagnostics` is `true`. |
| `diagnosticLogCategoryGroups` | `array` | `['audit', 'allLogs']` | Log category groups sent when `enableDiagnostics` is `true`. `['audit']` sends the audit trail only. |
| `diagnosticMetricsEnabled` | `bool` | `true` | Also sends `AllMetrics` when `enableDiagnostics` is `true`. |
| `secretsUserPrincipalIds` | `array` | `[]` | Principal IDs that receive the Key Vault Secrets User role on the vault. |
| `certificateUserPrincipalIds` | `array` | `[]` | Principal IDs that receive the Key Vault Certificate User role on the vault. |
| `keys` | `array` | `[]` | Keys created in the vault: `{ name, kty, curveName?, keySize?, keyOps?, rotationPolicy? }`. See **Keys** below. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Key Vault. |
| `name` | `string` | Name of the created Key Vault. |
| `vaultUri` | `string` | Key Vault URI for accessing secrets, keys, and certificates. |
| `keyNames` | `array` | Names of the keys created by this module, in declaration order. |

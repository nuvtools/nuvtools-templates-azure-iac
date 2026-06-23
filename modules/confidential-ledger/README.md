# Confidential Ledger

Bicep Module for provisioning an Azure Confidential Ledger (tamper-proof, append-only ledger backed by hardware-based confidential computing) with AAD- and/or certificate-based security principals, following a configurable naming convention (`{workloadName}-acl-{environment}`). The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: myapp-acl-dev (Public ledger, identity granted Administrator)
module ledger 'modules/confidential-ledger/main.bicep' = {
  name: 'deploy-confidential-ledger'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'eastus'
    ledgerType: 'Public'
    aadBasedSecurityPrincipals: [
      {
        principalId: identity.outputs.principalId
        tenantId: tenant().tenantId
        ledgerRoleName: 'Administrator'
      }
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. Confidential Ledger is region-restricted (e.g., `eastus`). |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `ledgerType` | `string` | `'Public'` | Ledger access type. Allowed: `Public`, `Private`. |
| `aadBasedSecurityPrincipals` | `array` | `[]` | AAD-based principals: `{ principalId, tenantId, ledgerRoleName }` (`Administrator`/`Contributor`/`Reader`). |
| `certBasedSecurityPrincipals` | `array` | `[]` | Certificate-based principals: `{ cert, ledgerRoleName }`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Confidential Ledger. |
| `name` | `string` | Name of the created Confidential Ledger. |
| `ledgerUri` | `string` | Public endpoint URI of the ledger. |

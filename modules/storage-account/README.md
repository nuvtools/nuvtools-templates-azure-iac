# NuvTools - Storage Account

Bicep Module for provisioning an Azure Storage Account with optional blob containers, network rules (service endpoints), TLS configuration, and conditional diagnostics, following the NuvTools naming convention (`{prefix}{workloadName}st{environment}`, no hyphens, maximum 24 characters).

## Naming Convention

The resource name is automatically generated based on the `prefix`, `workloadName`, and `environment` parameters. Storage accounts do not allow hyphens and have a 24-character limit:

- With prefix: `{prefix}{workloadName}st{environment}` (e.g., `nvtmyappstdev`)
- Without prefix: `{workloadName}st{environment}` (e.g., `myappstdev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

> **Note:** The automatically generated name is truncated to 24 characters to comply with the Azure limit.

## Usage

```bicep
module storageAccount 'modules/storage-account/main.bicep' = {
  name: 'deploy-storage-account'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    skuName: 'Standard_LRS'
    containers: [
      'documents'
      'images'
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: '/subscriptions/.../workspaces/my-law'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name. Used to compose the resource name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{}` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Standard_LRS'` | Storage account SKU. Allowed values: `Standard_LRS`, `Standard_GRS`, `Standard_RAGRS`, `Standard_ZRS`, `Premium_LRS`, `Premium_ZRS`. |
| `kind` | `string` | `'StorageV2'` | Storage account kind. Allowed values: `StorageV2`, `BlobStorage`, `BlockBlobStorage`, `FileStorage`, `Storage`. |
| `accessTier` | `string` | `'Hot'` | Storage account access tier. Allowed values: `Hot`, `Cool`. |
| `allowBlobPublicAccess` | `bool` | `false` | Allows public access to blobs. |
| `minimumTlsVersion` | `string` | `'TLS1_2'` | Minimum allowed TLS version. Allowed values: `TLS1_0`, `TLS1_1`, `TLS1_2`. |
| `networkDefaultAction` | `string` | `'Deny'` | Default network rule action. Allowed values: `Allow`, `Deny`. |
| `virtualNetworkSubnetIds` | `array` | `[]` | List of subnet IDs allowed for access via service endpoints. |
| `containers` | `array` | `[]` | List of blob container names to be created. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created storage account. |
| `name` | `string` | Name of the created storage account. |
| `primaryBlobEndpoint` | `string` | Primary blob endpoint URL of the storage account. |

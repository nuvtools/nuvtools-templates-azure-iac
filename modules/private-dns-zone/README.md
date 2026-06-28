# Private DNS Zone

Bicep Module for provisioning a Private DNS Zone with optional Virtual Network Links following a configurable convention. The DNS zone name is provided directly by the user via the `zoneName` parameter (e.g., `privatelink.blob.core.windows.net`), since private DNS zones have service-defined names. The private DNS zone is a global resource and supports links to one or more virtual networks, enabling name resolution within the linked VNets.

## Usage

```bicep
module privateDns 'modules/private-dns-zone/main.bicep' = {
  name: 'deploy-private-dns-zone'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    zoneName: 'privatelink.blob.core.windows.net'
    virtualNetworkLinks: [
      {
        name: 'link-vnet-myapp'
        virtualNetworkId: vnet.outputs.id
        registrationEnabled: false
      }
    ]
    // Optional A records, e.g. a wildcard resolving an internal Container Apps
    // environment's default domain to its static IP.
    aRecords: [
      { name: '*', ipv4Address: '10.0.0.4' }
    ]
  }
}
```

> **Note:** This module does not use automatic naming. The resource name is defined directly by the `zoneName` parameter. The `workloadName` and `environment` parameters are kept for interface standardization across modules and tag composition.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Kept for interface standardization across modules. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `zoneName` | `string` | *(required)* | Private DNS zone name. Example: `'privatelink.blob.core.windows.net'`. |
| `virtualNetworkLinks` | `array` | `[]` | List of virtual network links. Each object must contain: `name`, `virtualNetworkId`, and optionally `registrationEnabled` (default `false`). |
| `aRecords` | `array` | `[]` | List of A records. Each object must contain: `name` (`'*'` for wildcard, `'@'` for apex), `ipv4Address`, and optionally `ttl` (seconds, default `3600`). |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created private DNS zone. |
| `name` | `string` | Name of the created private DNS zone. |

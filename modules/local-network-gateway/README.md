# Local Network Gateway

Bicep module for provisioning a **Local Network Gateway** — the on-premises / peer
definition used by a Site-to-Site VPN connection. Follows the naming convention
`{workloadName}-lgw-{environment}`; the `name` parameter overrides it entirely.

## Usage

```bicep
module lng 'modules/local-network-gateway/main.bicep' = {
  name: 'deploy-lng-detran-pr'
  scope: resourceGroup('my-rg')
  params: {
    name: 'detran-pr-lng'
    workloadName: 'hd-common'
    environment: 'hub'
    location: 'brazilsouth'
    gatewayIpAddress: '200.189.112.4'
    addressPrefixes: [
      '200.189.116.201/32'
      '200.189.123.196/32'
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is ignored. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). |
| `environment` | `string` | *(required)* | Deployment environment. |
| `location` | `string` | `'brazilsouth'` | Azure region. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags applied to the resource. |
| `gatewayIpAddress` | `string` | *(required)* | Public IP of the peer VPN device. |
| `addressPrefixes` | `array` | *(required)* | Address prefixes reachable behind the peer. |
| `bgpSettings` | `object` | `{}` | Optional BGP settings (`asn`, `bgpPeeringAddress`). Empty = no BGP. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Local Network Gateway. |
| `name` | `string` | Name of the created Local Network Gateway. |

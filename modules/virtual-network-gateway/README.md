# Virtual Network Gateway (VPN)

Bicep module for provisioning a **route-based VPN gateway** — optionally
active-active, with BGP and a Point-to-Site (P2S) configuration. The public IPs
and the `GatewaySubnet` are passed in **by ID** (referenced, not created here).
Follows the naming convention `{workloadName}-vgw-{environment}`; `name` overrides it.

> A gateway is a long-lived, slow resource (create/update takes 30-45 min and
> interrupts tunnels/P2S). When adopting an existing gateway, deploy only after a
> what-if shows no real change.

## Usage

```bicep
module gateway 'modules/virtual-network-gateway/main.bicep' = {
  name: 'deploy-vpn-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'hd-common'
    environment: 'hub'
    location: 'brazilsouth'
    skuName: 'VpnGw2'
    activeActive: true
    enableBgp: true
    bgpAsn: 65515
    ipConfigurations: [
      { name: 'default',      publicIpId: primaryPipId,   subnetId: gatewaySubnetId }
      { name: 'activeActive', publicIpId: secondaryPipId,  subnetId: gatewaySubnetId }
    ]
    enablePointToSite: true
    pointToSiteAddressPool: ['172.16.100.0/24']
    pointToSiteProtocols: ['OpenVPN']
    pointToSiteAuthTypes: ['AAD']
    aadTenant: '${az.environment().authentication.loginEndpoint}${tenant().tenantId}'
    aadAudience: '<azure-vpn-client-app-id>'
    aadIssuer: 'https://sts.windows.net/${tenant().tenantId}/'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. Overrides the naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). |
| `environment` | `string` | *(required)* | Deployment environment. |
| `location` | `string` | `'brazilsouth'` | Azure region. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags. |
| `skuName` | `string` | `'VpnGw2'` | Gateway SKU (name and tier). |
| `vpnType` | `string` | `'RouteBased'` | `RouteBased` or `PolicyBased`. |
| `vpnGatewayGeneration` | `string` | `'Generation2'` | `Generation1` or `Generation2`. |
| `activeActive` | `bool` | `false` | Active-active mode (needs two IP configs). |
| `enableBgp` | `bool` | `false` | Enable BGP. |
| `bgpAsn` | `int` | `65515` | BGP ASN (used when `enableBgp`). |
| `ipConfigurations` | `array` | *(required)* | `{ name, publicIpId, subnetId }` per instance (+ one for P2S). |
| `enablePointToSite` | `bool` | `false` | Add a Point-to-Site (VPN client) configuration. |
| `pointToSiteAddressPool` | `array` | `[]` | P2S client address prefixes. |
| `pointToSiteProtocols` | `array` | `['OpenVPN']` | P2S tunnel protocols. |
| `pointToSiteAuthTypes` | `array` | `['AAD']` | P2S auth types (AAD / Certificate / Radius). |
| `aadTenant` / `aadAudience` / `aadIssuer` | `string` | `''` | Entra ID (AAD) settings for P2S AAD auth. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Virtual Network Gateway. |
| `name` | `string` | Name of the created Virtual Network Gateway. |

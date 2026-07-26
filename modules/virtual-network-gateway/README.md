# Virtual Network Gateway (VPN)

Bicep module for provisioning a **route-based VPN gateway** — optionally
active-active, with BGP and a Point-to-Site (P2S) configuration.
Follows the naming convention `{workloadName}-vgw-{environment}`; `name` overrides it.
The `GatewaySubnet` is always passed in **by ID** (referenced, never created here).

> A gateway is a long-lived, slow resource (create/update takes 30-45 min and
> interrupts tunnels/P2S). When adopting an existing gateway, deploy only after a
> what-if shows no real change.

## Where the public IPs come from

Two modes, both fully supported. `ipConfigurations` decides which one you get.

| | Bring your own | Managed by the module |
|---|---|---|
| How | pass `ipConfigurations` | leave it empty, pass `gatewaySubnetId` |
| Who owns the address | the caller | this module |
| Names | yours | `{workloadName}-vgw-pip-{environment}`, plus `-vgw-sec-pip-` (active-active) and `-vgw-vpnp2s-pip-` (P2S on active-active) |

**Choose bring-your-own whenever the gateway address is allow-listed in a third
party's firewall** — an IP created alongside the gateway is deleted with it, so a
recreation hands you a different address and silently breaks those integrations.
It is also the only way to adopt a gateway that already exists.

## Usage — bring your own public IPs

```bicep
module gateway 'modules/virtual-network-gateway/main.bicep' = {
  name: 'deploy-vpn-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'hd-common'
    environment: 'hub'
    location: 'brazilsouth'
    skuName: 'VpnGw2AZ'
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

## Usage — public IPs managed by the module

Single instance serving P2S over Entra ID; the module creates
`nuv-common-vgw-pip-hub` (Standard, Static, zone-redundant).

```bicep
module gateway 'modules/virtual-network-gateway/main.bicep' = {
  name: 'deploy-vpn-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'nuv-common'
    environment: 'hub'
    location: 'eastus2'
    skuName: 'VpnGw1AZ'
    gatewaySubnetId: gatewaySubnetId
    publicIpZones: ['1', '2', '3']
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
| `skuName` | `string` | `'VpnGw2AZ'` | Gateway SKU (name and tier). Prefer AZ SKUs (non-AZ are being retired). |
| `vpnType` | `string` | `'RouteBased'` | `RouteBased` or `PolicyBased`. |
| `vpnGatewayGeneration` | `string` | `'Generation2'` | `Generation1` or `Generation2`. |
| `activeActive` | `bool` | `false` | Active-active mode (needs two IP configs). |
| `enableBgp` | `bool` | `false` | Enable BGP. |
| `bgpAsn` | `int` | `65515` | BGP ASN (used when `enableBgp`). |
| `ipConfigurations` | `array` | `[]` | `{ name, publicIpId, subnetId }` per instance (+ one for P2S). Empty makes the module create its own public IPs. |
| `gatewaySubnetId` | `string` | `''` | Resource ID of the `GatewaySubnet`. Required when `ipConfigurations` is empty. |
| `publicIpZones` | `array` | `['1','2','3']` | Zones of the public IPs the module creates. The `*AZ` SKUs need a zone-redundant Standard IP. |
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
| `publicIpId` | `string` | ID of the primary public IP created by the module. Empty in bring-your-own mode. |
| `publicIpAddress` | `string` | Address of that public IP — the endpoint VPN clients connect to. Empty in bring-your-own mode. |

# Private DNS Resolver

Bicep Module for provisioning an **Azure DNS Private Resolver** with an inbound endpoint, following the configurable naming convention (`{workloadName}-dnspr-{environment}`).

A private DNS zone answers only queries that reach Azure DNS from inside a linked virtual network, and `168.63.129.16` is not routable from outside it. That leaves anything off-VNet — a point-to-site VPN client, an on-premises resolver, a branch office over ExpressRoute — resolving the public name instead of the private endpoint. The inbound endpoint closes that gap: it is a private IP in the VNet that accepts DNS queries and answers them exactly as Azure DNS would for a resource in that network, private zones linked to the VNet first, public names after.

Give it a **fixed** `inboundPrivateIpAddress` whenever something else has to be configured to point at it — the VNet's own DNS server list, a VPN client profile, an on-premises conditional forwarder. A dynamic address works, but it can only be discovered after the resolver exists, which is the wrong order for whoever needs to reference it.

## Usage

```bicep
module dnsResolver 'modules/private-dns-resolver/main.bicep' = {
  name: 'deploy-dns-private-resolver'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'hub'
    location: 'eastus2'
    virtualNetworkId: vnet.outputs.id
    inboundSubnetId: dnsInboundSubnet.outputs.id
    inboundPrivateIpAddress: '10.0.3.4'
  }
}
```

The inbound subnet is a dedicated one — at least `/28`, delegated to `Microsoft.Network/dnsResolvers`, holding nothing else:

```bicep
{
  name: 'dns-inbound-snet'
  addressPrefixes: ['10.0.3.0/28']
  delegations: [
    { name: 'dnsResolver', serviceName: 'Microsoft.Network/dnsResolvers' }
  ]
}
```

> **Note:** the resolver and its virtual network must be in the same region. Outbound endpoints and DNS forwarding rulesets — which send queries the other way, from Azure to an on-premises DNS server — are out of scope for this module.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. Overrides the auto-generated pattern when provided. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Composes the auto-generated name. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hub`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region. Must match the region of the virtual network. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `virtualNetworkId` | `string` | *(required)* | ID of the virtual network the resolver is attached to. Its linked private DNS zones are what the resolver answers for. |
| `inboundSubnetId` | `string` | *(required)* | ID of the subnet hosting the inbound endpoint. At least `/28`, delegated to `Microsoft.Network/dnsResolvers`, dedicated. |
| `inboundEndpointName` | `string` | `'inbound'` | Name of the inbound endpoint. |
| `inboundPrivateIpAddress` | `string` | `''` | Fixed private IP for the inbound endpoint, from the inbound subnet. Empty assigns one dynamically. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created DNS private resolver. |
| `name` | `string` | Name of the created DNS private resolver. |
| `inboundEndpointId` | `string` | ID of the inbound endpoint. |
| `inboundIpAddress` | `string` | Private IP address the inbound endpoint listens on. |

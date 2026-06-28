# Virtual Network Peering

Bicep Module for provisioning a single-direction peering on an existing Virtual Network. This module does not follow the automatic naming convention `{workloadName}-{abbr}-{environment}`, since the peering name is provided directly by the user through the `peeringName` parameter. A full hub-spoke connection requires two peerings (one per side): on the spoke set `useRemoteGateways: true`, and on the hub set `allowGatewayTransit: true`.

## Usage

```bicep
// Spoke side (e.g. deployed into the spoke's resource group)
module spokeToHub 'modules/vnet-peering/main.bicep' = {
  name: 'deploy-spoke-to-hub'
  scope: resourceGroup('myapp-spoke-rg')
  params: {
    localVnetName: 'myapp-vnet-spoke'
    peeringName: 'spoke-to-hub-peer'
    remoteVirtualNetworkId: hubVnetId
    allowForwardedTraffic: true
    useRemoteGateways: true
  }
}

// Hub side (deployed into the hub's resource group)
module hubToSpoke 'modules/vnet-peering/main.bicep' = {
  name: 'deploy-hub-to-spoke'
  scope: resourceGroup('myapp-hub-rg')
  params: {
    localVnetName: 'myapp-vnet-hub'
    peeringName: 'hub-to-spoke-peer'
    remoteVirtualNetworkId: spokeVnetId
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `localVnetName` | `string` | *(required)* | Name of the existing local virtual network where the peering will be created. |
| `peeringName` | `string` | *(required)* | Name of the peering to be created. |
| `remoteVirtualNetworkId` | `string` | *(required)* | Resource ID of the remote virtual network to peer with. |
| `allowVirtualNetworkAccess` | `bool` | `true` | Allows traffic from the local virtual network to reach the remote one. |
| `allowForwardedTraffic` | `bool` | `false` | Allows forwarded (non-originated) traffic from the remote virtual network. |
| `allowGatewayTransit` | `bool` | `false` | Allows the remote virtual network to use this network's gateway. Set on the hub side. |
| `useRemoteGateways` | `bool` | `false` | Uses the remote virtual network's gateway. Set on the spoke side. Mutually exclusive with `allowGatewayTransit`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created peering. |
| `name` | `string` | Name of the created peering. |

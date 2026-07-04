# VPN Connection (Site-to-Site)

Bicep module for provisioning an **IPsec Site-to-Site VPN connection** between an
existing Virtual Network Gateway (Azure side) and a Local Network Gateway (peer
side), with optional custom IPsec/IKE policy and NAT rule associations. Follows the
naming convention `{workloadName}-con-{environment}`; `name` overrides it.

> NAT rules and `usePolicyBasedTrafficSelectors` are mutually exclusive. When
> associating `egressNatRuleIds` / `ingressNatRuleIds`, keep
> `usePolicyBasedTrafficSelectors: false`.

## Usage

```bicep
module conn 'modules/vpn-connection/main.bicep' = {
  name: 'deploy-conn-detran-pr'
  scope: resourceGroup('my-rg')
  params: {
    name: 'detran-pr-conn'
    workloadName: 'hd-common'
    environment: 'hub'
    virtualNetworkGatewayId: vgwId
    localNetworkGatewayId: lng.outputs.id
    sharedKey: detranPrSharedKey
    connectionProtocol: 'IKEv1'
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: [
      {
        saLifeTimeSeconds: 3600
        saDataSizeKilobytes: 102400000
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA1'
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA1'
        dhGroup: 'DHGroup2'
        pfsGroup: 'PFS2'
      }
    ]
    egressNatRuleIds: [ natEgress.outputs.id ]
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
| `virtualNetworkGatewayId` | `string` | *(required)* | Resource ID of the Azure VPN gateway. |
| `localNetworkGatewayId` | `string` | *(required)* | Resource ID of the peer Local Network Gateway. |
| `sharedKey` | `secure string` | *(required)* | IPsec pre-shared key. |
| `connectionProtocol` | `string` | `'IKEv2'` | `IKEv1` or `IKEv2`. |
| `usePolicyBasedTrafficSelectors` | `bool` | `false` | Narrow (policy-based) selectors. Must be false with NAT rules. |
| `ipsecPolicies` | `array` | `[]` | Custom IPsec/IKE policies. Empty = default negotiation. |
| `egressNatRuleIds` | `array` | `[]` | EgressSNAT rule IDs to apply. |
| `ingressNatRuleIds` | `array` | `[]` | IngressSNAT rule IDs to apply. |
| `enableBgp` | `bool` | `false` | Enable BGP over the connection. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created connection. |
| `name` | `string` | Name of the created connection. |

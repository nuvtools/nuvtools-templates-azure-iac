# VPN Gateway NAT Rule

Bicep module for provisioning a **NAT rule on an existing Virtual Network Gateway
(VPN)**. It is the Azure-native equivalent of a "SNAT before the tunnel" rule on an
on-premises appliance: it translates source/destination address spaces for
Site-to-Site connections whose peer expects a specific or non-overlapping range.

The rule is created as a child of an **existing** gateway (referenced by name), so it
adopts a gateway that already exists (incremental-safe).

## Constraints (per Azure VPN Gateway NAT)

- Supported SKUs: `VpnGw2~5` / `VpnGw2AZ~5AZ`.
- **Static**: 1:1, internal and external prefixes must be the same size.
- **Dynamic** (PAT): external mapping subnet size is capped at **/26**; traffic is
  **unidirectional** (must be initiated from the Internal Mapping side).
- One address prefix per rule; external mappings must not overlap across rules.
- Not supported on connections with policy-based traffic selectors.
- For active-active gateways, create one rule per instance via `ipConfigurationId`.

## Usage

```bicep
module natEgress 'modules/vpn-gateway-nat-rule/main.bicep' = {
  name: 'deploy-nat-egress-pr'
  scope: resourceGroup('my-rg')
  params: {
    name: 'egress-detran-pr'
    virtualNetworkGatewayName: 'hd-common-vgw-hub'
    mode: 'EgressSnat'
    type: 'Dynamic'
    internalMappings: [ '10.0.0.0/13' ]
    externalMappings: [ '10.99.20.136/32' ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | *(required)* | NAT rule name (no slashes). |
| `virtualNetworkGatewayName` | `string` | *(required)* | Name of the existing gateway that owns the rule. |
| `mode` | `string` | *(required)* | `EgressSnat` or `IngressSnat`. |
| `type` | `string` | `'Dynamic'` | `Static` or `Dynamic`. |
| `internalMappings` | `array` | *(required)* | Internal (pre-NAT) address prefixes. |
| `externalMappings` | `array` | *(required)* | External (post-NAT) address prefixes. |
| `ipConfigurationId` | `string` | `''` | IP configuration ID (active-active). Empty = default instance. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created NAT rule. |
| `name` | `string` | Name of the created NAT rule. |

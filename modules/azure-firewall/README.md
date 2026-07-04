# Azure Firewall

Bicep module for provisioning an **Azure Firewall** together with a **Firewall
Policy** and a network rule collection group, associating an **existing public IP**.
Suited to centralized hub egress (SNAT to a fixed public IP) in a hub-spoke topology.
Follows the naming convention `{workloadName}-afw-{environment}` (policy:
`{workloadName}-afwp-{environment}`); `name` overrides the firewall name.

Azure Firewall SNATs traffic to public destinations using its public IP(s), so
reusing a known public IP keeps existing allowlists on the destination side valid.

## Usage

```bicep
module firewall 'modules/azure-firewall/main.bicep' = {
  name: 'deploy-firewall'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'hd-common'
    environment: 'hub'
    location: 'brazilsouth'
    skuTier: 'Standard'
    subnetId: azureFirewallSubnetId
    publicIpId: existingPublicIpId
    networkRules: [
      {
        name: 'detran-egress'
        sourceAddresses: [ '10.1.0.0/16', '10.3.0.0/16', '10.4.0.0/16' ]
        destinationAddresses: [ '200.198.22.26/32', '131.72.220.186/32' ]
        destinationPorts: [ '443' ]
        protocols: [ 'TCP' ]
      }
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full firewall name. Overrides the naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). |
| `environment` | `string` | *(required)* | Deployment environment. |
| `location` | `string` | `'brazilsouth'` | Azure region. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags. |
| `skuTier` | `string` | `'Standard'` | `Basic`, `Standard` or `Premium`. |
| `subnetId` | `string` | *(required)* | Resource ID of the `AzureFirewallSubnet`. |
| `publicIpId` | `string` | *(required)* | Resource ID of an existing public IP to associate. |
| `networkRules` | `array` | `[]` | Egress network rules (`name`, `sourceAddresses`, `destinationAddresses`, `destinationPorts`, `protocols`). |
| `networkRuleCollectionPriority` | `int` | `200` | Priority of the rule collection group and collection. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Azure Firewall. |
| `name` | `string` | Name of the created Azure Firewall. |
| `privateIpAddress` | `string` | Private IP of the firewall (next hop for spoke UDRs). |

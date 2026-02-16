# Subnet

Bicep Module for provisioning a Subnet as a child resource of an existing Virtual Network. This module does not follow the automatic naming convention `{prefix}-{workloadName}-{abbr}-{environment}`, since the subnet name is provided directly by the user through the `subnetName` parameter. Supports association with NSG, Route Table, NAT Gateway, Service Endpoints, delegations, and Private Endpoint policies.

## Usage

```bicep
module subnet 'modules/subnet/main.bicep' = {
  name: 'deploy-subnet'
  scope: resourceGroup('my-rg')
  params: {
    virtualNetworkName: 'nvt-myapp-vnet-dev'
    subnetName: 'snet-workloads'
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroupId: nsg.outputs.id
    serviceEndpoints: [
      'Microsoft.Storage'
      'Microsoft.Sql'
    ]
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `virtualNetworkName` | `string` | *(required)* | Name of the existing virtual network where the subnet will be created. |
| `subnetName` | `string` | *(required)* | Name of the subnet to be created. |
| `addressPrefix` | `string` | *(required)* | Subnet address prefix (CIDR). Example: `'10.0.1.0/24'`. |
| `networkSecurityGroupId` | `string` | `''` | ID of the Network Security Group to associate with the subnet. Leave empty to skip association. |
| `routeTableId` | `string` | `''` | ID of the Route Table to associate with the subnet. Leave empty to skip association. |
| `natGatewayId` | `string` | `''` | ID of the NAT Gateway to associate with the subnet. Leave empty to skip association. |
| `serviceEndpoints` | `array` | `[]` | List of Service Endpoints to enable. Example: `['Microsoft.Storage', 'Microsoft.Sql']`. |
| `delegations` | `array` | `[]` | List of subnet delegations. Each object must contain `name` and `serviceName`. |
| `privateEndpointNetworkPolicies` | `string` | `'Enabled'` | Network policy for Private Endpoints. Allowed values: `Enabled`, `Disabled`, `NetworkSecurityGroupEnabled`, `RouteTableEnabled`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created subnet. |
| `name` | `string` | Name of the created subnet. |
| `addressPrefix` | `string` | Address prefix of the created subnet. |

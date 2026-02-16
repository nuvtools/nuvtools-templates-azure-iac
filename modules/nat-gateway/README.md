# NAT Gateway

Bicep Module for provisioning a NAT Gateway with Public IP Prefix following the NuvTools naming convention (`{prefix}-{workloadName}-ng-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-ng-{environment}`. The `name` parameter allows you to completely override the automatic name. Automatically creates a public IP prefix (`{prefix}-{workloadName}-ippre-{environment}`) associated with the gateway.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-ng-dev)
module natGateway 'modules/nat-gateway/main.bicep' = {
  name: 'deploy-nat-gateway'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    publicIpPrefixLength: 31
    idleTimeoutInMinutes: 10
  }
}

// Usage with a custom full name
module natGateway2 'modules/nat-gateway/main.bicep' = {
  name: 'deploy-nat-gateway-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'meu-natgw-customizado'
    workloadName: 'myapp'
    environment: 'dev'
    publicIpPrefixLength: 31
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is ignored. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g., `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Standard'` | NAT Gateway SKU. Allowed value: `Standard`. |
| `idleTimeoutInMinutes` | `int` | `4` | Idle timeout in minutes for connections (4-120). |
| `publicIpPrefixLength` | `int` | `31` | Public IP prefix length in bits (28-31). Example: 31 = 2 IPs, 30 = 4 IPs. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created NAT Gateway. |
| `name` | `string` | Name of the created NAT Gateway. |
| `publicIpPrefixId` | `string` | ID of the Public IP Prefix associated with the NAT Gateway. |

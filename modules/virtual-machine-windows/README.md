# NuvTools - Virtual Machine Windows

Bicep Module for provisioning a Windows virtual machine with a dedicated network interface, managed identity (System Assigned), support for static or dynamic private IP, accelerated networking, boot diagnostics, and time zone configured for Brazil, following the NuvTools naming convention (`{prefix}-{workloadName}-vm-{environment}`). When `prefix` is not provided, the generated name will be `{workloadName}-vm-{environment}`. The network interface follows the pattern `{prefix}-{workloadName}-nic-{environment}`. The `name` parameter allows you to completely override the automatic VM name.

## Usage

```bicep
// Usage with prefix (generates: nvt-myapp-vm-dev and nvt-myapp-nic-dev)
module vmWindows 'modules/virtual-machine-windows/main.bicep' = {
  name: 'deploy-vm-windows'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    prefix: 'nvt'
    location: 'brazilsouth'
    vmSize: 'Standard_D2s_v3'
    adminUsername: 'azureadmin'
    adminPassword: 'S3cur3P@ssw0rd!'
    subnetId: '/subscriptions/.../subnets/default'
    imageSku: '2022-datacenter-g2'
    osDiskSizeGB: 128
    osDiskType: 'Premium_LRS'
    enableAcceleratedNetworking: true
    privateIpAddress: '10.0.1.10'
    enableBootDiagnostics: true
  }
}

// Usage with fully custom name
module vmWindows2 'modules/virtual-machine-windows/main.bicep' = {
  name: 'deploy-vm-windows-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'minha-vm-customizada'
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    adminUsername: 'azureadmin'
    adminPassword: 'S3cur3P@ssw0rd!'
    subnetId: '/subscriptions/.../subnets/default'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `prefix` | `string` | `''` | Resource prefix. Used to compose the automatic name (e.g.: `hd`, `nvt`, `corp`). When empty, the name is generated without a prefix. |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'NuvTools', Environment: environment }` | Tags to be applied to the resource. |
| `vmSize` | `string` | `'Standard_D2s_v3'` | Virtual machine size. |
| `adminUsername` | `string` | *(required)* | Administrator username for the virtual machine. |
| `adminPassword` | `string` (secure) | *(required)* | Administrator password for the virtual machine. |
| `subnetId` | `string` | *(required)* | Subnet ID where the network interface will be deployed. |
| `imagePublisher` | `string` | `'MicrosoftWindowsServer'` | Operating system image publisher. |
| `imageOffer` | `string` | `'WindowsServer'` | Operating system image offer. |
| `imageSku` | `string` | `'2022-datacenter-g2'` | Operating system image SKU. |
| `osDiskSizeGB` | `int` | `128` | Operating system disk size in GB. |
| `osDiskType` | `string` | `'Premium_LRS'` | Operating system disk type. Allowed values: `Premium_LRS`, `StandardSSD_LRS`, `Standard_LRS`. |
| `enableAcceleratedNetworking` | `bool` | `true` | Enables accelerated networking on the network interface. |
| `privateIpAddress` | `string` | `''` | Static private IP address. If empty, dynamic allocation will be used. |
| `enableBootDiagnostics` | `bool` | `true` | Enables boot diagnostics for the virtual machine. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created virtual machine. |
| `name` | `string` | Name of the created virtual machine. |
| `privateIpAddress` | `string` | Private IP address of the virtual machine. |

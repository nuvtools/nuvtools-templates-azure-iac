# Virtual Machine Windows

Bicep Module for provisioning a Windows virtual machine with a dedicated network interface, managed identity (System Assigned), support for static or dynamic private IP, accelerated networking, boot diagnostics, and time zone configured for Brazil, following a configurable naming convention (`{workloadName}-vm-{environment}`). The network interface follows the pattern `{workloadName}-vm-nic-{environment}`. The `name` parameter allows you to completely override the automatic VM name.

## Usage

```bicep
// Generates: myapp-vm-dev and myapp-vm-nic-dev
module vmWindows 'modules/virtual-machine-windows/main.bicep' = {
  name: 'deploy-vm-windows'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
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

// Jumpbox reached over VPN: Entra ID sign-in instead of the local administrator,
// and a nightly shutdown so a forgotten session stops costing compute.
// Pair it with a "Virtual Machine Administrator Login" role assignment.
module jumpbox 'modules/virtual-machine-windows/main.bicep' = {
  name: 'deploy-vm-jumpbox'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'hub'
    adminUsername: 'breakglass'
    adminPassword: adminPassword
    subnetId: '/subscriptions/.../subnets/vm-snet'
    enableEntraLogin: true
    autoShutdownTime: '2300'
  }
}

// Usage with fully custom name
module vmWindows2 'modules/virtual-machine-windows/main.bicep' = {
  name: 'deploy-vm-windows-2'
  scope: resourceGroup('my-rg')
  params: {
    name: 'my-custom-vm'
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
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
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
| `enableEntraLogin` | `bool` | `false` | Installs the `AADLoginForWindows` extension so Microsoft Entra ID accounts sign in over RDP. Who may sign in is granted separately with the *Virtual Machine Administrator Login* or *Virtual Machine User Login* role. The VM needs outbound access to Entra ID — on a subnet without default outbound access, a NAT Gateway. |
| `autoShutdownTime` | `string` | `''` | Daily auto-shutdown time, 24-hour `HHmm` (e.g. `2300`). Empty disables it. Requires the `Microsoft.DevTestLab` resource provider registered in the subscription. |
| `autoShutdownTimeZone` | `string` | `'E. South America Standard Time'` | Windows time zone ID in which `autoShutdownTime` is read. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created virtual machine. |
| `name` | `string` | Name of the created virtual machine. |
| `privateIpAddress` | `string` | Private IP address of the virtual machine. |

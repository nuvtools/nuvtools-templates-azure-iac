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

// SQL Server marketplace image whose Entra ID users can open the local instance:
// without sqlSysadminLogins only the local administrator is a sysadmin.
module sqlJumpbox 'modules/virtual-machine-windows/main.bicep' = {
  name: 'deploy-vm-sql-jumpbox'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'hub'
    adminUsername: 'breakglass'
    adminPassword: adminPassword
    subnetId: '/subscriptions/.../subnets/vm-snet'
    imagePublisher: 'MicrosoftSQLServer'
    imageOffer: 'sql2025-ws2025'
    imageSku: 'entdev-gen2'
    enableEntraLogin: true
    sqlSysadminLogins: [
      'AzureAD\\jane@contoso.com'
    ]
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
| `computerName` | `string` | `''` | Windows computer name (NetBIOS, max 15 characters). Empty derives it from `workloadName` and `environment` without hyphens. It is also the host name registered in a private DNS zone with autoregistration and the name an Entra ID RDP sign-in must connect to. Immutable: changing it recreates the VM. |
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
| `primaryDnsSuffix` | `string` | `''` | Primary DNS suffix (e.g. `contoso.internal`), set by a run command before the Entra ID extension, without a reboot. An Azure VM has none, so with `enableEntraLogin` the device registers only its bare computer name and an RDP to `<computerName>.<suffix>` is refused (`AADSTS293004`). Set it to the private DNS zone the VM autoregisters in and the device registers the FQDN too. |
| `sqlSysadminLogins` | `array` | `[]` | Windows accounts or groups made sysadmin on the SQL Server default instance of a SQL Server marketplace image (e.g. `AzureAD\jane@contoso.com`, `BUILTIN\Administrators`). Such an image comes up in Windows authentication mode with the local administrator as its only usable sysadmin, so an account that signs in with Entra ID is refused by SQL Server. An Entra ID account is written `AzureAD\<UPN>` and needs `enableEntraLogin`; it does not have to have signed in before. `BUILTIN\Administrators` covers whoever may sign in as administrator, but only from an elevated client. Applied by a run command that restarts SQL Server in single-user mode — it drops open connections, once, and again only when the list changes. Names cannot contain a comma. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created virtual machine. |
| `name` | `string` | Name of the created virtual machine. |
| `privateIpAddress` | `string` | Private IP address of the virtual machine. |

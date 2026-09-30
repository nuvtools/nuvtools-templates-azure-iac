// ---------------------------------------------------------------------------
// Bicep Module: Virtual Machine Windows
// Creates a Windows virtual machine with a dedicated network interface,
// static or dynamic private IP support and boot diagnostics, and optionally
// Microsoft Entra ID sign-in and a daily auto-shutdown.
// ---------------------------------------------------------------------------

metadata name = 'Virtual Machine Windows'
metadata description = 'Module for creating a Windows virtual machine with network interface and boot diagnostics following configurable naming conventions.'
metadata version = '1.2.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Full resource name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the resource name when name is not provided.')
@minLength(2)
@maxLength(20)
param workloadName string

@description('''Windows computer name (NetBIOS, at most 15 characters). Empty derives it from
workloadName and environment, hyphens removed. It is also the host name the VM registers in a
private DNS zone with autoregistration, and the name an Entra ID RDP sign-in must connect to — so
set it when people will type it. Immutable: changing it recreates the VM.''')
@maxLength(15)
param computerName string = ''

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string


@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Virtual machine size.')
param vmSize string = 'Standard_D2s_v3'

@description('Administrator username for the virtual machine.')
param adminUsername string

@description('Administrator password for the virtual machine.')
@secure()
param adminPassword string

@description('Subnet ID where the network interface will be deployed.')
param subnetId string

@description('OS image publisher.')
param imagePublisher string = 'MicrosoftWindowsServer'

@description('OS image offer.')
param imageOffer string = 'WindowsServer'

@description('OS image SKU.')
param imageSku string = '2022-datacenter-g2'

@description('OS disk size in GB.')
param osDiskSizeGB int = 128

@description('OS disk type.')
@allowed([
  'Premium_LRS'
  'StandardSSD_LRS'
  'Standard_LRS'
])
param osDiskType string = 'Premium_LRS'

@description('Enables accelerated networking on the network interface.')
param enableAcceleratedNetworking bool = true

@description('Static private IP address. If empty, dynamic allocation will be used.')
param privateIpAddress string = ''

@description('Enables boot diagnostics for the virtual machine.')
param enableBootDiagnostics bool = true

@description('''Installs the AADLoginForWindows extension, so Microsoft Entra ID accounts sign in over
RDP and the local administrator becomes break-glass only. The extension grants nothing by itself:
who may sign in is decided by the "Virtual Machine Administrator Login" or "Virtual Machine User
Login" role on the VM or a scope above it. The VM must reach Microsoft Entra ID over the internet —
on a subnet without default outbound access that means a NAT Gateway, or the extension fails.''')
param enableEntraLogin bool = false

@description('Daily auto-shutdown time, 24-hour HHmm (e.g. 2300). Empty disables auto-shutdown. Requires the Microsoft.DevTestLab resource provider to be registered in the subscription.')
param autoShutdownTime string = ''

@description('Windows time zone ID in which autoShutdownTime is read.')
param autoShutdownTimeZone string = 'E. South America Standard Time'

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-vm-{environment}, and the subordinate resources with
// the resource type last: {workloadName}-vm-<type>-{environment}.
var autoName = '${workloadName}-vm-${environment}'
var vmName = empty(name) ? autoName : name
var nicName = '${workloadName}-vm-nic-${environment}'

// Determines the private IP allocation type
var useStaticIp = !empty(privateIpAddress)

// =============================================================================
// Resources
// =============================================================================

// Virtual machine network interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2025-07-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: enableAcceleratedNetworking
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: useStaticIp ? 'Static' : 'Dynamic'
          privateIPAddress: useStaticIp ? privateIpAddress : null
        }
      }
    ]
  }
}

// Windows virtual machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2025-11-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: empty(computerName) ? take(replace('${workloadName}vm${environment}', '-', ''), 15) : computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        timeZone: 'E. South America Standard Time'
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: osDiskType
        }
        caching: 'ReadWrite'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: enableBootDiagnostics
      }
    }
  }
}

// Microsoft Entra ID sign-in over RDP
resource entraLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2025-11-01' = if (enableEntraLogin) {
  parent: virtualMachine
  name: 'AADLoginForWindows'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.2'
    autoUpgradeMinorVersion: true
  }
}

// Daily auto-shutdown. The resource name is fixed by the platform: the portal only
// recognises a schedule named shutdown-computevm-<vm name>.
#disable-next-line use-recent-api-versions // 2018-09-15 is the latest non-preview version of Microsoft.DevTestLab/schedules
resource autoShutdownSchedule 'Microsoft.DevTestLab/schedules@2018-09-15' = if (!empty(autoShutdownTime)) {
  name: 'shutdown-computevm-${vmName}'
  location: location
  tags: tags
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: virtualMachine.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created virtual machine.')
output id string = virtualMachine.id

@description('Name of the created virtual machine.')
output name string = virtualMachine.name

@description('Private IP address of the virtual machine.')
output privateIpAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress

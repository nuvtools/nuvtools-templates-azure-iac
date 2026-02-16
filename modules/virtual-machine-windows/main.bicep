// ---------------------------------------------------------------------------
// Bicep Module: Virtual Machine Windows
// Creates a Windows virtual machine with a dedicated network interface,
// static or dynamic private IP support and boot diagnostics.
// ---------------------------------------------------------------------------

metadata name = 'Virtual Machine Windows'
metadata description = 'Module for creating a Windows virtual machine with network interface and boot diagnostics following configurable naming conventions.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Full resource name. If provided, overrides the auto-generated naming pattern.')
param name string = ''

@description('Workload name. Used to compose the resource name when name is not provided.')
@minLength(2)
@maxLength(20)
param workloadName string

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

// =============================================================================
// Variables
// =============================================================================

// Pattern: {workloadName}-vm-{environment}
var autoName = '${workloadName}-vm-${environment}'
var vmName = empty(name) ? autoName : name
var nicName = '${workloadName}-nic-${environment}'

// Determines the private IP allocation type
var useStaticIp = !empty(privateIpAddress)

// =============================================================================
// Resources
// =============================================================================

// Virtual machine network interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2024-05-01' = {
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
resource virtualMachine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
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
      computerName: take(replace('${workloadName}vm${environment}', '-', ''), 15)
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

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created virtual machine.')
output id string = virtualMachine.id

@description('Name of the created virtual machine.')
output name string = virtualMachine.name

@description('Private IP address of the virtual machine.')
output privateIpAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress

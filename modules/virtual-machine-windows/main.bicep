// ---------------------------------------------------------------------------
// Bicep Module: Virtual Machine Windows
// Creates a Windows virtual machine with a dedicated network interface,
// static or dynamic private IP support and boot diagnostics, and optionally
// Microsoft Entra ID sign-in, a daily auto-shutdown and, on a SQL Server image,
// sysadmin logins.
// ---------------------------------------------------------------------------

metadata name = 'Virtual Machine Windows'
metadata description = 'Module for creating a Windows virtual machine with network interface and boot diagnostics following configurable naming conventions.'
metadata version = '1.4.0'

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

@description('''Primary DNS suffix of the VM (e.g. contoso.internal), set before anything else runs on
it. An Azure VM has none — the VNet suffix is only connection-specific — so with Entra ID sign-in the
device registers its bare computer name alone, and an RDP to <computerName>.<suffix> is refused with
AADSTS293004. Set this to the private DNS zone the VM autoregisters in, and the device registers the
FQDN as well. Applied without a reboot. Empty leaves the VM without one.''')
param primaryDnsSuffix string = ''

@description('''Windows accounts or groups made sysadmin on the SQL Server default instance of a SQL
Server marketplace image (e.g. AzureAD\jane@contoso.com, BUILTIN\Administrators). Such an image
comes up in Windows authentication mode with the local administrator as its only usable sysadmin, so
an account that signs in with Entra ID is refused by SQL Server although it administers Windows.
An Entra ID account is written AzureAD\<UPN> and needs enableEntraLogin; it does not have to have
signed in before. BUILTIN\Administrators covers whoever may sign in as administrator, but only from
an elevated client ("Run as administrator"): UAC strips the group from a normal token. Applied by a
run command that restarts SQL Server in single-user mode, so it drops open connections — once, and
again only when this list changes. Names cannot contain a comma. Empty leaves SQL Server untouched.''')
param sqlSysadminLogins array = []

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

// Primary DNS suffix. Written to both registry values: 'NV Domain' is what survives a
// reboot, 'Domain' is what Windows reports now — so it takes effect without one, which
// is what lets the Entra ID join below register the FQDN on the first boot.
resource primaryDnsSuffixCommand 'Microsoft.Compute/virtualMachines/runCommands@2025-11-01' = if (!empty(primaryDnsSuffix)) {
  parent: virtualMachine
  name: 'set-primary-dns-suffix'
  location: location
  tags: tags
  properties: {
    source: {
      script: '''
param([string]$Suffix)
$path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
Set-ItemProperty -Path $path -Name 'NV Domain' -Value $Suffix
Set-ItemProperty -Path $path -Name 'Domain' -Value $Suffix
'''
    }
    parameters: [
      {
        name: 'Suffix'
        value: primaryDnsSuffix
      }
    ]
    treatFailureAsDeploymentFailure: true
  }
}

// Microsoft Entra ID sign-in over RDP. After the DNS suffix: the host names the device
// registers are read once, at join, and an RDP is accepted only to one of them.
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
  dependsOn: [
    primaryDnsSuffixCommand
  ]
}

// SQL Server sysadmin logins. Nothing on the VM can create a login the ordinary way — not
// even SYSTEM, which the run command runs as, is a sysadmin on the marketplace image — so
// the instance is restarted in single-user mode, where a local administrator is one.
// -mSQLCMD reserves the only connection for sqlcmd; the telemetry service would take it.
// After the Entra ID join: an AzureAD\<UPN> name resolves only on a joined device.
resource sqlSysadminLoginsCommand 'Microsoft.Compute/virtualMachines/runCommands@2025-11-01' = if (!empty(sqlSysadminLogins)) {
  parent: virtualMachine
  name: 'grant-sql-sysadmin'
  location: location
  tags: tags
  properties: {
    source: {
      script: '''
param([string[]]$Logins)
$ErrorActionPreference = 'Stop'
$service = 'MSSQLSERVER'

if (-not (Get-Service $service -ErrorAction SilentlyContinue)) {
    throw "No SQL Server default instance on this VM; sqlSysadminLogins needs a SQL Server image."
}

# Resolved before SQL Server is touched, so a mistyped name fails with the instance still up.
# The login is created under the name Windows reports for the SID: an Entra ID account is
# given as AzureAD\<UPN> and reported as AzureAD\<DisplayName>.
$accounts = foreach ($login in ($Logins -split ',').Trim() | Where-Object { $_ }) {
    $sid = [System.Security.Principal.NTAccount]::new($login).Translate([System.Security.Principal.SecurityIdentifier])
    $sid.Translate([System.Security.Principal.NTAccount]).Value
}

$statements = foreach ($account in $accounts) {
    $name = $account.Replace(']', ']]')
    $literal = $account.Replace("'", "''")
    "IF SUSER_ID(N'$literal') IS NULL CREATE LOGIN [$name] FROM WINDOWS; ALTER SERVER ROLE [sysadmin] ADD MEMBER [$name];"
}
$sql = $statements -join ' '

$agentWasRunning = (Get-Service SQLSERVERAGENT -ErrorAction SilentlyContinue).Status -eq 'Running'
Stop-Service $service -Force
try {
    net start $service /mSQLCMD | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "SQL Server did not start in single-user mode (net start exit code $LASTEXITCODE)." }

    # The service reports started a few seconds before the instance accepts a connection.
    for ($attempt = 1; ; $attempt++) {
        $output = sqlcmd -S . -E -C -b -Q $sql
        if ($LASTEXITCODE -eq 0) { break }
        if ($attempt -ge 12) { throw "sqlcmd failed: $output" }
        Start-Sleep -Seconds 5
    }
}
finally {
    Stop-Service $service -Force
    Start-Service $service
    if ($agentWasRunning) { Start-Service SQLSERVERAGENT }
}

"sysadmin granted to: $($accounts -join ', ')"
'''
    }
    parameters: [
      {
        name: 'Logins'
        value: join(sqlSysadminLogins, ',')
      }
    ]
    timeoutInSeconds: 600
    treatFailureAsDeploymentFailure: true
  }
  dependsOn: [
    entraLoginExtension
  ]
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

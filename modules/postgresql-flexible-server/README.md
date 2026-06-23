# PostgreSQL Flexible Server

Bicep module for provisioning an **Azure Database for PostgreSQL Flexible Server** with a configurable compute SKU, storage, backup, high availability, public or VNet-integrated (private) network access, optional firewall rules and conditional diagnostics, following a configurable naming convention (`{workloadName}-psql-{environment}`).

## Naming Convention

The resource name is automatically generated based on the `workloadName` and `environment` parameters:

- Pattern: `{workloadName}-psql-{environment}` (e.g., `myapp-psql-dev`)
- Override: use the `name` parameter to define a fully custom name, bypassing the automatic naming convention.

## Network Access

The module supports the two Flexible Server connectivity methods:

- **Public access** (default): set `publicNetworkAccess` to `Enabled` or `Disabled` and optionally add firewall rules via `allowAzureServices` / `firewallRules`.
- **Private access (VNet integration)**: provide `delegatedSubnetResourceId` (a subnet delegated to `Microsoft.DBforPostgreSQL/flexibleServers`) and `privateDnsZoneArmResourceId`. When a delegated subnet is provided, the server is created with private access and firewall rules are ignored.

## Usage

### Public access

```bicep
module postgresqlServer 'modules/postgresql-flexible-server/main.bicep' = {
  name: 'deploy-postgresql-server'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    location: 'brazilsouth'
    administratorLogin: 'pgadmin'
    administratorPassword: 'S3cur3P@ssw0rd!'
    postgresqlVersion: '16'
    skuName: 'Standard_B1ms'
    skuTier: 'Burstable'
    storageSizeGB: 32
    publicNetworkAccess: 'Enabled'
    allowAzureServices: true
  }
}
```

### Private access (VNet-integrated)

```bicep
module postgresqlServer 'modules/postgresql-flexible-server/main.bicep' = {
  name: 'deploy-postgresql-server'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'prod'
    administratorLogin: 'pgadmin'
    administratorPassword: 'S3cur3P@ssw0rd!'
    skuName: 'Standard_D2s_v3'
    skuTier: 'GeneralPurpose'
    storageSizeGB: 128
    highAvailabilityMode: 'ZoneRedundant'
    delegatedSubnetResourceId: '/subscriptions/.../subnets/snet-postgresql'
    privateDnsZoneArmResourceId: '/subscriptions/.../privateDnsZones/myapp.private.postgres.database.azure.com'
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, the automatic naming convention is bypassed. |
| `workloadName` | `string` | *(required)* | Workload name. Used to compose the resource name. Min: 2, Max: 20 characters. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `administratorLogin` | `string` | *(required)* | PostgreSQL administrator login. |
| `administratorPassword` | `string` (secure) | *(required)* | PostgreSQL administrator password. |
| `postgresqlVersion` | `string` | `'16'` | Major PostgreSQL engine version. Allowed: `13`, `14`, `15`, `16`, `17`. |
| `skuName` | `string` | `'Standard_B1ms'` | Compute SKU name (e.g., `Standard_B1ms`, `Standard_D2s_v3`, `Standard_E2ds_v5`). |
| `skuTier` | `string` | `'Burstable'` | Compute SKU tier. Allowed: `Burstable`, `GeneralPurpose`, `MemoryOptimized`. |
| `storageSizeGB` | `int` | `32` | Allocated storage size in GB. Allowed: `32`–`16384`. |
| `storageAutoGrow` | `string` | `'Enabled'` | Enables storage auto-grow. Allowed: `Enabled`, `Disabled`. |
| `backupRetentionDays` | `int` | `7` | Number of days to retain backups. Min: 7, Max: 35. |
| `geoRedundantBackup` | `string` | `'Disabled'` | Enables geo-redundant backups. Allowed: `Enabled`, `Disabled`. |
| `highAvailabilityMode` | `string` | `'Disabled'` | High availability mode. Allowed: `Disabled`, `ZoneRedundant`, `SameZone`. ZoneRedundant/SameZone require GeneralPurpose or MemoryOptimized. |
| `availabilityZone` | `string` | `''` | Availability zone for the primary server. Empty lets Azure choose. |
| `publicNetworkAccess` | `string` | `'Disabled'` | Public network access. Allowed: `Enabled`, `Disabled`. Ignored when `delegatedSubnetResourceId` is provided. |
| `delegatedSubnetResourceId` | `string` | `''` | Resource ID of the delegated subnet for VNet integration (private access). |
| `privateDnsZoneArmResourceId` | `string` | `''` | Resource ID of the private DNS zone to link. Required when `delegatedSubnetResourceId` is provided. |
| `allowAzureServices` | `bool` | `false` | Adds a firewall rule allowing access from Azure services (0.0.0.0). Public access only. |
| `firewallRules` | `array` | `[]` | Additional firewall rules. Array of objects with `name`, `startIpAddress`, `endIpAddress`. Public access only. |
| `enableDiagnostics` | `bool` | `false` | Enables sending diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Log Analytics workspace ID for sending diagnostics. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created PostgreSQL Flexible Server. |
| `name` | `string` | Name of the created PostgreSQL Flexible Server. |
| `fullyQualifiedDomainName` | `string` | Fully qualified domain name (e.g., myserver.postgres.database.azure.com). |

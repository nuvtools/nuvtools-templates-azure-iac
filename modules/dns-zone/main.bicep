// ---------------------------------------------------------------------------
// Bicep Module: Public DNS Zone
// Creates a public (internet-facing) Azure DNS zone and its record sets. Record
// sets declared here are owned by the template; record sets created outside it
// (e.g. a validation TXT written by a pipeline) are left alone, because the
// deployment is incremental.
// ---------------------------------------------------------------------------

metadata name = 'Public DNS Zone'
metadata description = 'Module for creating a public Azure DNS zone with A, AAAA, CNAME, MX, TXT, SRV and CAA record sets, including alias records.'
metadata version = '1.0.0'

// =============================================================================
// Parameters
// =============================================================================

@description('Workload name. Kept for interface standardization; the zone is named after the domain.')
@minLength(2)
@maxLength(20)
#disable-next-line no-unused-params // Kept for interface standardization across modules
param workloadName string

@description('Deployment environment (e.g., dev, uat, hml, staging, prod).')
param environment string

@description('Tags to apply to the resource.')
param tags object = {
  ManagedBy: 'Bicep'
  Environment: environment
}

@description('Domain the zone answers for. Example: \'example.com\'.')
param zoneName string

@description('A record sets. Each: name (\'@\' for the apex), ttl (optional, default 3600), and either ipv4Addresses (string array) or targetResourceId (alias to an Azure resource such as a public IP or a static web app).')
param aRecords array = []

@description('AAAA record sets. Each: name, ttl (optional), and either ipv6Addresses (string array) or targetResourceId (alias).')
param aaaaRecords array = []

@description('CNAME record sets. Each: name, ttl (optional), and either cname (target host name) or targetResourceId (alias). A CNAME cannot sit at the apex.')
param cnameRecords array = []

@description('MX record sets. Each: name, ttl (optional), exchanges (array of { preference, exchange }).')
param mxRecords array = []

@description('TXT record sets. Each: name, ttl (optional), values (string array, one entry per TXT record; each entry at most 255 characters).')
param txtRecords array = []

@description('SRV record sets. Each: name (e.g. \'_sip._tls\'), ttl (optional), records (array of { priority, weight, port, target }).')
param srvRecords array = []

@description('CAA record sets. Each: name, ttl (optional), records (array of { flags, tag, value }).')
param caaRecords array = []

// =============================================================================
// Variables
// =============================================================================

// Public DNS zones are global resources, location must be 'global'
var dnsZoneLocation = 'global'
var defaultTtl = 3600

// =============================================================================
// Resources
// =============================================================================

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: zoneName
  location: dnsZoneLocation
  tags: tags
  properties: {
    zoneType: 'Public'
  }
}

// An alias record carries targetResource instead of values; the two are mutually exclusive.
resource dnsARecords 'Microsoft.Network/dnsZones/A@2018-05-01' = [for record in aRecords: {
  name: record.name
  parent: dnsZone
  properties: union(
    { TTL: record.?ttl ?? defaultTtl },
    empty(record.?targetResourceId ?? '')
      ? { ARecords: map(record.ipv4Addresses, ip => { ipv4Address: ip }) }
      : { targetResource: { id: record.targetResourceId } }
  )
}]

resource dnsAaaaRecords 'Microsoft.Network/dnsZones/AAAA@2018-05-01' = [for record in aaaaRecords: {
  name: record.name
  parent: dnsZone
  properties: union(
    { TTL: record.?ttl ?? defaultTtl },
    empty(record.?targetResourceId ?? '')
      ? { AAAARecords: map(record.ipv6Addresses, ip => { ipv6Address: ip }) }
      : { targetResource: { id: record.targetResourceId } }
  )
}]

resource dnsCnameRecords 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = [for record in cnameRecords: {
  name: record.name
  parent: dnsZone
  properties: union(
    { TTL: record.?ttl ?? defaultTtl },
    empty(record.?targetResourceId ?? '')
      ? { CNAMERecord: { cname: record.cname } }
      : { targetResource: { id: record.targetResourceId } }
  )
}]

resource dnsMxRecords 'Microsoft.Network/dnsZones/MX@2018-05-01' = [for record in mxRecords: {
  name: record.name
  parent: dnsZone
  properties: {
    TTL: record.?ttl ?? defaultTtl
    MXRecords: record.exchanges
  }
}]

resource dnsTxtRecords 'Microsoft.Network/dnsZones/TXT@2018-05-01' = [for record in txtRecords: {
  name: record.name
  parent: dnsZone
  properties: {
    TTL: record.?ttl ?? defaultTtl
    TXTRecords: map(record.values, v => { value: [v] })
  }
}]

resource dnsSrvRecords 'Microsoft.Network/dnsZones/SRV@2018-05-01' = [for record in srvRecords: {
  name: record.name
  parent: dnsZone
  properties: {
    TTL: record.?ttl ?? defaultTtl
    SRVRecords: record.records
  }
}]

resource dnsCaaRecords 'Microsoft.Network/dnsZones/CAA@2018-05-01' = [for record in caaRecords: {
  name: record.name
  parent: dnsZone
  properties: {
    TTL: record.?ttl ?? defaultTtl
    caaRecords: record.records
  }
}]

// =============================================================================
// Outputs
// =============================================================================

@description('ID of the created DNS zone.')
output id string = dnsZone.id

@description('Name of the created DNS zone.')
output name string = dnsZone.name

@description('Name servers Azure assigned to the zone. Delegate the domain to these at the registrar.')
output nameServers array = dnsZone.properties.nameServers

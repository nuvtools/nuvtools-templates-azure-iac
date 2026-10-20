# Public DNS Zone

Bicep Module for provisioning a public (internet-facing) Azure DNS zone and its record sets: A, AAAA, CNAME, MX, TXT, SRV and CAA. A, AAAA and CNAME sets can be **alias** records that follow an Azure resource (public IP, static web app, Front Door…) instead of fixed values, which is how an apex domain points at a service with no fixed IP.

The zone is named after the domain, so `name` is not a parameter here. For private DNS (Private Link, internal names) use `private-dns-zone`.

Record sets created outside the template, such as a validation TXT written by a pipeline, are left alone: deployments are incremental. A set declared here, however, is replaced with exactly the values declared.

## Usage

```bicep
module zone 'modules/dns-zone/main.bicep' = {
  name: 'deploy-dns-zone'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'mysite'
    environment: 'prod'
    zoneName: 'example.com'
    aRecords: [
      { name: '@', targetResourceId: site.outputs.id }          // alias to a static web app
      { name: 'gw', ipv4Addresses: ['20.0.0.1'], ttl: 600 }
    ]
    cnameRecords: [
      { name: 'www', cname: site.outputs.defaultHostname }
    ]
    mxRecords: [
      { name: '@', exchanges: [{ preference: 0, exchange: 'example-com.mail.protection.outlook.com' }] }
    ]
    txtRecords: [
      { name: '@', values: ['v=spf1 include:spf.protection.outlook.com -all'] }
    ]
    srvRecords: [
      { name: '_sip._tls', records: [{ priority: 100, weight: 1, port: 443, target: 'sipdir.online.lync.com' }] }
    ]
  }
}
```

After the first deployment, delegate the domain at the registrar to the four servers in the
`nameServers` output. Copy every existing record into the zone **before** switching, or whatever
was left out (mail, verification records) stops resolving.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workloadName` | `string` | *(required)* | Kept for interface standardization; not used in the name. |
| `environment` | `string` | *(required)* | Deployment environment (used in the default tags). |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the zone. |
| `zoneName` | `string` | *(required)* | The domain, e.g. `example.com`. |
| `aRecords` | `array` | `[]` | `{ name, ttl?, ipv4Addresses? , targetResourceId? }` — one of the last two. |
| `aaaaRecords` | `array` | `[]` | `{ name, ttl?, ipv6Addresses?, targetResourceId? }` — one of the last two. |
| `cnameRecords` | `array` | `[]` | `{ name, ttl?, cname?, targetResourceId? }` — one of the last two. Not allowed at the apex. |
| `mxRecords` | `array` | `[]` | `{ name, ttl?, exchanges: [{ preference, exchange }] }` |
| `txtRecords` | `array` | `[]` | `{ name, ttl?, values: [string] }` — each value at most 255 characters. |
| `srvRecords` | `array` | `[]` | `{ name, ttl?, records: [{ priority, weight, port, target }] }` |
| `caaRecords` | `array` | `[]` | `{ name, ttl?, records: [{ flags, tag, value }] }` |

`ttl` defaults to 3600 seconds. Use `@` for the apex.

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the zone. |
| `name` | `string` | Name of the zone (the domain). |
| `nameServers` | `array` | Name servers Azure assigned; delegate the domain to these at the registrar. |

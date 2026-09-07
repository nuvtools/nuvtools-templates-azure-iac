# Private DNS Zone Virtual Network Link

Bicep Module for linking a virtual network to a Private DNS Zone that **already exists and is owned by another deployment**. It declares the zone `existing` and writes only the link, so it never competes with the zone's owner.

Use [`private-dns-zone`](../private-dns-zone/README.md) when the same deployment owns the zone and its links. Use this module when ownership is split.

## When ownership is split

A private DNS zone name is global, and a virtual network accepts exactly one link per zone name. So a name that has to resolve across an estate — `privatelink.database.windows.net`, say — exists exactly once, in one resource group, while the virtual networks that need to resolve it are spread across resource groups and subscriptions. One deployment owns the zone; many own a link into it.

`private-dns-zone` cannot play the second role. Its zone declaration is unconditional, so calling it from a second deployment issues a PUT on the zone carrying that deployment's tags, and the owner's next run puts its own back. The tags flap between two pipelines forever and both sides report a spurious change on every `what-if`.

## Usage

Deploy at the scope that owns the **zone**, not the one that owns the virtual network — the link is a child of the zone:

```bicep
module hubZoneLink 'modules/private-dns-zone-link/main.bicep' = {
  name: 'deploy-pdnslink-sql-uat'
  // The zone lives in the hub, in another subscription.
  scope: resourceGroup(hubSubscriptionId, 'nuv-common-rg-hub')
  params: {
    workloadName: 'myapp'
    environment: 'uat'
    zoneName: 'privatelink.database.windows.net'
    virtualNetworkId: virtualNetwork.outputs.id
  }
}
```

The identity running this needs write access on the zone's resource group, plus `Microsoft.Network/virtualNetworks/join/action` on the virtual network being linked.

> **Note:** This module does not use automatic naming. `linkName` defaults to `<virtual-network-name>-link`, matching the name `private-dns-zone` composes for the links it writes — so a link keeps its name if ownership of it ever moves between the two modules. `workloadName` and `environment` are kept for interface standardization and tag composition.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Kept for interface standardization across modules. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g., `dev`, `uat`, `hml`, `staging`, `prod`). |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the link. |
| `zoneName` | `string` | *(required)* | Name of the **existing** private DNS zone. Never written to. |
| `virtualNetworkId` | `string` | *(required)* | Resource ID of the virtual network to link. May live in any resource group or subscription. |
| `linkName` | `string` | `''` | Link name. Empty composes `<virtual-network-name>-link`. |
| `registrationEnabled` | `bool` | `false` | Registers the virtual network's VM records in the zone. A privatelink zone is a resolution zone, never a registration zone, and a zone accepts only one registration link. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created virtual network link. |
| `name` | `string` | Name of the created virtual network link. |

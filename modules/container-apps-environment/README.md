# Container Apps Environment

Bicep module for provisioning a VNet-injected Azure Container Apps managed environment (workload profiles) following a configurable naming convention (`{workloadName}-cae-{environment}`). An **internal** environment (the default) exposes a single private static IP inside the VNet with no public endpoint, making it the network isolation boundary for every app it hosts. The `name` parameter allows you to completely override the automatic name.

The module reads the Log Analytics shared key via `listKeys` on an existing workspace in the same resource group, because the `log-analytics` module deliberately does not output the key.

## Usage

```bicep
// Generates: myapp-cae-dev
module containerAppsEnvironment 'modules/container-apps-environment/main.bicep' = {
  name: 'deploy-container-apps-environment'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'dev'
    infrastructureSubnetId: '<subnet delegated to Microsoft.App/environments, >= /27>'
    logAnalyticsWorkspaceName: logAnalytics.outputs.name
    internal: true
  }
}
```

> **Subnet requirement.** The infrastructure subnet must be **delegated to `Microsoft.App/environments`** and at least **/27**. This module always passes `workloadProfiles`, so it always creates a workload-profiles environment — the consumption-only environment, which is the one that requires an *undelegated* `/23`, is not reachable through it. Removing the delegation to satisfy that older requirement breaks the deploy.
>
> The subnet is also consumed exclusively by the environment: it cannot hold other resources, and the delegation is what reserves it.

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment (e.g., `dev`, `uat`, `staging`, `prod`). |
| `location` | `string` | `'brazilsouth'` | Azure region where the resource will be created. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `infrastructureSubnetId` | `string` | *(required)* | Resource ID of the infrastructure subnet. Must be delegated to `Microsoft.App/environments` and at least /27. |
| `logAnalyticsWorkspaceName` | `string` | *(required)* | Name of the Log Analytics workspace (same resource group) that receives container app logs. |
| `internal` | `bool` | `true` | Restricts the environment to a private static IP inside the VNet (no public endpoint) when true. |
| `zoneRedundant` | `bool` | `false` | Spreads replicas across availability zones when true. |
| `workloadProfiles` | `array` | `[{ name: 'Consumption', workloadProfileType: 'Consumption' }]` | Workload profiles available in the environment. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the created Container Apps environment. |
| `name` | `string` | Name of the created Container Apps environment. |
| `defaultDomain` | `string` | Default domain of the environment. App FQDNs are `<app>.<defaultDomain>`. |
| `staticIp` | `string` | Static IP of the environment. For an internal environment this is the private VIP inside the VNet. |

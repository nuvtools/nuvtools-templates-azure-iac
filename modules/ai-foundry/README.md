# Azure AI Foundry (AIServices)

Bicep module for provisioning an **Azure AI Foundry** account — `Microsoft.CognitiveServices/accounts`
of kind **`AIServices`** — with optional **model deployments** and conditional diagnostics, following a
configurable naming convention (`{workloadName}-oai-{environment}`).

The account exposes the OpenAI endpoint at `https://{customSubDomain}.openai.azure.com/` (the
subdomain defaults to the account name).

## Naming Convention

- Pattern: `{workloadName}-oai-{environment}` (e.g., `myapp-oai-prod`)
- Override: use the `name` parameter for a fully custom name.

## Models & regions

`modelDeployments` is an array of model deployments. Each item:

```bicep
{
  name: 'gpt-4.1'            // deployment name (what the app calls)
  modelName: 'gpt-4.1'       // model
  modelVersion: '2025-04-14' // optional; omit to let Azure pick the default
  skuName: 'GlobalStandard'  // optional (default GlobalStandard); or 'Standard', 'DataZoneStandard', ...
  capacity: 10               // optional (default 10) — tokens-per-minute units
}
```

> The account `location` must offer the requested models/SKUs. `GlobalStandard` maximizes regional
> availability. Deployments are created one at a time (`@batchSize(1)`) because the account serializes
> deployment writes.

## Authentication

By default `disableLocalAuth = false`, so API-key auth works (keys retrieved via `listKeys`). Set
`disableLocalAuth = true` for Entra-ID-only (keyless) access, granting callers the *Cognitive Services
OpenAI User* role instead.

## Usage

```bicep
module aiFoundry 'modules/ai-foundry/main.bicep' = {
  name: 'deploy-ai-foundry'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'myapp'
    environment: 'prod'
    location: 'eastus2'
    modelDeployments: [
      { name: 'gpt-4.1', modelName: 'gpt-4.1', modelVersion: '2025-04-14', skuName: 'GlobalStandard', capacity: 10 }
    ]
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. Overrides the naming convention. |
| `workloadName` | `string` | *(required)* | Workload name. Min 2, max 20 chars. |
| `environment` | `string` | *(required)* | Deployment environment. |
| `location` | `string` | `'eastus2'` | Azure region. Must offer the requested models. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: env }` | Tags. |
| `skuName` | `string` | `'S0'` | AIServices account SKU. |
| `customSubDomainName` | `string` | `''` | Custom subdomain label (required for AAD/token + the OpenAI endpoint). Empty uses the account name. |
| `publicNetworkAccess` | `string` | `'Enabled'` | `Enabled` or `Disabled`. |
| `disableLocalAuth` | `bool` | `false` | Disable API-key auth (Entra-only) when `true`. |
| `modelDeployments` | `array` | `[]` | Model deployments (see above). |
| `enableDiagnostics` | `bool` | `false` | Send diagnostics to Log Analytics. |
| `logAnalyticsWorkspaceId` | `string` | `''` | Workspace ID. Required when `enableDiagnostics` is `true`. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | Resource ID of the account. |
| `name` | `string` | Name of the account. |
| `endpoint` | `string` | Primary (Cognitive Services) endpoint. |
| `openAiEndpoint` | `string` | OpenAI endpoint (`https://{subdomain}.openai.azure.com/`). |

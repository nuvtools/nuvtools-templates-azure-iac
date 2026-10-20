# Static Web App

Bicep Module for provisioning an Azure Static Web App with no linked repository, following a configurable naming convention (`{workloadName}-stapp-{environment}`). The content is built and uploaded by the consumer's own pipeline with `Azure/static-web-apps-deploy` and the app's deployment token, so the module never needs repository access. The `name` parameter allows you to completely override the automatic name.

## Usage

```bicep
// Generates: mysite-stapp-prod
module site 'modules/static-web-app/main.bicep' = {
  name: 'deploy-static-web-app'
  scope: resourceGroup('my-rg')
  params: {
    workloadName: 'mysite'
    environment: 'prod'
    location: 'eastus2'
  }
}
```

### Fetching the deployment token in a pipeline

Instead of storing the token as a repository secret, a workflow logged in with OIDC can read it
(the identity needs Contributor on the app):

```bash
token=$(az staticwebapp secrets list --name mysite-stapp-prod --query properties.apiKey -o tsv)
echo "::add-mask::$token"
```

### Custom domains

`customDomains` binds **subdomains** with CNAME validation. The CNAME to `defaultHostname` must
already resolve publicly when the deployment runs (a zone just delegated to Azure DNS counts only
after the registrar's name servers point at it), otherwise the deployment waits and fails.

An **apex** domain cannot be declared here: it is validated with a TXT token that only exists
after the domain is added. Point the apex at the app with an alias A record (`dns-zone` module,
`targetResourceId` = this module's `id`), then add it from a pipeline:

```bash
az staticwebapp hostname set -n mysite-stapp-prod --hostname example.com --validation-method dns-txt-token --no-wait
az staticwebapp hostname show -n mysite-stapp-prod --hostname example.com --query validationToken -o tsv
# write that token as a TXT record named _dnsauth in the zone, then wait for status Ready
```

## Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | `''` | Full resource name. If provided, overrides the automatic naming convention. |
| `workloadName` | `string` | *(required)* | Workload name (2-20 characters). Used to compose the resource name when `name` is not provided. |
| `environment` | `string` | *(required)* | Deployment environment. Accepts any string (e.g.: `dev`, `uat`, `hml`, `staging`, `prod`). |
| `location` | `string` | `'eastus2'` | Region of the management plane: `westus2`, `centralus`, `eastus2`, `westeurope` or `eastasia`. Content is served from a global edge regardless. |
| `tags` | `object` | `{ ManagedBy: 'Bicep', Environment: environment }` | Tags to be applied to the resource. |
| `skuName` | `string` | `'Free'` | `Free` (no SLA, two custom domains) or `Standard`. |
| `stagingEnvironmentPolicy` | `string` | `'Enabled'` | Whether pull requests get preview environments. |
| `allowConfigFileUpdates` | `bool` | `true` | Whether `staticwebapp.config.json` may change the app's configuration on deploy. |
| `customDomains` | `array` | `[]` | Subdomains to bind with CNAME validation. See above. |

## Outputs

| Output | Type | Description |
|---|---|---|
| `id` | `string` | ID of the static web app. |
| `name` | `string` | Name of the static web app. |
| `defaultHostname` | `string` | Default host name (`<random>.azurestaticapps.net`), the target for CNAME records. |

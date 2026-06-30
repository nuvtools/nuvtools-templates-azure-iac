// ---------------------------------------------------------------------------
// Bicep Module: Container App — identity bootstrap
// Pre-creates the Container App with only its user-assigned identity attached
// (public placeholder image, scaled to zero, no ingress, no registries, no
// secrets). This guarantees the identity is associated with the resource BEFORE
// the main module adds @Microsoft.KeyVault secret references, avoiding the Azure
// Container Apps create-time race where secret resolution runs before the
// identity is applied ("No managed service identities are associated with
// resource ..." / IdentityDoesNotExist). The main module then updates this same
// app to its real configuration, by which point the identity already exists.
// ---------------------------------------------------------------------------

metadata name = 'Container App identity bootstrap'
metadata description = 'Pre-creates a Container App with its user-assigned identity so the main module can add Key Vault-backed secrets without hitting the create-time identity race.'
metadata version = '1.0.0'

@description('Full resource name of the Container App to pre-create. Must match the name used by the main module.')
param name string

@description('Azure region where the resource will be created.')
param location string = 'brazilsouth'

@description('Tags to apply to the resource.')
param tags object = {}

@description('Resource ID of the Container Apps managed environment that hosts the app.')
param managedEnvironmentId string

@description('Resource ID of the user-assigned managed identity to associate with the app.')
param userAssignedIdentityId string

@description('Workload profile that runs the app. Must exist on the managed environment.')
param workloadProfileName string = 'Consumption'

@description('Public placeholder image for the bootstrap revision. Must be pullable without registry credentials, so the app can be created before its identity has registry/Key Vault access.')
param image string = 'mcr.microsoft.com/k8se/quickstart:latest'

// Scaled to zero with no ingress: the placeholder never runs and nothing depends
// on a healthy revision, so the create succeeds purely to attach the identity.
resource containerApp 'Microsoft.App/containerApps@2025-10-02-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
    workloadProfileName: workloadProfileName
    configuration: {
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: name
          image: image
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

@description('ID of the bootstrapped Container App.')
output id string = containerApp.id
